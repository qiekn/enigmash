// Unobstructed playback for video capture. The finished/interrupted frame stays
// visible, and the editor's take and campaign are left intact.
do_run: Tas;
do_active: bool;
do_escape_held: bool;

free_cloned_level :: (level: *Level) {
    for level.messages { free(it.id); free(it.text); }
    level_free(level);
    array_free(level.messages);
    array_free(level.tunnels);
    level.* = .{};
}

do_stop :: () {
    do_active = false;
    tas_pause(*do_run);
    do_run.session.no_undo = false;
    release_player_keys();
}

do_command :: (arguments: string) -> string {
    // Validation uses temporary sessions; restore the visible binding on every exit.
    defer session_bind(play_session);
    if program_mode == .EDITOR return "Start a level playtest (F5) before do.";
    words := split(trim(arguments), " ",, temp);
    script: String_Builder;
    defer free_buffers(*script);
    delay: int = -1;
    i := 0;
    while i < words.count {
        word := words[i];
        i += 1;
        if !word continue;
        if equal_nocase(word, "-delay") {
            if delay >= 0 || i >= words.count return "Usage: do [name|WASD script] [-delay 1..10000]";
            value, ok, rest := string_to_int(words[i]);
            i += 1;
            if !ok || rest || value < 1 || value > 10000 return "Delay must be 1..10000 ms.";
            delay = value;
        } else {
            append(*script, word);
            append(*script, " ");
        }
    }
    requested := trim(builder_to_string(*script,, temp));
    source := play_session.*;
    if !requested {
        if !tas_has_take || !tas.keys.count return "Usage: do <saved name|WASD script>; do alone plays the current take.";
        source = tas.session;
    }
    next_level := level_clone(*source.level);
    defer free_cloned_level(*next_level);
    source.level = next_level;
    next: Tas;
    defer tas_free(*next);
    tas_capture(*next, *source);
    if !requested {
        data := tas_encode(*tas);
        defer free(data);
        error := tas_decode(*next, data);
        if error return error;
    } else if tas_name_valid(requested) && file_exists(tas_file_path(requested)) {
        path := tas_file_path(requested);
        _, size, size_ok := file_modtime_and_size(path);
        if !size_ok || size > 16777216 return "Recording is unreadable or too large.";
        data, ok := read_entire_file(path);
        if !ok return "Could not read recording.";
        defer free(data);
        error := tas_decode(*next, data);
        if error return error;
    } else {
        keys, error := tas_parse(requested);
        defer free(keys);
        if error return "Recording not found or invalid script. Use do <name> or do W3ASD.";
        for keys array_add(*next.keys, it);
    }
    if !next.keys.count return "The recording/script is empty.";
    if delay >= 0 next.delay_ms = cast(float) delay;

    // Only switch the visible session after all arguments and file data validate.
    if tas_active tas_close();
    do_stop();
    old_level := do_run.session.level;
    tas_free(*do_run);
    free_cloned_level(*old_level);
    do_run = next;
    next = .{};
    next_level = .{};
    play_session = *do_run.session;
    program_mode = .GAME;
    menu_return_mode = .GAME;
    game_camera.bounds = .{cast(float) do_run.session.level.w, cast(float) do_run.session.level.h};
    update_game_camera_target();
    camera_reset(*game_camera);
    terminal_hide();
    do_run.playing = true;
    do_run.elapsed_ms = do_run.delay_ms;
    do_active = true;
    session_bind(play_session);
    return "";
}

do_update :: (dt_ms: float) {
    if !do_active return;
    tas_update(*do_run, dt_ms);
    if !do_run.playing && (!do_run.session.againing || do_run.session.message || do_run.session.won) do_stop();
}

do_handle_event :: (event: Event) -> bool {
    if do_escape_held && event.type == .KEYBOARD && event.key_code == .ESCAPE {
        if !event.key_pressed do_escape_held = false;
        return true;
    }
    if !do_active || event.type != .KEYBOARD return false;
    if event.key_code == .ESCAPE {
        if event.key_pressed { do_escape_held = true; do_stop(); }
        return true;
    }
    // Console shortcuts still work; opening the console stops the run.
    if event.key_code == .F1 || event.key_code == #char ";" || event.key_code == #char ":" return false;
    // Camera controls remain available without forwarding physical game input.
    handle_game_camera_event(event);
    return true;
}
