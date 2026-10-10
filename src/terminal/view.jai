// Meslo Nerd Font and the floating Naysayer panels from ootss-cmd.
terminal_font, terminal_small_font: *Font;
TERMINAL_OPACITY :: 220.0 / 255.0;
TAS_PANEL_OPACITY :: 236.0 / 255.0;
TAS_BUTTON_COUNT :: 9;
TAS_CELL_PITCH :: 36;
tas_last_caret, tas_last_head: int = -1;

Tas_Icon :: struct {
    RECORD :: "󰑋"; STOP :: ""; BACK :: ""; STEP :: "";
    PLAY :: ""; PAUSE :: ""; START :: ""; END :: "";
    SAVE :: ""; COPY :: ""; CLOSE :: "⏻"; KEYBOARD :: "";
    UP :: ""; DOWN :: ""; LEFT :: ""; RIGHT :: ""; ACTION :: "";
}

terminal_color :: (rgb: int, alpha := 1.0) -> Color {
    return .{cast(float)((rgb >> 16) & 255) / 255, cast(float)((rgb >> 8) & 255) / 255,
             cast(float)(rgb & 255) / 255, alpha};
}

terminal_init_font :: () {
    terminal_font = load_font("fonts/Meslo-LG-Mono-Nerd-Regular.ttf", 20);
    terminal_small_font = load_font("fonts/Meslo-LG-Mono-Nerd-Regular.ttf", 13);
}

terminal_label :: (text: string, x: int, y: int, rgb: int = 0xd0b892, max_width: int = -1, small := false) {
    font := ifx small then terminal_small_font else terminal_font;
    if !font return;
    shown := text;
    if max_width >= 0 {
        while shown.count && text_width(font, shown) > max_width {
            // Keep the four-byte Nerd Font glyphs intact when clipping labels.
            end := shown.count - 1;
            while end > 0 && (shown[end] & 0xc0) == 0x80 end -= 1;
            shown.count = end;
        }
    }
    draw_text(font, shown, x, y, terminal_color(rgb));
}

// -----------------------------------------------------------------------------: shared drawing and hit geometry

tas_panel_rect :: () -> Rect {
    width := max(1, min(cast(int) window_width - 32, max(840, cast(int) window_width * 65 / 100)));
    return get_rect(xx ((window_width - width) / 2), 24, xx width, 252);
}

tas_strip_rect :: () -> Rect {
    p := tas_panel_rect();
    return get_rect(p.x + 16, p.y + 106, p.w - 32, 78);
}

tas_button_rect :: (index: int) -> Rect {
    p := tas_panel_rect();
    gap := 8.0;
    width := max(1.0, min(44.0, (p.w - 40 - gap * (TAS_BUTTON_COUNT - 1)) / TAS_BUTTON_COUNT));
    total := width * TAS_BUTTON_COUNT + gap * (TAS_BUTTON_COUNT - 1);
    return get_rect(p.x + (p.w - total) / 2 + cast(float) index * (width + gap), p.y + 50, width, 36);
}

tas_hit_rect :: (r: Rect, x: int, y: int) -> bool { return is_inside(xx x, xx y, r); }

tas_draw_rect :: (r: Rect, rgb: int, alpha := 1.0) {
    draw_screen_rect(r.x, r.y, r.x + r.w, r.y + r.h, terminal_color(rgb, alpha));
}

tas_visible_cells :: () -> int { return max(2, cast(int) tas_strip_rect().w / TAS_CELL_PITCH); }

tas_hit_index :: (x: int) -> int {
    strip := tas_strip_rect();
    center := strip.x + strip.w / 2;
    return clamp(tas_view_head + cast(int) floor((cast(float) x - center) / TAS_CELL_PITCH + 0.5), 0, tas.keys.count);
}

tas_button_action :: (index: int) {
    release_player_keys();
    if index == {
        case 0; tas_toggle_record();
        case 1; tas_seek(*tas, tas.playhead - 1);
        case 2; tas_seek(*tas, tas.playhead + 1);
        case 3; tas_toggle_play();
        case 4; tas_seek(*tas, 0);
        case 5; tas_request_seek(*tas, tas.keys.count);
        case 6; tas_request_save();
        case 7; terminal_execute("export");
        case 8; tas_close();
    }
}

tas_key_icon :: (key: u8) -> string {
    if key == {
        case #char "W"; return Tas_Icon.UP;
        case #char "A"; return Tas_Icon.LEFT;
        case #char "S"; return Tas_Icon.DOWN;
        case #char "D"; return Tas_Icon.RIGHT;
        case #char "X"; return Tas_Icon.ACTION;
        case #char "R"; return Tas_Icon.START;
    }
    return "";
}

