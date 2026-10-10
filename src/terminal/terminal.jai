// In-game version of ootss-cmd's minimal $ console, history and text editing.
Terminal :: struct {
    open, mini: bool;
    height_ratio := 0.7;
    input: [..] u8;
    cursor, history_cursor, scroll, scroll_max: int;
    history, lines: [..] string;
    draft: string;
    skip_text: int;
    ignore_open_punctuation: bool;
}

terminal: Terminal;
TERMINAL_INPUT_LIMIT :: 4096;
TERMINAL_COMMANDS :: string.["help", "editor", "record", "play", "do", "pause", "stop", "step", "back", "rewind",
    "seek", "insert", "save", "load", "list", "export", "speed", "clear", "toggle", "quit"];

terminal_text :: () -> string { return .{terminal.input.count, terminal.input.data}; }

terminal_write :: (message: string) {
    for split(message, "\n",, temp) {
        if terminal.lines.count >= 256 {
            free(terminal.lines[0]);
            array_ordered_remove_by_index(*terminal.lines, 0);
        }
        array_add(*terminal.lines, copy_string(it));
    }
    terminal.scroll = 0;
}

terminal_show :: (mini := false) {
    if do_active do_stop();
    terminal.open = true;
    terminal.mini = mini;
    release_player_keys();
    tas_dragging = false;
    if tas_active tas_pause(*tas);
    active_widget_deactivate_all();
    if !terminal.lines.count terminal_write("Enigmash / TAS\nType help.  editor opens the recording timeline.");
}

terminal_hide :: () {
    terminal.open = false;
    release_player_keys();
}

terminal_set_input :: (text: string) {
    array_reset(*terminal.input);
    for text {
        if terminal.input.count >= TERMINAL_INPUT_LIMIT break;
        array_add(*terminal.input, it);
    }
    terminal.cursor = terminal.input.count;
}

terminal_insert :: (text: string) {
    if text.count + terminal.input.count > TERMINAL_INPUT_LIMIT { terminal_write("Input too long (4096 bytes)."); return; }
    for c: text {
        if c < 32 || c >= 127 continue;
        array_insert_at(*terminal.input, c, terminal.cursor);
        terminal.cursor += 1;
    }
    terminal.history_cursor = terminal.history.count;
}

terminal_erase :: (first: int, last: int) {
    if first < 0 || last > terminal.input.count || first >= last return;
    for i: last..terminal.input.count-1 terminal.input[i - (last - first)] = terminal.input[i];
    terminal.input.count -= last - first;
    terminal.cursor = first;
}

terminal_history :: (direction: int) {
    if !terminal.history.count return;
    if terminal.history_cursor == terminal.history.count {
        free(terminal.draft);
        terminal.draft = copy_string(terminal_text());
    }
    terminal.history_cursor = clamp(terminal.history_cursor + direction, 0, terminal.history.count);
    if terminal.history_cursor == terminal.history.count terminal_set_input(terminal.draft);
    else terminal_set_input(terminal.history[terminal.history_cursor]);
}

terminal_complete :: () {
    prefix := terminal_text();
    matches: [..] string;
    matches.allocator = temp;
    for TERMINAL_COMMANDS {
        if prefix.count <= it.count && equal_nocase(prefix, slice(it, 0, prefix.count)) array_add(*matches, it);
    }
    if matches.count == 1 terminal_set_input(tprint("% ", matches[0]));
    else for matches terminal_write(it);
}

terminal_submit :: () {
    line := copy_string(trim(terminal_text()));
    defer free(line);
    terminal_set_input("");
    if line {
        if terminal.history.count == 64 {
            free(terminal.history[0]);
            array_ordered_remove_by_index(*terminal.history, 0);
        }
        array_add(*terminal.history, copy_string(line));
        terminal_write(tprint("$ %", line));
        terminal_execute(line);
    }
    terminal.history_cursor = terminal.history.count;
    if terminal.mini terminal_hide();
}

// -----------------------------------------------------------------------------: commands

