# sh/lib/batt.sh
: 'Unified battery dispatcher. Source-only.

    Fourth family on the shared provider.sh engine (added 2026-07-29, and the
    reason provider.sh was extracted from the clip/vol/bright copies — the
    2026-07-06 design set "a fourth provider family" as the trigger to do so).

    Unlike vol/bright this family is read-only: there is no `set`, so the
    caps vocabulary is just `get:status` and the optional `get:procs`.
    Payloads travel as argv, so no --stdin buffering; the winning-provider
    cache is on (the default), which matters for --watch redraws.

    `get:status` returns "key value" lines rather than a single scalar,
    because a battery has no one number. Every field is optional except
    state — kernels and platforms expose wildly different subsets, and a
    provider must be free to report only what it can honestly measure. The
    front-end renders whatever arrives and stays silent about the rest.

    Field vocabulary:
      state             charging|discharging|full|notcharging|unknown
      percent           integer 0-100
      watts amps volts  instantaneous rate and electrical state
      energy_now_wh energy_full_wh energy_design_wh
      health_pct        100 * full/design
      cycles            integer
      seconds_left      to empty when discharging, to full when charging
'

source "$(dirname "${BASH_SOURCE[0]}")/provider.sh"

batt::_providers() { provider::_providers batt; }

batt::dispatch() {
  : 'Run the best capable provider for an op/control, with timeout + fallback.

      Thin wrapper over provider::dispatch — see that function for the probe,
      scoring, fallback and caching contract.

      @arg $1 op  (get)
      @arg $2 control (status|procs)
      @env BATT_TIMEOUT per-provider timeout in seconds (default 5)
      @env BATT_PROBE_TIMEOUT per-probe timeout in seconds (default 2)
      @env BATT_CACHE_TTL winning-provider cache TTL in seconds (default 60)
      @stdout "key value" lines (status) or "pct<TAB>pid<TAB>cmd" (procs)
      @return 0 on success, 3 if no capable provider succeeds
  '
  provider::dispatch batt "$@"
}

batt::_no_provider() {
  printf 'batt: no provider for %s:%s on this machine.\n' "$1" "$2" >&2
  printf 'batt: hint: install/enable a batt.<tag> that offers %s:%s (see sh/docs/plans/2026-07-29-portable-batt-design.md).\n' "$1" "$2" >&2
}
