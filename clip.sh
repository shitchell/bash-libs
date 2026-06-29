# sh/lib/clip.sh
: 'Unified clipboard dispatcher. Source-only.'

clip::_providers() { compgen -c 'clip.' 2>/dev/null | sort -u; }

clip::dispatch() {
  : 'Run the best provider for an op/type.
      @arg $1 op  (get|set)
      @arg $2 type (plain|rich|image)
      @stdin  content (for set)
      @stdout clipboard content (for get)
  '
  local op="$1" type="$2"; shift 2
  local want="$op:$type" best="" bestscore=0 p score caps line
  while IFS= read -r p; do
    score=0 caps=""
    while IFS= read -r line; do
      case "$line" in
        score\ *) score="${line#score }" ;;
        caps\ *)  caps=" ${line#caps } " ;;
      esac
    done < <("$p" probe </dev/null 2>/dev/null)
    [[ "$score" =~ ^[0-9]+$ ]] || score=0
    if (( score > bestscore )) && [[ "$caps" == *" $want "* ]]; then
      best="$p"; bestscore="$score"
    fi
  done < <(clip::_providers)
  if [[ -z "$best" ]]; then
    clip::_no_provider "$op" "$type"; return 3
  fi
  "$best" "$op" "$type" "$@"
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
