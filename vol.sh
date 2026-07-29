# sh/lib/vol.sh
: 'Unified volume dispatcher. Source-only.

    The dispatch engine lives in provider.sh, shared with clip/bright/batt
    (extracted 2026-07-29 — this file used to carry a namespaced copy of it).
    Volume ops carry their payload as argv (integer percent / mute state),
    never stdin, so no --stdin buffering is requested here; the winning-provider
    cache is on (the default) because these run off mashed keybindings.
'

source "$(dirname "${BASH_SOURCE[0]}")/provider.sh"

vol::_providers() { provider::_providers vol; }

vol::dispatch() {
  : 'Run the best capable provider for an op/control, with timeout + fallback.

      Thin wrapper over provider::dispatch — see that function for the probe,
      scoring, fallback and caching contract.

      @arg $1 op  (get|set)
      @arg $2 control (volume|mute)
      @arg $@ value for set (percent 0-100, or on|off|toggle for mute)
      @env VOL_TIMEOUT per-provider timeout in seconds (default 5)
      @env VOL_PROBE_TIMEOUT per-probe timeout in seconds (default 2)
      @env VOL_CACHE_TTL winning-provider cache TTL in seconds (default 60)
      @stdout current state (for get)
      @return 0 on success, 3 if no capable provider succeeds
  '
  provider::dispatch vol "$@"
}

vol::_no_provider() {
  printf 'vol: no provider for %s:%s on this machine.\n' "$1" "$2" >&2
  printf 'vol: hint: install/enable a vol.<tag> that offers %s:%s (see sh/docs/plans/2026-07-06-unified-vol-bright-design.md).\n' "$1" "$2" >&2
}
