# sh/lib/bright.sh
: 'Unified brightness dispatcher. Source-only.

    The dispatch engine lives in provider.sh, shared with clip/vol/batt
    (extracted 2026-07-29 — this file used to carry a namespaced copy of it).
    Like vol, payloads travel as argv (integer percent), never stdin, so no
    --stdin buffering is requested here; the winning-provider cache is on (the
    default) because these run off mashed keybindings.
'

source "$(dirname "${BASH_SOURCE[0]}")/provider.sh"

bright::_providers() { provider::_providers bright; }

bright::dispatch() {
  : 'Run the best capable provider for an op/control, with timeout + fallback.

      Thin wrapper over provider::dispatch — see that function for the probe,
      scoring, fallback and caching contract.

      @arg $1 op  (get|set)
      @arg $2 control (brightness)
      @arg $@ value for set (percent 1-100)
      @env BRIGHT_TIMEOUT per-provider timeout in seconds (default 5)
      @env BRIGHT_PROBE_TIMEOUT per-probe timeout in seconds (default 2)
      @env BRIGHT_CACHE_TTL winning-provider cache TTL in seconds (default 60)
      @stdout current state (for get)
      @return 0 on success, 3 if no capable provider succeeds
  '
  provider::dispatch bright "$@"
}

bright::_no_provider() {
  printf 'bright: no provider for %s:%s on this machine.\n' "$1" "$2" >&2
  printf 'bright: hint: install/enable a bright.<tag> that offers %s:%s (see sh/docs/plans/2026-07-06-unified-vol-bright-design.md).\n' "$1" "$2" >&2
}
