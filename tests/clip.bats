#!/usr/bin/env bats

# Test suite for clip.sh (the unified clipboard dispatcher) and the probe
# contract its providers must honour.
#
# Regression origin: micro froze ~100s on startup in a VT. micro's default
# `clipboard: external` runs `xclip -out` on launch -> our xclip shim -> clipout
# -> clip::dispatch -> `clip.gpaste probe` -> `gpaste-client --version`, which
# asks D-Bus to activate org.gnome.GPaste. With no graphical session the daemon
# cannot start, so the call blocked for D-Bus's 25s activation timeout. The
# dispatcher wrapped the *op* invocation in `timeout` but not the *probe*, so
# the stall was paid in full, once per provider-discovery pass.

setup() {
    CLIP_LIB="$(dirname "$BATS_TEST_DIRNAME")/clip.sh"
    BIN_DIR="$(dirname "$BATS_TEST_DIRNAME")/../bin"
    FAKE_BIN="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$FAKE_BIN"

    # A VT: no graphical session of any kind.
    unset DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
}

# Write an executable provider stub into $FAKE_BIN.
#   make_provider <name> <probe-body>
make_provider() {
    local name="$1" probe_body="$2"
    cat > "$FAKE_BIN/$name" <<EOF
#!/usr/bin/env bash
case "\$1" in
  probe) $probe_body ;;
  get)   printf '%s' "$name-content" ;;
  set)   cat > /dev/null ;;
esac
EOF
    chmod +x "$FAKE_BIN/$name"
}

# Run a command with only $FAKE_BIN plus the system dirs on PATH, so provider
# enumeration (compgen -c 'clip.') sees exactly the stubs we created.
with_fake_path() {
    PATH="$FAKE_BIN:/usr/bin:/bin" "$@"
}

# --- dispatcher: a stalling probe must not hang the dispatcher ---------------

@test "clip::dispatch skips a provider whose probe stalls" {
    make_provider clip.stall 'sleep 30; echo "score 90"; echo "caps get:plain set:plain"'
    make_provider clip.good  'echo "score 10"; echo "caps get:plain set:plain"'

    local start=$SECONDS
    run with_fake_path bash -c \
        "source '$CLIP_LIB'; CLIP_PROBE_TIMEOUT=1 clip::dispatch get plain"
    local elapsed=$((SECONDS - start))

    [ "$status" -eq 0 ]
    [ "$output" = "clip.good-content" ]
    # 1s probe timeout + fork overhead. Without the fix this takes 30s.
    [ "$elapsed" -lt 10 ]
}

@test "clip::dispatch fails fast when the only provider stalls on probe" {
    make_provider clip.stall 'sleep 30; echo "score 90"; echo "caps get:plain set:plain"'

    local start=$SECONDS
    run with_fake_path bash -c \
        "source '$CLIP_LIB'; CLIP_PROBE_TIMEOUT=1 clip::dispatch get plain"
    local elapsed=$((SECONDS - start))

    [ "$status" -eq 3 ]
    [ "$elapsed" -lt 10 ]
}

@test "clip::dispatch still honours a fast provider's score ordering" {
    make_provider clip.low  'echo "score 10"; echo "caps get:plain set:plain"'
    make_provider clip.high 'echo "score 90"; echo "caps get:plain set:plain"'

    run with_fake_path bash -c "source '$CLIP_LIB'; clip::dispatch get plain"

    [ "$status" -eq 0 ]
    [ "$output" = "clip.high-content" ]
}

# --- provider contract: probes must be cheap --------------------------------

# Stub the D-Bus name-owner check. "true" = daemon on the bus, "false" = not.
# Also stubs gpaste-client to stall: any use of it during a probe is the bug, so
# this makes that failure show up as a timeout rather than passing quietly.
fake_bus() {
    cat > "$FAKE_BIN/busctl" <<EOF
#!/usr/bin/env bash
echo "b $1"
EOF
    printf '#!/usr/bin/env bash\nsleep 30\n' > "$FAKE_BIN/gpaste-client"
    chmod +x "$FAKE_BIN/busctl" "$FAKE_BIN/gpaste-client"
}

@test "clip.gpaste probe scores 0 when the daemon is not on the bus" {
    fake_bus false

    local start=$SECONDS
    run env PATH="$FAKE_BIN:$PATH" "$BIN_DIR/clip.gpaste" probe
    local elapsed=$((SECONDS - start))

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "score 0" ]
    [ "$elapsed" -lt 5 ]
}

@test "clip.gpaste probe scores when the daemon is on the bus" {
    fake_bus true

    run env PATH="$FAKE_BIN:$PATH" XDG_CURRENT_DESKTOP=GNOME \
        "$BIN_DIR/clip.gpaste" probe

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "score 50" ]
    [ "${lines[1]}" = "caps get:plain set:plain" ]
}

@test "clip.gpaste probe ignores stale display vars: VT-created tmux pane, GUI up" {
    # The case that makes an environment gate wrong. A tmux pane opened in a VT
    # keeps empty DISPLAY/WAYLAND_DISPLAY for its whole life; attaching that same
    # tmux from a GUI session does not update them. But gpaste-daemon is running
    # and perfectly usable. An env gate would score this 0 and silently kill the
    # clipboard -- worse than the hang it was meant to prevent.
    fake_bus true

    run env PATH="$FAKE_BIN:$PATH" XDG_CURRENT_DESKTOP=GNOME \
        DISPLAY= WAYLAND_DISPLAY= "$BIN_DIR/clip.gpaste" probe

    [ "${lines[0]}" = "score 50" ]
}

@test "clip.gpaste probe ignores stale display vars: GUI-created pane, now in a VT" {
    # The mirror case. A pane opened under Wayland keeps WAYLAND_DISPLAY set
    # forever; used from a VT after the GUI session ends, an env gate would call
    # this provider usable when the daemon is gone.
    fake_bus false

    run env PATH="$FAKE_BIN:$PATH" WAYLAND_DISPLAY=wayland-0 \
        XDG_CURRENT_DESKTOP=GNOME "$BIN_DIR/clip.gpaste" probe

    [ "${lines[0]}" = "score 0" ]
}

# --- integration: the front-ends a VT actually hits -------------------------

@test "clipout fails fast in a VT instead of hanging" {
    local start=$SECONDS
    run "$BIN_DIR/clipout"
    local elapsed=$((SECONDS - start))

    # No provider is capable without a display; the point is that we learn that
    # quickly. micro's startup `xclip -out` is exactly this call.
    [ "$status" -eq 3 ]
    [ "$elapsed" -lt 10 ]
}