terminal_execute :: (line: string) {
    split_at := 0;
    while split_at < line.count && line[split_at] != #char " " split_at += 1;
    command := slice(line, 0, split_at);
    args := trim(slice(line, split_at, line.count - split_at));
    is :: (name: string) -> bool #expand { return equal_nocase(command, name); }
    if is("do") {
        error := do_command(args);
        if error terminal_write(error);
        return;
    }
    if is("help") {
        terminal_write("editor [name]       Open TAS / load a saved take\neditor new[!]       Start a fresh take at the beginning of the game\neditor close        Return to game; retain take in memory\nrecord              Record accepted WASD turns (F8 toggles)\nplay [name]         Play from playhead / load then play\ndo [name|W3ASD]     Hidden playback; bare do plays the current take\n  [-delay MS]       1..10000 ms; Esc stops playback\n  Scripts start here; saved/current takes start at their snapshot.\npause / stop        Stop playback and recording\nstep / back         Advance / rewind one input\nrewind / seek N     Restore start / seek to turn N\ninsert W3ASD        Insert at selection; digits repeat the preceding key\nsave [name]         Save snapshot + script in save/tas/<name>.tas\nload[!] name        Load; ! explicitly replaces an unsaved take\nlist / export      List recordings / copy script to clipboard\nspeed MS           Set playback delay (1..10000 ms)\nclear / cl          Clear terminal output\ntoggle MODE         full / normal / small / mini\nq / quit            Hide terminal\n\n: or F1 opens console; ; opens quick input. Esc hides it.\nTimeline: click/drag/wheel seeks; Shift+drag/arrows selects.\nWASD inserts; Delete removes; Enter seeks; Z goes back.\nClick Play to replay; Ctrl+S saves. Space does not toggle playback.\nX records action/message dismissal; R records checkpoint restart.");
        terminal.scroll = 1000000;
        return;
    }
    if is("clear") || is("cl") {
        for terminal.lines free(it);
        array_reset(*terminal.lines);
        return;
    }
    if is("q") || is("quit") { terminal_hide(); return; }
    if is("toggle") {
        if equal_nocase(args, "mini") terminal.mini = true;
        else {
            terminal.mini = false;
            if equal_nocase(args, "full") terminal.height_ratio = 1;
            else if equal_nocase(args, "normal") terminal.height_ratio = 0.7;
            else if equal_nocase(args, "small") terminal.height_ratio = 0.3;
            else terminal_write("Usage: toggle full|normal|small|mini");
        }
        return;
    }
    if is("list") {
        found := false;
        for file_list(tprint("%/tas", SAVE_DIR),, temp) {
            if ends_with(it, ".tas") { terminal_write(path_strip_extension(path_filename(it))); found = true; }
        }
        if !found terminal_write("No recordings in save/tas yet.");
        return;
    }
    if is("editor") {
        if equal_nocase(args, "close") { tas_close(); terminal_hide(); return; }
        if !tas_open() { terminal_write(tas_status); return; }
        if equal_nocase(args, "new") || equal_nocase(args, "new!") {
            if tas.dirty && !equal_nocase(args, "new!") { terminal_write("Unsaved take. Save first, or use editor new!."); return; }
            tas_new_take();
        } else if args {
            result, ok := tas_load_take(args);
            terminal_write(result);
            tas_set_status(result);
            if !ok return;
        }
        terminal_hide();
        return;
    }
    known := is("record") || is("play") || is("pause") || is("stop") || is("step") || is("back") || is("undo") ||
             is("rewind") || is("seek") || is("insert") || is("save") || is("load") || is("load!") || is("export") || is("speed");
    if !known { terminal_write(tprint("Unknown command: %. Type help.", command)); return; }
    if !tas_active { terminal_write("Open a TAS workspace with editor first."); return; }
    result := "";
    if is("record") {
        if !tas.recording tas_toggle_record();
        terminal_hide();
    } else if is("pause") || is("stop") {
        tas_pause(*tas); tas.recording = false;
        result = "Stopped.";
    } else if is("play") {
        if args {
            ok: bool;
            result, ok = tas_load_take(args);
            if !ok { terminal_write(result); return; }
        }
        tas_pause(*tas);
        tas_toggle_play();
        terminal_hide();
    } else if is("step") || is("back") || is("undo") || is("rewind") {
        tas.recording = false;
        target := ifx is("rewind") then 0 else tas.playhead + (ifx is("step") then 1 else -1);
        tas_seek(*tas, target);
    } else if is("seek") || is("speed") {
        value, ok, rest := string_to_int(args);
        if !ok || rest || value < 0 || (is("speed") && (value < 1 || value > 10000)) ||
           (is("seek") && value > tas.keys.count) result = "Invalid position/delay. See help.";
        else if is("speed") { tas.delay_ms = cast(float) value; tas.dirty = true; }
        else { tas.recording = false; tas_seek(*tas, value); }
    } else if is("insert") { tas_insert_text(args); result = tas_status; }
    else if is("save") result = tas_save_take(args);
    else if is("load") || is("load!") result = tas_load_take(args, is("load!"));
    else if is("export") { os_clipboard_set_text(string.{tas.keys.count, tas.keys.data}); result = "WASD script copied."; }
    if result { terminal_write(result); tas_set_status(result); }
    release_player_keys();
}

