// Adapted from ootss-cmd's solution timeline. Keys are game turns, not OS events.
#load "cache.jai";
TAS_KEY_LIMIT :: 65536;

Tas_Snapshot :: struct {
    state, restart: Game_State;
    message: string;
    againing, won: bool;
    again_ms: float;
}

Tas :: struct {
    session: Session;              // Borrows its level from the owning UI/test.
    start: Tas_Snapshot;
    keys: [..] u8;
    playhead, caret, anchor: int;
    recording, playing, dirty: bool;
    delay_ms := 150.0;
    elapsed_ms: float;
    cache: Tas_Cache;
    seek_target: int = -1;
}

// -----------------------------------------------------------------------------: lifecycle

tas_snapshot_free :: (snapshot: *Tas_Snapshot) {
    state_free(*snapshot.state);
    state_free(*snapshot.restart);
    free(snapshot.message);
    snapshot.* = .{};
}

tas_free :: (t: *Tas) {
    session_clear(*t.session);
    array_free(t.session.undo_diffs);
    array_free(t.session.sound_commands);
    state_free(*t.session.state);
    state_free(*t.session.restart_target);
    state_free(*t.session.undo_top);
    tas_snapshot_free(*t.start);
    tas_cache_free(t);
    array_free(t.keys);
    t.* = .{};
}

tas_capture :: (t: *Tas, source: *Session) {
    tas_free(t);
    t.session.level = source.level;
    state_copy(*t.start.state, source.state);
    state_copy(*t.start.restart, source.restart_target);
    t.start.message = copy_string(source.message);
    t.start.againing = source.againing;
    t.start.again_ms = source.again_ms;
    t.start.won = source.won;
    tas_restore(t);
}

tas_restore :: (t: *Tas) {
    s := *t.session;
    session_clear(s);
    state_copy(*s.state, t.start.state);
    state_copy(*s.restart_target, t.start.restart);
    s.message = t.start.message;
    s.againing = t.start.againing;
    s.again_ms = t.start.again_ms;
    s.won = t.start.won;
    s.no_save = true;
    s.no_undo = true;
    s.inputs_since_save = 0;
    t.playhead = 0;
    t.elapsed_ms = 0;
    session_bind(s);
}

tas_pause :: (t: *Tas) {
    t.playing = false;
    t.elapsed_ms = 0;
    t.seek_target = -1;
}

// -----------------------------------------------------------------------------: input and transport

tas_key_valid :: (key: u8) -> bool { return contains("WASDXR", key); }

tas_direction :: (key: u8) -> Dir {
    if key == {
        case #char "W"; return .UP;
        case #char "A"; return .LEFT;
        case #char "S"; return .DOWN;
        case #char "D"; return .RIGHT;
        case #char "X"; return .ACTION;
    }
    return .NONE;
}

tas_apply :: (t: *Tas, key: u8) -> bool {
    s := *t.session;
    if s.message {
        if key != #char "X" return false;
        session_dismiss_message(s);
        return true;
    }
    if s.won || s.againing return false;
    if key == #char "R" {
        session_restart(s);
        return true;
    }
    if !tas_key_valid(key) return false;
    return session_input(s, tas_direction(key));
}

tas_record :: (t: *Tas, key: u8) -> bool {
    if !t.recording || !tas_key_valid(key) || t.keys.count >= TAS_KEY_LIMIT return false;
    tas_pause(t);
    // Record only accepted turns. again/cancel/no-op inputs create no ghost cells.
    tas_cache_capture(t);
    if !tas_apply(t, key) return false;
    tas_cache_trim(t, t.playhead);
    array_insert_at(*t.keys, key, t.playhead);
    t.playhead += 1;
    t.caret = t.playhead;
    t.anchor = t.caret;
    t.dirty = true;
    tas_cache_capture(t);
    return true;
}

tas_step :: (t: *Tas) -> bool {
    s := *t.session;
    if t.playhead >= t.keys.count || (s.againing && !s.message && !s.won) return false;
    // An edited script may contain a blocked turn; consume it exactly once.
    tas_cache_capture(t);
    tas_apply(t, t.keys[t.playhead]);
    t.playhead += 1;
    t.caret = t.playhead;
    t.anchor = t.caret;
    tas_cache_capture(t);
    return true;
}

tas_settle :: (t: *Tas) {
    // Messages suspend again ticks until an explicit X, just like session_update.
    guard := 0;
    while t.session.againing && !t.session.message && !t.session.won {
        again_step(*t.session);
        guard += 1;
        if guard >= 10000 { t.session.againing = false; break; }
    }
    t.session.again_ms = 0;
    tas_cache_capture(t);
}

