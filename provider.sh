# sh/lib/provider.sh
: 'Generic provider dispatcher shared by the clip/vol/bright/batt families.
    Source-only.

    Extracted 2026-07-29 from the three namespaced copies that clip.sh, vol.sh
    and bright.sh each carried. The 2026-07-06 vol/bright design accepted that
    duplication with an explicit trigger to revisit — "Copy dispatcher per tool
    instead of shared provider.sh — Accepted (YAGNI; don'\''t destabilize clip).
    Revisit if a fourth provider family shows up." `batt` is that fourth family.

    The three copies had diverged in exactly four ways, all of which are
    parameters here rather than forks:

      | behavior                | clip           | vol/bright/batt |
      |-------------------------|----------------|-----------------|
      | stdin buffered on `set` | yes (--stdin)  | no (argv only)  |
      | winning-provider cache  | no (--no-cache)| yes, 60s TTL    |
      | no-provider hint text   | family hook    | family hook     |
      | env var prefix          | CLIP_*         | VOL_*/BRIGHT_*/BATT_* |

    Families keep their own thin `<ns>::dispatch` wrapper so callers and the
    env-var names they already document are unchanged.
'

provider::_providers() {
  : 'List candidate provider commands on PATH for a namespace.

      @arg $1 namespace (clip|vol|bright|batt)
      @stdout one command name per line, deduped
  '
  compgen -c "$1." 2>/dev/null | sort -u
}

provider::_try() {
  : 'Run one provider attempt under `timeout`, capturing stdout.

      Reads the caller'\''s locals (op, control, timeout_s, stdin_file,
      out_file) via bash dynamic scoping — it is an inlined block of
      provider::dispatch, not a general-purpose entry point.

      stdin comes from the buffered payload when there is one and from
      /dev/null otherwise: a provider must never inherit the caller'\''s
      terminal and block on a read.

      @arg $1 provider command
      @arg $@ value args forwarded to the provider
      @return the provider'\''s exit status (124 on timeout)
  '
  local cmd="$1"; shift
  if [[ -n "$stdin_file" ]]; then
    timeout "$timeout_s" "$cmd" "$op" "$control" "$@" < "$stdin_file" > "$out_file"
  else
    timeout "$timeout_s" "$cmd" "$op" "$control" "$@" </dev/null > "$out_file"
  fi
}