// -----------------------------------------------------------------------------: recording editor

draw_tas_panel :: () {
    if !tas_active || !terminal_font || !terminal_small_font return;
    if tas.seek_target >= 0 tas_view_head = tas.seek_target;
    else if tas_dragging && !tas_drag_select {} // Keep the grabbed timeline under the pointer.
    else if tas_last_head != tas.playhead tas_view_head = tas.playhead;
    else if tas_last_caret != tas.caret {
        half := max(1, tas_visible_cells() / 2 - 1);
        if tas.caret < tas_view_head - half tas_view_head = tas.caret + half;
        if tas.caret > tas_view_head + half tas_view_head = tas.caret - half;
    }
    tas_last_caret = tas.caret;
    tas_last_head = tas.playhead;

    p := tas_panel_rect();
    strip := tas_strip_rect();
    center := strip.x + strip.w / 2;
    tas_draw_rect(p, 0x062626, TAS_PANEL_OPACITY);
    status := ifx tas.recording then "REC" else ifx tas.playing then "PLAY" else "EDIT";
    terminal_label(tprint("enigmash / % %", ifx tas_name then tas_name else "untitled", ifx tas.dirty then "*" else ""),
                   xx (p.x + 20), xx (p.y + 228), 0xd0b892, cast(int) p.w - 140, small = true);
    terminal_label(status, xx (p.x + p.w - 62), xx (p.y + 228),
                   ifx tas.recording then 0xf92672 else 0xa0b8c8, small = true);
    boundary := center + cast(float)(tas.playhead - tas_view_head) * TAS_CELL_PITCH;
    terminal_label("EXECUTED", xx strip.x, xx (p.y + 198), 0xa0b8c8, small = true);
    terminal_label("FUTURE", xx (center + 10), xx (p.y + 198), 0x8cde94, small = true);
    progress := tprint("% / %  % ms", tas.playhead, tas.keys.count, cast(int) tas.delay_ms);
    terminal_label(progress, xx (strip.x + strip.w - text_width(terminal_small_font, progress)),
                   xx (p.y + 198), small = true);

    tas_draw_rect(strip, 0x0b3335, 0.65);
    first, last := tas_selection(*tas);
    half := tas_visible_cells() / 2 + 1;
    for i: max(0, tas_view_head - half)..min(tas.keys.count, tas_view_head + half)-1 {
        x := center + cast(float)(i - tas_view_head) * TAS_CELL_PITCH;
        if x < strip.x || x + TAS_CELL_PITCH > strip.x + strip.w continue;
        color := ifx i < tas.playhead then 0x062626 else 0x23444b;
        if i >= first && i < last color = 0x126367;
        cell := get_rect(x + 3, strip.y + 10, TAS_CELL_PITCH - 6, 43);
        tas_draw_rect(cell, color, 0.86);
        icon := tas_key_icon(tas.keys[i]);
        terminal_label(icon, xx (cell.x + (cell.w - text_width(terminal_font, icon)) / 2),
                       xx (cell.y + 13), ifx i < tas.playhead then 0xa0b8c8 else 0xd0b892);
        number := tprint("%", i + 1);
        terminal_label(number, xx (x + (TAS_CELL_PITCH - text_width(terminal_small_font, number)) / 2),
                       xx (strip.y + 62), 0xa0b8c8, small = true);
    }
    if boundary >= strip.x && boundary <= strip.x + strip.w
        draw_screen_rect(boundary - 1, strip.y - 2, boundary + 1, strip.y + strip.h + 2, terminal_color(0x8cde94));
    caret_x := center + cast(float)(tas.caret - tas_view_head) * TAS_CELL_PITCH;
    if caret_x >= strip.x && caret_x <= strip.x + strip.w
        draw_screen_rect(caret_x, strip.y + 8, caret_x + 2, strip.y + 54, terminal_color(0xffffff));

    icons := string.[ifx tas.recording then Tas_Icon.STOP else Tas_Icon.RECORD, Tas_Icon.BACK, Tas_Icon.STEP,
                      ifx tas.playing then Tas_Icon.PAUSE else Tas_Icon.PLAY, Tas_Icon.START, Tas_Icon.END,
                      Tas_Icon.SAVE, Tas_Icon.COPY, Tas_Icon.CLOSE];
    labels := string.[ifx tas.recording then "Stop recording (F8)" else "Record (F8)", "Back one step (Z)", "Step forward",
                      ifx tas.playing then "Pause" else "Play", "Start: return to recording start", "End: seek to last step",
                      "Save (Ctrl+S)", "Copy WASD script (Ctrl+C)", "Close editor (Esc)"];
    mx, my, mouse_ok := get_mouse_pointer_position(the_window, true);
    hovered := -1;
    for icon: icons {
        r := tas_button_rect(it_index);
        hover := mouse_ok && !terminal.open && tas_hit_rect(r, mx, my);
        if hover hovered = it_index;
        active := (it_index == 0 && tas.recording) || (it_index == 3 && tas.playing);
        tas_draw_rect(r, ifx active || hover then 0x126367 else 0x23444b, 0.92);
        terminal_label(icon, xx (r.x + (r.w - text_width(terminal_font, icon)) / 2), xx (r.y + 10),
                       ifx active then 0x8cde94 else 0xd0b892);
    }
    terminal_label(ifx hovered >= 0 then labels[hovered] else tas_status, xx (p.x + 20), xx (p.y + 31),
                   0xa0b8c8, cast(int) p.w - 40, small = true);
    terminal_label(tprint("% F8  WASD %  % Z  % Ctrl+C  % Ctrl+S  % F1/:  Esc close",
                         Tas_Icon.RECORD, ifx tas.recording then "record" else "insert", Tas_Icon.BACK,
                         Tas_Icon.COPY, Tas_Icon.SAVE, Tas_Icon.KEYBOARD),
                   xx (p.x + 20), xx (p.y + 12), 0xa0b8c8, cast(int) p.w - 40, small = true);
}