tas_seek :: (t: *Tas, target: int) {
    tas_pause(t);
    target = clamp(target, 0, t.keys.count);
    previous_headless := t.session.headless;
    t.session.headless = true;
    tas_cache_capture(t);
    if !t.cache.turns.count tas_settle(t);
    tas_cache_restore(t, min(target, t.cache.turns.count - 1));
    while t.playhead < target {
        tas_settle(t);
        tas_step(t);
    }
    tas_settle(t);
    array_reset(*t.session.sound_commands);
    t.session.headless = previous_headless;
    t.session.jumps += 1;
    t.caret = target;
    t.anchor = target;
}

tas_update :: (t: *Tas, dt_ms: float) {
    if t.seek_target >= 0 { tas_update_seek(t); return; }
    session_update(*t.session, dt_ms);
    tas_cache_capture(t);
    if !t.playing return;
    t.elapsed_ms += dt_ms;
    if t.elapsed_ms < t.delay_ms return;
    if tas_step(t) t.elapsed_ms = 0;
    if t.playhead == t.keys.count tas_pause(t);
}

// Build unvisited turns over multiple frames; cached targets need no rule ticks.
tas_request_seek :: (t: *Tas, target: int) {
    tas_pause(t);
    target = clamp(target, 0, t.keys.count);
    tas_cache_capture(t);
    if target < t.cache.turns.count { tas_cache_restore(t, target); return; }
    if t.cache.turns.count tas_cache_restore(t, t.cache.turns.count - 1);
    t.seek_target = target;
}

tas_update_seek :: (t: *Tas) {
    target := t.seek_target;
    previous_headless := t.session.headless;
    t.session.headless = true;
    defer t.session.headless = previous_headless;
    started := current_time_monotonic();
    for 0..7 {
        if t.session.againing && !t.session.message && !t.session.won {
            again_step(*t.session);
        } else {
            tas_cache_capture(t);
            if t.playhead == target {
                t.seek_target = -1;
                t.session.again_ms = 0;
                t.session.jumps += 1;
                break;
            }
            tas_step(t);
        }
        if to_milliseconds(current_time_monotonic() - started) >= 8 break;
    }
    array_reset(*t.session.sound_commands);
}

// -----------------------------------------------------------------------------: editing

tas_selection :: (t: *Tas) -> int, int {
    return min(t.caret, t.anchor), max(t.caret, t.anchor);
}

tas_move_caret :: (t: *Tas, target: int, select := false) {
    t.caret = clamp(target, 0, t.keys.count);
    if !select t.anchor = t.caret;
}

tas_parse :: (source: string) -> string, string {
    keys: [..] u8;
    defer array_free(keys);
    i := 0;
    while i < source.count {
        c := source[i];
        i += 1;
        if contains(" \t\r\n", c) continue;
        if c >= #char "a" && c <= #char "z" c -= #char "a" - #char "A";
        if !tas_key_valid(c) return "", "Use W/A/S/D, X (action/message), R (restart), and repeats such as W3.";
        count := 0;
        digits := false;
        while i < source.count && source[i] >= #char "0" && source[i] <= #char "9" {
            count = count * 10 + source[i] - #char "0";
            if count > TAS_KEY_LIMIT return "", "Too many steps (limit 65536).";
            digits = true;
            i += 1;
        }
        if !digits count = 1;
        if count == 0 || keys.count + count > TAS_KEY_LIMIT return "", "Repeat count must be 1..65536; total limit 65536.";
        for 0..count-1 array_add(*keys, c);
    }
    return copy_string(string.{keys.count, keys.data}), "";
}

tas_replace :: (t: *Tas, first: int, last: int, source: string) -> string {
    if first < 0 || last < first || last > t.keys.count return "Invalid selection.";
    keys, error := tas_parse(source);
    defer free(keys);
    if error return error;
    if t.keys.count - (last - first) + keys.count > TAS_KEY_LIMIT return "Too many steps (limit 65536).";
    tas_pause(t);
    t.recording = false;
    // Rewind before changing executed history, then rebuild the surviving prefix.
    head := min(t.playhead, first);
    tas_seek(t, head);
    tas_cache_trim(t, first);
    for i: last..t.keys.count-1 t.keys[i - (last - first)] = t.keys[i];
    t.keys.count -= last - first;
    for key: keys array_insert_at(*t.keys, key, first + it_index);
    tas_move_caret(t, first + keys.count);
    t.dirty = true;
    return "";
}

#scope_file
#import "Basic";
#import "String";
#import "Math";
