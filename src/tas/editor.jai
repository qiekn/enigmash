// Game-owned TAS workspace. Closing it retains the take and restores the game.
tas: Tas;
tas_active, tas_has_take: bool;
tas_level: Level;
tas_return_session: *Session;
tas_return_mode: Program_Mode;
tas_return_camera: Camera;
tas_name: string;
tas_status: string;
tas_view_head: int;
tas_dragging: bool;
tas_drag_select, tas_drag_moved: bool;
tas_drag_x, tas_drag_origin, tas_drag_click: int;

tas_set_status :: (message: string) {
    owned := copy_string(message);
    free(tas_status);
    tas_status = owned;
}

tas_open :: () -> bool {
    if tas_active return true;
    if program_mode == .EDITOR {
        tas_set_status("Start a level playtest (F5), then open editor.");
        return false;
    }
    tas_return_session = play_session;
    tas_return_mode = program_mode;
    tas_return_camera = game_camera;
    if !tas_has_take tas_new_take();
    tas_active = true;
    play_session = *tas.session;
    program_mode = .GAME;
    game_camera.bounds = .{cast(float) tas_level.w, cast(float) tas_level.h};
    release_player_keys();
    update_game_camera_target();
    camera_reset(*game_camera);
    return true;
}

tas_new_take :: () {
    tas_free(*tas);
    for tas_level.messages { free(it.id); free(it.text); }
    level_free(*tas_level);
    array_free(tas_level.messages);
    array_free(tas_level.tunnels);
    tas_level = level_clone(*tas_return_session.level);
    fresh: Tas;
    defer tas_free(*fresh);
    fresh.session.level = tas_level;
    fresh.session.headless = true;
    fresh.session.no_save = true;
    session_new_game(*fresh.session, show_intro = false);
    tas_capture(*tas, *fresh.session);
    tas_has_take = true;
    tas_view_head = 0;
    tas_last_caret = -1;
    tas_last_head = -1;
    free(tas_name);
    tas_name = "";
    tas_set_status("At game start. Record (F8), or type WASD to edit the timeline.");
    if tas_active {
        release_player_keys();
        game_camera.bounds = .{cast(float) tas_level.w, cast(float) tas_level.h};
        update_game_camera_target();
        camera_reset(*game_camera);
    }
}

tas_close :: () {
    if !tas_active return;
    tas_pause(*tas);
    tas.recording = false;
    tas_active = false;
    tas_dragging = false;
    release_player_keys();
    array_reset(*tas.session.sound_commands);
    play_session = tas_return_session;
    program_mode = tas_return_mode;
    game_camera = tas_return_camera;
    session_bind(play_session);
}

tas_toggle_record :: () {
    tas_pause(*tas);
    tas.recording = !tas.recording;
    release_player_keys();
    tas_set_status(ifx tas.recording then "Recording accepted WASD turns. Z: back; X: action; F8: stop."
                   else "Edit: WASD insert; Shift+arrows select; Delete removes; click Play to replay.");
}

tas_toggle_play :: () {
    tas.recording = false;
    release_player_keys();
    if tas.playing { tas_pause(*tas); return; }
    if tas.playhead == tas.keys.count tas_seek(*tas, 0);
    tas.playing = tas.keys.count > 0;
    tas.elapsed_ms = tas.delay_ms;
}

tas_game_action :: (key: u8) {
    if tas.keys.count >= TAS_KEY_LIMIT {
        tas_set_status("Recording is full (65536 steps). Save this take.");
        return;
    }
    tas_record(*tas, key);
}

tas_insert_text :: (source: string) {
    first, last := tas_selection(*tas);
    error := tas_replace(*tas, first, last, source);
    tas_set_status(ifx error then error else "Timeline updated; playback resumes from the unchanged prefix.");
}

tas_delete_selection :: (backwards: bool) {
    first, last := tas_selection(*tas);
    if first == last {
        if backwards first = max(0, first - 1);
        else last = min(tas.keys.count, last + 1);
    }
    if first < last tas_set_status(tas_replace(*tas, first, last, ""));
}

tas_file_path :: (name: string) -> string {
    return tprint("%/tas/%.tas", SAVE_DIR, name);
}