// -----------------------------------------------------------------------------: event routing

terminal_handle_event :: (event: Event) -> bool {
    if event.type == .TEXT_INPUT && terminal.ignore_open_punctuation {
        terminal.ignore_open_punctuation = false;
        if event.utf32 == #char ";" || event.utf32 == #char ":" {
            terminal.skip_text = 0;
            return true;
        }
    }
    if event.type == .TEXT_INPUT && terminal.skip_text > 0 {
        terminal.skip_text -= 1;
        return true;
    }
    if !terminal.open {
        if event.type == .KEYBOARD && event.key_pressed && !event.repeat && !event.ctrl_pressed && !event.alt_pressed &&
           (event.key_code == .F1 || event.key_code == #char ";" || event.key_code == #char ":") {
            terminal_show(event.key_code == #char ";" && !event.shift_pressed);
            terminal.skip_text = event.text_input_count;
            terminal.ignore_open_punctuation = event.key_code != .F1;
            return true;
        }
        // Some keyboard layouts report punctuation only as a text event.
        if event.type == .TEXT_INPUT && (event.utf32 == #char ":" || event.utf32 == #char ";") {
            terminal_show(event.utf32 == #char ";");
            return true;
        }
        return false;
    }
    if event.type == .TEXT_INPUT {
        if event.utf32 >= 32 && event.utf32 < 127 {
            c := cast(u8) event.utf32;
            terminal_insert(string.{1, *c});
        }
    } else if event.type == .MOUSE_WHEEL {
        terminal.scroll = clamp(terminal.scroll + (ifx event.wheel_delta > 0 then 3 else -3), 0, terminal.scroll_max);
    } else if event.type == .KEYBOARD && event.key_pressed {
        key := event.key_code;
        if key == .ESCAPE || key == .F1 || (event.ctrl_pressed && (key == #char "C" || key == #char "D")) terminal_hide();
        else if key == .ENTER { terminal.skip_text = event.text_input_count; terminal_submit(); }
        else if key == .ARROW_UP terminal_history(-1);
        else if key == .ARROW_DOWN terminal_history(1);
        else if key == .HOME terminal.cursor = 0;
        else if key == .END terminal.cursor = terminal.input.count;
        else if key == .ARROW_LEFT terminal.cursor = max(0, terminal.cursor - 1);
        else if key == .ARROW_RIGHT terminal.cursor = min(terminal.input.count, terminal.cursor + 1);
        else if key == .PAGE_UP terminal.scroll = min(terminal.scroll_max, terminal.scroll + 10);
        else if key == .PAGE_DOWN terminal.scroll = max(0, terminal.scroll - 10);
        else if key == .TAB terminal_complete();
        else if (event.ctrl_pressed && key == #char "V") || (event.shift_pressed && key == .INSERT) {
            pasted := os_clipboard_get_text();
            defer free(pasted);
            terminal_insert(pasted);
        } else if event.ctrl_pressed && key == #char "U" terminal_erase(0, terminal.cursor);
        else if event.ctrl_pressed && key == #char "W" {
            first := terminal.cursor;
            while first > 0 && terminal.input[first - 1] == #char " " first -= 1;
            while first > 0 && terminal.input[first - 1] != #char " " first -= 1;
            terminal_erase(first, terminal.cursor);
        } else if key == .DELETE && event.ctrl_pressed {
            last := terminal.cursor;
            while last < terminal.input.count && terminal.input[last] == #char " " last += 1;
            while last < terminal.input.count && terminal.input[last] != #char " " last += 1;
            terminal_erase(terminal.cursor, last);
        } else if key == .BACKSPACE terminal_erase(terminal.cursor - 1, terminal.cursor);
        else if key == .DELETE terminal_erase(terminal.cursor, terminal.cursor + 1);
    }
    return true;
}

#scope_file
#import "Clipboard";
