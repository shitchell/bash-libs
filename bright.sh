# sh/lib/bright.sh
: 'Unified brightness dispatcher. Source-only.

    Namespaced copy of clip.sh'\''s dispatcher (see
    docs/plans/2026-07-06-unified-vol-bright-design.md — copied per tool
    rather than extracted to a shared lib so the working clip system stays
    untouched). Like vol.sh, payloads travel as argv (integer percent), never
    stdin, so there is no binary-safe stdin buffering here.
'

bright::_providers() { compgen -c 'bright.' 2>/dev/null | sort -u; }

bright::dispatch() {
  : 'Run the best capable provider for an op/control, with timeout + fallback.

      Providers self-rate via `probe` ("score N" then "caps ..."). Candidates
      advertising the requested capability are tried highest-score first, each
      wrapped in `timeout` (BRIGHT_TIMEOUT seconds, default 5); non-zero exit
      or a timeout (124) falls through to the next. Provider stdout is
      captured and emitted only on success so a failed provider never leaks
      partial output before we fall back.

      @arg $1 op  (get|set)
      @arg $2 control (brightness)
      @arg $@ value for set (percent 1-100)
      @env BRIGHT_TIMEOUT per-provider timeout in seconds (default 5)
      @stdout current state (for get)
      @return 0 on success, 3 if no capable provider succeeds
  '
  local op="$1" control="$2"; shift 2
  local want="$op:$control" timeout_s="${BRIGHT_TIMEOUT:-5}"
  local p score caps line

  # Fast path: reuse the last winning provider for this op/control, with a
  # TTL (BRIGHT_CACHE_TTL, default 60s) and failure invalidation — see the
  # twin comment in vol.sh for the full tradeoff discussion and file format.
  local cache_file="${XDG_RUNTIME_DIR:-/tmp}/bright.provider.$want"
  local cache_ttl="${BRIGHT_CACHE_TTL:-60}" cached cached_at now out_file
  printf -v now '%(%s)T' -1 2>/dev/null || now=$(date +%s)
  out_file="$(mktemp)"
  if [[ -r "$cache_file" ]]; then
    { IFS= read -r cached; IFS= read -r cached_at; } < "$cache_file"
    [[ "$cached_at" =~ ^[0-9]+$ ]] || cached_at=0
    if (( now - cached_at < cache_ttl )) && command -v "$cached" >/dev/null 2>&1; then
      if timeout "$timeout_s" "$cached" "$op" "$control" "$@" </dev/null > "$out_file"; then
        cat "$out_file"; rm -f "$out_file"; return 0
      fi
    fi
    rm -f "$cache_file"
  fi

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
  done < <(bright::_providers)

  if (( ${#candidates[@]} == 0 )); then
    rm -f "$out_file"
    bright::_no_provider "$op" "$control"; return 3
  fi

  local rc=3 entry best

  # Try candidates highest-score first; first success wins and is cached.
  while IFS= read -r entry; do
    best="${entry#*$'\t'}"
    timeout "$timeout_s" "$best" "$op" "$control" "$@" </dev/null > "$out_file"
    rc=$?
    (( rc == 0 )) && { cat "$out_file"; printf '%s\n%s\n' "$best" "$now" > "$cache_file"; break; }
  done < <(printf '%s\n' "${candidates[@]}" | sort -t$'\t' -k1,1nr)

  rm -f "$out_file"
  (( rc == 0 )) && return 0
  bright::_no_provider "$op" "$control"; return 3
}

bright::_no_provider() {
  printf 'bright: no provider for %s:%s on this machine.\n' "$1" "$2" >&2
  printf 'bright: hint: install/enable a bright.<tag> that offers %s:%s (see sh/docs/plans/2026-07-06-unified-vol-bright-design.md).\n' "$1" "$2" >&2
}
