# sh/lib/clip.sh
: 'Unified clipboard dispatcher. Source-only.'

clip::_providers() { compgen -c 'clip.' 2>/dev/null | sort -u; }

clip::dispatch() {
  : 'Run the best capable provider for an op/type, with timeout + fallback.

      Every backend here can occasionally stall, so each provider invocation is
      wrapped in `timeout` (CLIP_TIMEOUT seconds, default 5). If the chosen
      provider times out (exit 124) or exits non-zero, the dispatcher falls back
      to the next-highest-scoring capable provider, until one succeeds or none
      remain. If all fail, the friendly no-provider error is printed and 3 is
      returned.

      On `set`, stdin is consumed only once, so the payload is buffered up front
      and replayed to every fallback attempt. On `get`, the provider stdout is
      captured and emitted only if the provider succeeded, so a partial/failed
      provider never leaks garbage before we fall back.

      @arg $1 op  (get|set)
      @arg $2 type (plain|rich|image)
      @env CLIP_TIMEOUT per-provider timeout in seconds (default 5)
      @stdin  content (for set)
      @stdout clipboard content (for get)
      @return 0 on success, 3 if no capable provider succeeds
  '
  local op="$1" type="$2"; shift 2
  local want="$op:$type" timeout_s="${CLIP_TIMEOUT:-5}"
  local p score caps line

  # Collect capable providers as "score<TAB>path", then order by score desc.
  local -a candidates=()
  while IFS= read -r p; do
    score=0 caps=""
    while IFS= read -r line; do
      case "$line" in
        score\ *) score="${line#score }" ;;
        caps\ *)  caps=" ${line#caps } " ;;
      esac
    done < <("$p" probe </dev/null 2>/dev/null)
    [[ "$score" =~ ^[0-9]+$ ]] || score=0
    if (( score > 0 )) && [[ "$caps" == *" $want "* ]]; then
      candidates+=("$(printf '%d\t%s' "$score" "$p")")
    fi
  done < <(clip::_providers)

  if (( ${#candidates[@]} == 0 )); then
    clip::_no_provider "$op" "$type"; return 3
  fi

  # Buffer stdin once for `set` so every fallback attempt gets the full payload.
  # Use a temp FILE, not a shell variable: bash variables silently drop NUL
  # bytes and trailing newlines, which corrupts binary payloads (e.g. a
  # set:image PNG). A file preserves the bytes exactly. Same for capturing a
  # get's stdout below.
  local stdin_file="" out_file rc=3 entry best
  if [[ "$op" == set ]]; then
    stdin_file="$(mktemp)"; cat > "$stdin_file"
  fi
  out_file="$(mktemp)"

  # Try candidates highest-score first; first success wins.
  while IFS= read -r entry; do
    best="${entry#*$'\t'}"
    if [[ "$op" == set ]]; then
      timeout "$timeout_s" "$best" "$op" "$type" "$@" < "$stdin_file"
      rc=$?
    else
      # Capture stdout to a file (binary-safe); emit only on success so a failed
      # provider can't leak a partial read before we fall back.
      timeout "$timeout_s" "$best" "$op" "$type" "$@" </dev/null > "$out_file"
      rc=$?
      (( rc == 0 )) && cat "$out_file"
    fi
    (( rc == 0 )) && break
  done < <(printf '%s\n' "${candidates[@]}" | sort -t$'\t' -k1,1nr)

  [[ -n "$stdin_file" ]] && rm -f "$stdin_file"
  rm -f "$out_file"
  (( rc == 0 )) && return 0
  clip::_no_provider "$op" "$type"; return 3
}

clip::_no_provider() {
  printf 'clip: no provider for %s:%s on this machine.\n' "$1" "$2" >&2
  [[ "$2" != plain ]] && printf 'clip: hint: install/enable a clip.<tag> that offers %s:%s (see sh/docs/plans/2026-06-29-unified-clipboard-design.md).\n' "$1" "$2" >&2
}

clip::real_binary() {
  : 'Resolve the real system binary for NAME, excluding our own shims.
      @arg $1 name
      @arg $@ --need-binary  require a non-text file
      @arg $@ --need-nonhome require a path outside $HOME
      @stdout absolute path of the first matching candidate
      @return 0 if found, 1 otherwise
  '
  local name="$1"; shift
  local need_binary=false need_nonhome=false a
  for a in "$@"; do
    [[ "$a" == --need-binary ]] && need_binary=true
    [[ "$a" == --need-nonhome ]] && need_nonhome=true
  done
  local c
  while IFS= read -r c; do
    [[ -x "$c" ]] || continue
    if $need_nonhome; then case "$c" in "$HOME"/*) continue ;; esac; fi
    if $need_binary; then
      case "$(file -b --mime-type "$c" 2>/dev/null)" in text/*) continue ;; esac
    fi
    printf '%s\n' "$c"; return 0
  done < <(type -af "$name" 2>/dev/null | awk '{print $NF}')
  return 1
}