tas_name_valid :: (name: string) -> bool {
    if !name || name.count > 80 return false;
    for name if !((it >= #char "a" && it <= #char "z") || (it >= #char "A" && it <= #char "Z") ||
                  (it >= #char "0" && it <= #char "9") || it == #char "_" || it == #char "-") return false;
    return true;
}

tas_save_take :: (requested: string) -> string {
    name := requested;
    if !name name = ifx tas_name then tas_name else "recording";
    if !tas_name_valid(name) return "Name: use letters, digits, _ or - (up to 80 characters).";
    if !make_directory_if_it_does_not_exist(tprint("%/tas", SAVE_DIR), recursive = true) return "Could not create save/tas.";
    data := tas_encode(*tas);
    defer free(data);
    if !write_entire_file(tas_file_path(name), data) return "Could not save recording.";
    owned := copy_string(name);
    free(tas_name);
    tas_name = owned;
    tas.dirty = false;
    return tprint("Saved % (% steps).", tas_file_path(tas_name), tas.keys.count);
}

tas_request_save :: () {
    if tas_name { tas_set_status(tas_save_take("")); return; }
    terminal_show(mini = true);
    terminal_set_input("save ");
    tas_set_status("Type a recording name after save, then press Enter.");
}

tas_load_take :: (name: string, discard := false) -> string, bool {
    if !tas_name_valid(name) return "Name: use letters, digits, _ or -.", false;
    if tas.dirty && !discard return "Unsaved take. Save first, or use load! <name> to replace it.", false;
    path := tas_file_path(name);
    _, size, size_ok := file_modtime_and_size(path);
    if !size_ok || size > 16777216 return "Recording missing or too large (16 MiB limit).", false;
    data, ok := read_entire_file(path);
    if !ok return "Could not read recording.", false;
    defer free(data);
    error := tas_decode(*tas, data);
    if error return error, false;
    free(tas_name);
    tas_name = copy_string(name);
    tas_view_head = 0;
    tas_last_caret = -1;
    tas_last_head = -1;
    return tprint("Loaded % (% steps). Play starts from its saved snapshot.", name, tas.keys.count), true;
}

// -----------------------------------------------------------------------------: editor input

tas_scrub_to :: (target: int) {
    target = clamp(target, 0, tas.keys.count);
    tas.recording = false;
    tas_view_head = target;
    current_target := ifx tas.seek_target >= 0 then tas.seek_target else tas.playhead;
    if target != current_target tas_request_seek(*tas, target);
}

tas_drag_begin :: (x: int, select := false, seek := false) {
    tas_pause(*tas);
    tas.recording = false;
    release_player_keys();
    tas_dragging = !seek;
    tas_drag_select = select;
    tas_drag_moved = false;
    tas_drag_x = x;
    tas_drag_origin = tas_view_head;
    tas_drag_click = tas_hit_index(x);
    if seek tas_scrub_to(tas_drag_click);
    else if select tas_move_caret(*tas, tas_drag_click, select = true);
}

tas_drag_move :: (x: int) {
    if !tas_dragging return;
    if tas_drag_select { tas_move_caret(*tas, tas_hit_index(x), select = true); return; }
    delta := x - tas_drag_x;
    if abs(delta) >= 4 tas_drag_moved = true;
    if tas_drag_moved tas_scrub_to(tas_drag_origin - cast(int) floor(cast(float) delta / TAS_CELL_PITCH + 0.5));
}

tas_drag_end :: (x: int) {
    if !tas_dragging return;
    tas_drag_move(x);
    if !tas_drag_select && !tas_drag_moved tas_scrub_to(tas_drag_click);
    tas_dragging = false;
}

tas_update_pointer :: () {
    if !tas_dragging return;
    mx, my, ok := get_mouse_pointer_position(the_window, true);
    if ok tas_drag_move(mx);
}

tas_handle_event :: (event: Event) -> bool {
    if !tas_active return false;
    if event.type == .MOUSE_WHEEL {
        mx, my, ok := get_mouse_pointer_position(the_window, true);
        if ok && tas_hit_rect(tas_panel_rect(), mx, my) {
            if event.wheel_delta == 0 return true;
            release_player_keys();
            delta := ifx event.wheel_delta > 0 then -1 else 1;
            head := ifx tas.seek_target >= 0 then tas.seek_target else tas.playhead;
            tas_scrub_to(head + delta);
            return true;
        }
    }
    if event.type != .KEYBOARD return false;
    key := event.key_code;
    if key == .MOUSE_BUTTON_LEFT {
        mx, my, ok := get_mouse_pointer_position(the_window, true);
        if !event.key_pressed {
            was_dragging := tas_dragging;
            if ok tas_drag_end(mx);
            else tas_dragging = false;
            return was_dragging;
        }
        if !ok || !tas_hit_rect(tas_panel_rect(), mx, my) return false;
        if tas_hit_rect(tas_strip_rect(), mx, my) {
            tas_drag_begin(mx, event.shift_pressed, event.ctrl_pressed);
            return true;
        }
        for index: 0..TAS_BUTTON_COUNT-1
            if tas_hit_rect(tas_button_rect(index), mx, my) { tas_button_action(index); break; }
        return true;
    }
    if !event.key_pressed return false;
    if key == .ESCAPE { tas_close(); return true; }
    if key == .F8 { if !event.repeat tas_toggle_record(); return true; }
    if event.ctrl_pressed {
        if key == #char "S" { tas_request_save(); return true; }
        if key == #char "C" {
            first, last := tas_selection(*tas);
            if first == last { first = 0; last = tas.keys.count; }
            os_clipboard_set_text(string.{last - first, tas.keys.data + first});
            tas_set_status("WASD script copied.");
            return true;
        }
        if !tas.recording && !tas.playing {
            if key == #char "V" {
                text := os_clipboard_get_text();
                defer free(text);
                tas_insert_text(text);
                return true;
            }
            if key == #char "A" { tas.anchor = 0; tas.caret = tas.keys.count; return true; }
        }
        return true;
    }
    if tas.recording return false;
    if key == .ENTER { tas_request_seek(*tas, tas.caret); return true; }
    if key == #char "Z" { tas_seek(*tas, tas.playhead - 1); return true; }
    if key == .ARROW_LEFT { tas_move_caret(*tas, tas.caret - 1, event.shift_pressed); return true; }
    if key == .ARROW_RIGHT { tas_move_caret(*tas, tas.caret + 1, event.shift_pressed); return true; }
    if key == .HOME { tas_move_caret(*tas, 0, event.shift_pressed); return true; }
    if key == .END { tas_move_caret(*tas, tas.keys.count, event.shift_pressed); return true; }
    if key == .DELETE || key == .BACKSPACE { tas_delete_selection(key == .BACKSPACE); return true; }
    if cast(u32) key < 128 && tas_key_valid(cast(u8) key) {
        c := cast(u8) key;
        tas_insert_text(string.{1, *c});
        return true;
    }
    return false;
}

#scope_file
#import "Clipboard";