provider::dispatch() {
  : 'Run the best capable provider for an op/control, with timeout + fallback.

      Providers self-rate via `probe` ("score N" then "caps ..."). Candidates
      advertising the requested capability are tried highest-score first, each
      wrapped in `timeout` (<NS>_TIMEOUT seconds, default 5); non-zero exit or
      a timeout (124) falls through to the next. Provider stdout is captured
      and emitted only on success, so a failed provider never leaks partial
      output before we fall back.

      `probe` is a provider invocation too, so it gets the same treatment on a
      tighter budget (<NS>_PROBE_TIMEOUT, default 2). By contract a probe only
      inspects the environment, so it must be near-instant; a probe that stalls
      is a broken provider and is skipped (no output -> score 0 -> not a
      candidate) rather than allowed to block the whole dispatch. This is not
      hypothetical: `clip.gpaste probe` used to shell out to `gpaste-client`,
      which asks D-Bus to activate the daemon, and in a VT that blocked for the
      full 25s D-Bus activation timeout — freezing micro on startup, the very
      bug this suite was built to kill.

      @arg $1.. --stdin    buffer stdin and replay it to every `set` attempt
      @arg $1.. --no-cache never consult or write the winning-provider cache
      @arg $1 namespace (clip|vol|bright|batt)
      @arg $2 op (get|set)
      @arg $3 control (plain|volume|mute|brightness|status|...)
      @arg $@ value for set
      @env <NS>_TIMEOUT       per-provider timeout in seconds (default 5)
      @env <NS>_PROBE_TIMEOUT per-probe timeout in seconds (default 2)
      @env <NS>_CACHE_TTL     winning-provider cache TTL in seconds (default 60)
      @stdin  payload (only with --stdin, only for set)
      @stdout provider output (for get)
      @return 0 on success, 3 if no capable provider succeeds
  '
  local use_stdin=false use_cache=true
  while true; do
    case "$1" in
      --stdin)    use_stdin=true; shift ;;
      --no-cache) use_cache=false; shift ;;
      *) break ;;
    esac
  done

  local ns="$1" op="$2" control="$3"; shift 3
  local want="$op:$control"
  local ns_uc="${ns^^}" v

  # Per-family env knobs, resolved by indirection so one dispatcher serves
  # CLIP_TIMEOUT, VOL_TIMEOUT, BRIGHT_TIMEOUT and BATT_TIMEOUT alike.
  v="${ns_uc}_TIMEOUT";       local timeout_s="${!v:-5}"
  v="${ns_uc}_PROBE_TIMEOUT"; local probe_timeout_s="${!v:-2}"
  v="${ns_uc}_CACHE_TTL";     local cache_ttl="${!v:-60}"

  local p score caps line
  local stdin_file="" out_file rc=3 entry best

  # Buffer stdin ONCE, before any attempt, so every fallback gets the full
  # payload. Use a temp FILE, not a shell variable: bash variables silently
  # drop NUL bytes and trailing newlines, which corrupts binary payloads (e.g.
  # a clip set:image PNG). A file preserves the bytes exactly. Same for
  # capturing a get's stdout below.
  if $use_stdin && [[ "$op" == set ]]; then
    stdin_file="$(mktemp)"; cat > "$stdin_file"
  fi
  out_file="$(mktemp)"

  # Fast path: reuse the last winning provider for this op/control. A full
  # probe sweep costs ~90ms — too slow for a mashed keybinding. Entries live
  # in XDG_RUNTIME_DIR (cleared on logout/reboot) and expire two ways:
  #   - TTL (<NS>_CACHE_TTL seconds, default 60): bounds how long a
  #     stale-but-still-working winner can shadow a better backend after a
  #     backend-stack change.
  #   - failure: a cached provider that errors is dropped and the fresh probe
  #     sweep below takes over within this same invocation — a backend swap
  #     never errors a keypress, it just pays the probe cost once.
  # File format: line 1 provider name, line 2 epoch written. The timestamp is
  # read/written with bash's %(%s)T builtin (no stat(1) GNU/BSD portability
  # mess); the date(1) fallback covers pre-4.2 bash (macOS /bin/bash).
  #
  # clip opts out (--no-cache): it is the family whose probe once froze micro,
  # and keeping it uncached made the 2026-07-29 extraction a behavior-
  # preserving refactor that its existing bats suite could actually gate.
  local cache_file="${XDG_RUNTIME_DIR:-/tmp}/${ns}.provider.$want"
  local cached cached_at now
  printf -v now '%(%s)T' -1 2>/dev/null || now=$(date +%s)
  if $use_cache && [[ -r "$cache_file" ]]; then
    { IFS= read -r cached; IFS= read -r cached_at; } < "$cache_file"
    [[ "$cached_at" =~ ^[0-9]+$ ]] || cached_at=0
    if (( now - cached_at < cache_ttl )) && command -v "$cached" >/dev/null 2>&1; then
      if provider::_try "$cached" "$@"; then
        cat "$out_file"
        rm -f "$out_file"; [[ -n "$stdin_file" ]] && rm -f "$stdin_file"
        return 0
      fi
    fi
    rm -f "$cache_file"
  fi

  # Collect capable providers as "score<TAB>path", then order by score desc.
  # A probe that overruns its budget is killed and emits nothing, which leaves
  # score at 0 and drops the provider from the running -- discovery must never
  # be able to hang the dispatch.
  #
  # Probes run in PARALLEL. They are independent and side-effect-free by
  # contract, and it is the timeout(1) wrapper, not the probes, that dominates
  # the sweep: where coreutils is uutils' (Ubuntu 25.10 default, package
  # coreutils-from-uutils) `timeout` takes ~110ms just to start, against ~4ms
  # for siblings like `cat` and `env` out of the same multi-call binary. Serial
  # that is ~0.7s a sweep; parallel it is ~0.15s. micro runs four clip
  # dispatches on startup, so this is seconds of editor latency rather than
  # milliseconds.
  local -a candidates=() plist=() pids=()
  local probe_dir idx
  probe_dir="$(mktemp -d)"
  while IFS= read -r p; do
    idx="${#plist[@]}"
    plist+=("$p")
    timeout "$probe_timeout_s" "$p" probe </dev/null > "$probe_dir/$idx" 2>/dev/null &
    pids+=("$!")
  done < <(provider::_providers "$ns")
  # Wait only on our own probes, so a caller with background jobs of its own is
  # unaffected. Exit statuses are deliberately ignored: a timed-out probe (124)
  # is indistinguishable from an unusable one, and both mean "not a candidate".
  [[ ${#pids[@]} -gt 0 ]] && wait "${pids[@]}" 2>/dev/null
  for idx in "${!plist[@]}"; do
    p="${plist[idx]}" score=0 caps=""
    while IFS= read -r line; do
      case "$line" in
        score\ *) score="${line#score }" ;;
        caps\ *)  caps=" ${line#caps } " ;;
      esac
    done < "$probe_dir/$idx"
    [[ "$score" =~ ^[0-9]+$ ]] || score=0
    if (( score > 0 )) && [[ "$caps" == *" $want "* ]]; then
      candidates+=("$(printf '%d\t%s' "$score" "$p")")
    fi
  done
  rm -rf "$probe_dir"

  if (( ${#candidates[@]} == 0 )); then
    rm -f "$out_file"; [[ -n "$stdin_file" ]] && rm -f "$stdin_file"
    provider::_no_provider "$ns" "$op" "$control"; return 3
  fi

  # Try candidates highest-score first; first success wins and is cached.
  while IFS= read -r entry; do
    best="${entry#*$'\t'}"
    provider::_try "$best" "$@"
    rc=$?
    if (( rc == 0 )); then
      cat "$out_file"
      $use_cache && printf '%s\n%s\n' "$best" "$now" > "$cache_file"
      break
    fi
  done < <(printf '%s\n' "${candidates[@]}" | sort -t$'\t' -k1,1nr)

  rm -f "$out_file"; [[ -n "$stdin_file" ]] && rm -f "$stdin_file"
  (( rc == 0 )) && return 0
  provider::_no_provider "$ns" "$op" "$control"; return 3
}

provider::_no_provider() {
  : 'Report that nothing could serve op:control.

      Families may define `<ns>::_no_provider op control` to customise the
      wording (clip suppresses its install hint for the always-expected
      `plain` type); otherwise a generic message is printed.

      @arg $1 namespace
      @arg $2 op
      @arg $3 control
  '
  local ns="$1" op="$2" control="$3"
  if declare -F "${ns}::_no_provider" >/dev/null 2>&1; then
    "${ns}::_no_provider" "$op" "$control"; return
  fi
  printf '%s: no provider for %s:%s on this machine.\n' "$ns" "$op" "$control" >&2
  printf '%s: hint: install/enable a %s.<tag> that offers %s:%s.\n' \
    "$ns" "$ns" "$op" "$control" >&2
}