// -----------------------------------------------------------------------------: terminal

draw_terminal :: () {
    if !terminal.open || !terminal_font || !terminal_small_font return;
    width := ifx terminal.mini then min(window_width, 760) else window_width;
    height := ifx terminal.mini then 56 else max(118, cast(int)(cast(float) window_height * terminal.height_ratio));
    bottom := ifx terminal.mini then 0 else window_height - height;
    footer_height := ifx terminal.mini then 0 else 28;
    input_bottom := bottom + footer_height;
    input_top := input_bottom + 56;
    // Disjoint backgrounds retain the original window's translucency.
    if !terminal.mini {
        draw_screen_rect(0, xx input_top, xx width, xx (bottom + height), terminal_color(0x062626, TERMINAL_OPACITY));
        draw_screen_rect(0, xx bottom, xx width, xx input_bottom, terminal_color(0xd3b58e, TERMINAL_OPACITY));
    }
    draw_screen_rect(0, xx input_bottom, xx width, xx input_top, terminal_color(0x0b3335, TERMINAL_OPACITY));
    cell_width := max(1, text_width(terminal_font, "M"));
    columns := max(1, (width - 84) / cell_width);
    input_y := input_bottom + 20;
    terminal_label("$", 28, input_y, 0x8cde94);
    offset := max(0, terminal.cursor - columns + 1);
    shown := slice(terminal_text(), offset, min(columns, terminal.input.count - offset));
    if shown terminal_label(shown, 56, input_y);
    else terminal_label("Type a command...", 56, input_y, 0xa0b8c8, width - 84);
    cursor_x := 56 + (terminal.cursor - offset) * cell_width;
    draw_screen_rect(xx cursor_x, xx (input_y - 3), xx (cursor_x + 2), xx (input_y + 19), terminal_color(0xffffff));
    if !terminal.mini {
        rows: [..] string;
        rows.allocator = temp;
        output_columns := max(1, (width - 56) / cell_width);
        for line: terminal.lines {
            if !line { array_add(*rows, ""); continue; }
            start := 0;
            while start < line.count {
                array_add(*rows, slice(line, start, min(output_columns, line.count - start)));
                start += output_columns;
            }
        }
        visible := max(0, (height - 126) / 30);
        terminal.scroll_max = max(0, rows.count - visible);
        terminal.scroll = clamp(terminal.scroll, 0, terminal.scroll_max);
        first := max(0, rows.count - visible - terminal.scroll);
        for i: first..min(rows.count, first + visible)-1 {
            terminal_label(rows[i], 28, bottom + height - 44 - (i - first) * 30,
                           ifx begins_with(rows[i], "$ ") then 0x40c040 else 0xd0b892);
        }
        hint := ifx terminal.scroll > 0 then tprint("Scrollback: % lines   PAGE DOWN to return", terminal.scroll)
                else "ENTER run   TAB complete   UP/DOWN history   ESC hide";
        terminal_label(hint, 28, bottom + 9, 0x12251b, width - 56, small = true);
    }
}
