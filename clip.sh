# sh/lib/clip.sh
: 'Unified clipboard dispatcher. Source-only.

    The dispatch engine itself lives in provider.sh, shared with vol/bright/batt
    (extracted 2026-07-29). clip keeps two family-specific traits, both passed
    as flags:
      --stdin    clipboard payloads travel on stdin and must survive NUL bytes
                 and replay to a fallback provider.
      --no-cache clip deliberately re-probes every dispatch. It is the family
                 whose probe once froze micro for 100s, and staying uncached
                 kept the extraction a behavior-preserving refactor that
                 tests/clip/*.bats could gate.
'

source "$(dirname "${BASH_SOURCE[0]}")/provider.sh"

clip::_providers() { provider::_providers clip; }

clip::dispatch() {
  : 'Run the best capable provider for an op/type, with timeout + fallback.

      Thin wrapper over provider::dispatch — see that function for the probe,
      scoring, fallback and binary-safety contract.

      @arg $1 op  (get|set)
      @arg $2 type (plain|rich|image)
      @env CLIP_TIMEOUT per-provider timeout in seconds (default 5)
      @env CLIP_PROBE_TIMEOUT per-probe timeout in seconds (default 2)
      @stdin  content (for set)
      @stdout clipboard content (for get)
      @return 0 on success, 3 if no capable provider succeeds
  '
  provider::dispatch --stdin --no-cache clip "$@"
}

clip::dbus_has_owner() {
  : 'True if NAME currently has an owner on the session bus.

      The cheap liveness check providers should use instead of "run the client
      and see if it works". Running the client asks D-Bus to ACTIVATE the
      service, and activating one that cannot start (a daemon with no graphical
      session to attach to) blocks for the full 25s bus timeout. NameHasOwner
      only asks the bus what it already knows: ~20ms, never activates.

      Prefer this over $DISPLAY/$WAYLAND_DISPLAY sniffing. Those are process
      environment, and in a tmux session shared across a GUI and VTs they are
      frozen at pane-creation time -- a pane opened in a VT keeps empty display
      vars forever, even while a graphical session is up. Daemon liveness is a
      live fact and stays correct across VT switches.

      @arg $1 well-known bus name
      @return 0 if the name is currently owned, 1 otherwise (including no bus
              and no usable D-Bus CLI)
  '
  local name="$1"
  [[ -n "$DBUS_SESSION_BUS_ADDRESS" || -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/bus" ]] || return 1
  if command -v busctl >/dev/null 2>&1; then
    [[ "$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
            org.freedesktop.DBus NameHasOwner s "$name" 2>/dev/null)" == "b true" ]]
  elif command -v gdbus >/dev/null 2>&1; then
    [[ "$(gdbus call --session -d org.freedesktop.DBus -o /org/freedesktop/DBus \
            -m org.freedesktop.DBus.NameHasOwner "$name" 2>/dev/null)" == "(true,)" ]]
  else
    return 1
  fi
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
