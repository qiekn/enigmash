// 编辑器面板（GetRect）。布局：顶栏（文件）/ 左栏（工具）/ 右栏（检查器）/ 底栏（状态），中间是画布。
// 帧流程见 main.jai：事件先交给 getrect_handle_event，再 ui_per_frame_update → 画布 → 面板 → draw_popups。

#scope_file

theme          : Overall_Theme;
button_theme   : Button_Theme;
label_theme    : Label_Theme;
title_theme    : Label_Theme;
check_theme    : Checkbox_Theme;
radio_theme    : Checkbox_Theme;
input_theme    : Text_Input_Theme;
dropdown_theme : Dropdown_Theme;
scroll_theme   : Scrollable_Region_Theme;

top_rect, left_rect, right_rect, bottom_rect : Rect;

// 下拉框的选项数组和当前值必须活到 draw_popups()，所以放全局
message_ids   : [..] string;
style_choices :: string.["a", "b", "c", "d"];

problems_scroll : float;

setup_themes :: () {
    theme = default_theme_procs[Default_Themes.Default]();
    set_default_theme(theme);

    font := editor_font;
    button_theme = theme.button_theme;
    button_theme.font = font;

    label_theme = theme.label_theme;
    label_theme.font = font;
    label_theme.alignment = .Left;
    label_theme.alignment_pad_ems = 0.3;

    title_theme = label_theme;
    title_theme.text_color = .{1, 0.8, 0.4, 1};

    check_theme = theme.checkbox_theme;
    check_theme.font = font;

    radio_theme = theme.checkbox_theme;
    radio_theme.font = font;
    radio_theme.is_radio_button = true;

    input_theme = theme.text_input_theme;
    input_theme.font = font;

    dropdown_theme = theme.dropdown_theme;
    dropdown_theme.theme_for_current_value.font  = font;
    dropdown_theme.theme_for_each_choice.font    = font;
    dropdown_theme.theme_for_current_choice.font = font;

    scroll_theme = theme.scrollable_region_theme;
}

row_height :: () -> float { return editor_font.character_height * 1.7; }

panel_bg :: (r: Rect) {
    draw_screen_rect(r.x, r.y, r.x + r.w, r.y + r.h, .{0.09, 0.09, 0.11, 0.94});
}

// 从上往下排版的小工具
Column :: struct {
    x, w : float;
    y    : float;    // 下一行的顶边
}

next_row :: (c: *Column, height_scale := 1.0) -> Rect {
    h := row_height() * height_scale;
    c.y -= h;
    return get_rect(c.x, c.y + h * 0.08, c.w, h * 0.84);
}

gap :: (c: *Column, amount := 0.4) { c.y -= row_height() * amount; }

section :: (c: *Column, title: string) {
    gap(c, 0.3);
    label(next_row(c), title, *title_theme);
}

text_label :: (c: *Column, text: string) {
    label(next_row(c), text, *label_theme);
}

modify_string :: (s: *string, v: string) {
    free(s.*);
    s.* = copy_string(v);
}

#scope_export

mouse_over_panels :: () -> bool {
    mx, my, ok := get_mouse_pointer_position(the_window, true);
    if !ok  return false;
    x := cast(float) mx;
    y := cast(float) my;
    return is_inside(x, y, top_rect) || is_inside(x, y, left_rect) || is_inside(x, y, right_rect) || is_inside(x, y, bottom_rect);
}

// 在 ui_per_frame_update 之后调用
editor_draw_panels :: () {
    setup_themes();

    W := cast(float) window_width;
    H := cast(float) window_height;
    rh := row_height();

    top_h    := rh * 1.3;
    bottom_h := rh;
    left_w   := max(240.0, W * 0.17);
    right_w  := max(280.0, W * 0.21);

    top_rect    = get_rect(0, H - top_h, W, top_h);
    bottom_rect = get_rect(0, 0, W, bottom_h);
    left_rect   = get_rect(0, bottom_h, left_w, H - top_h - bottom_h);
    right_rect  = get_rect(W - right_w, bottom_h, right_w, H - top_h - bottom_h);

    panel_bg(top_rect);  panel_bg(bottom_rect);  panel_bg(left_rect);  panel_bg(right_rect);
    Simp.immediate_flush();

    focused := false;
    draw_top_bar(*focused);
    draw_left_panel(*focused);
    draw_right_panel(*focused);
    draw_status_bar();
    editor_text_focused = focused;
}

#scope_file

draw_top_bar :: (focused: *bool) {
    r := shrink(top_rect, 4);
    bw := editor_font.character_height * 4.2;

    b, rest := cut_left(r, bw, 4);
    if button(b, "New", *button_theme)   editor_new_level(MAP_WIDTH, MAP_HEIGHT);
    b, rest = cut_left(rest, bw, 4);
    if button(b, "Open", *button_theme)  if ed.path  editor_load(ed.path);
    b, rest = cut_left(rest, bw, 4);
    if button(b, "Save", *button_theme)  editor_save();
    b, rest = cut_left(rest, bw * 1.4, 4);
    if button(b, "Play (F5)", *button_theme)  editor_playtest(false);
    b, rest = cut_left(rest, bw * 1.2, 4);
    if button(b, "Check", *button_theme) {
        editor_validate();
        editor_set_status("% problems", ed.problems.count);
    }

    l, rest2 := cut_left(rest, editor_font.character_height * 2.5, 4);
    label(l, "path", *label_theme);
    field, star := cut_left(rest2, rest2.w - editor_font.character_height * 1.5, 4);
    action, text, state := text_input(field, ed.path, *input_theme);
    if action & .ENTERED  modify_string(*ed.path, text);
    if state && state.active  focused.* = true;
    if ed.dirty  label(star, "*", *title_theme);
}

draw_left_panel :: (focused: *bool) {
    c := Column.{left_rect.x + 6, left_rect.w - 12, left_rect.y + left_rect.h - 4};

    section(*c, "Tools");
    for TOOL_NAMES  radio_button(next_row(*c), it, *ed.tool, cast(Editor_Tool) it_index, *radio_theme, it_index);

    gap(*c);
    if ed.tool == {
        case .BRUSH;
            section(*c, "Brush (LMB paint, RMB erase)");
            for BRUSH_NAMES  radio_button(next_row(*c), it, *ed.brush, cast(Brush) it_index, *radio_theme, it_index);

        case .WORLD;
            section(*c, "World (click a region)");
            for WORLD_NAMES  radio_button(next_row(*c), it, *ed.world_value, cast(s32) it_index, *radio_theme, it_index);
            gap(*c, 0.2);
            if base_checkbox(next_row(*c), "Set hidden world", ed.world_hidden, *check_theme)  ed.world_hidden = !ed.world_hidden;

        case .ENTITY;
            section(*c, "Entity (LMB place, RMB clear)");
            for ENTITY_KINDS  radio_button(next_row(*c), it.name, *ed.entity_index, cast(s32) it_index, *radio_theme, it_index);
            radio_button(next_row(*c), "letter", *ed.entity_index, cast(s32) ENTITY_KINDS.count, *radio_theme, ENTITY_KINDS.count);
            row := next_row(*c);
            l, field := cut_left(row, editor_font.character_height * 3.0, 4);
            label(l, "char", *label_theme);
            action, text, state := text_input(field, ed.letter_text, *input_theme);
            if action & .ENTERED  modify_string(*ed.letter_text, text);
            if state && state.active  focused.* = true;

        case .EDGE;
            section(*c, "Region edges");
            text_label(*c, "Click near a cell edge");
            text_label(*c, "to toggle it; drag to paint.");

        case .TUNNEL;
            section(*c, "Tunnel click mode");
            radio_button(next_row(*c), "Set end 0",            *ed.tunnel_stage, .END0, *radio_theme, 0);
            radio_button(next_row(*c), "Add path point (RMB undo)", *ed.tunnel_stage, .PATH, *radio_theme, 1);
            radio_button(next_row(*c), "Set end 1",            *ed.tunnel_stage, .END1, *radio_theme, 2);

        case .PICK;
            section(*c, "Pick");
            text_label(*c, "Click a cell to copy it");
            text_label(*c, "into the brush.");
    }

    gap(*c);
    section(*c, "View");
    if base_checkbox(next_row(*c), "Schematic (Tab)", ed.schematic, *check_theme, 0)        ed.schematic     = !ed.schematic;
    if base_checkbox(next_row(*c), "Hidden worlds (H)", ed.show_hidden, *check_theme, 1)    ed.show_hidden   = !ed.show_hidden;
    if base_checkbox(next_row(*c), "Regions (G)", ed.show_regions, *check_theme, 2)         ed.show_regions  = !ed.show_regions;
    if base_checkbox(next_row(*c), "Edges", ed.show_edges, *check_theme, 3)                 ed.show_edges    = !ed.show_edges;
    if base_checkbox(next_row(*c), "Entity labels", ed.show_entities, *check_theme, 4)      ed.show_entities = !ed.show_entities;
}

draw_right_panel :: (focused: *bool) {
    c := Column.{right_rect.x + 6, right_rect.w - 12, right_rect.y + right_rect.h - 4};
    l := *ed.level;

    // ---- 悬停格
    section(*c, "Cell");
    if ed.hover_valid {
        editor_update_regions();
        i := ed_index(ed.hover);
        cell := l.initial.cells[i];
        text_label(*c, tprint("%, %   region %", ed.hover.x, ed.hover.y, ed.region_of[i]));
        text_label(*c, tprint("world %   hidden %", cast(int) cell.num, cast(int) cell.hide));
        text_label(*c, tprint("%", cell_summary(cell, l.letters[i])));
    } else {
        text_label(*c, "-");
    }

    // ---- 隧道
    section(*c, tprint("Tunnels (%)", l.tunnels.count));
    row := next_row(*c);
    bw := row.w / 4;
    b, rest := cut_left(row, bw - 2, 2);
    if button(b, "New", *button_theme, 0) {
        begin_stroke(); stroke_touch_tunnels();
        t := array_add(*l.tunnels);
        t.ends[0] = .{ed.hover, true, "", #char "a"};
        t.ends[1] = .{ed.hover, false, "", #char "b"};
        end_stroke();
        ed.tunnel_index = cast(s32) l.tunnels.count - 1;
        ed.tool = .TUNNEL;
    }
    b, rest = cut_left(rest, bw - 2, 2);
    if button(b, "Del", *button_theme, 1) && ed.tunnel_index >= 0 {
        begin_stroke(); stroke_touch_tunnels();
        array_free(l.tunnels[ed.tunnel_index].path);
        array_ordered_remove_by_index(*l.tunnels, ed.tunnel_index);
        end_stroke();
        clamp_tunnel_index();
    }
    b, rest = cut_left(rest, bw - 2, 2);
    if button(b, "<", *button_theme, 2) && ed.tunnel_index > 0  ed.tunnel_index -= 1;
    if button(rest, ">", *button_theme, 3) && ed.tunnel_index + 1 < l.tunnels.count  ed.tunnel_index += 1;

    if ed.tunnel_index >= 0 && ed.tunnel_index < l.tunnels.count {
        t := *l.tunnels[ed.tunnel_index];
        text_label(*c, tprint("tunnel %: % path points", ed.tunnel_index, t.path.count));
        for * e, ei: t.ends {
            text_label(*c, tprint("end%  at %, %", ei, e.pos.x, e.pos.y));
            if base_checkbox(next_row(*c), "open at start", e.start_open, *check_theme, 10 + ei) {
                begin_stroke(); stroke_touch_tunnels();
                e.start_open = !e.start_open;
                end_stroke();
                l.initial.open = initial_open_bits(l);
            }
            row = next_row(*c);
            sw := row.w / 5;
            lab, styles := cut_left(row, sw, 2);
            label(lab, "style", *label_theme);
            for s, si: style_choices {
                sr: Rect;
                sr, styles = cut_left(styles, sw - 2, 2);
                if button(sr, s, *button_theme, 100 + ei * 10 + si) {
                    begin_stroke(); stroke_touch_tunnels();
                    e.style = s[0];
                    end_stroke();
                }
            }
            row = next_row(*c);
            lab2, field := cut_left(row, editor_font.character_height * 3.2, 2);
            label(lab2, "msg", *label_theme);
            action, text, state := text_input(field, e.message, *input_theme, 20 + ei);
            if action & .ENTERED {
                begin_stroke(); stroke_touch_tunnels();
                e.message = copy_string(text);
                end_stroke();
            }
            if state && state.active  focused.* = true;
        }
    }

    // ---- 消息文本
    section(*c, "Messages");
    array_reset_keeping_memory(*message_ids);
    for l.messages  array_add(*message_ids, it.id);
    if l.messages.count {
        if ed.message_index >= l.messages.count  ed.message_index = 0;
        dropdown(next_row(*c), message_ids, *ed.message_index, *dropdown_theme);
        m := *l.messages[ed.message_index];
        action, text, state := text_input(next_row(*c, 1.2), escape_newlines(m.text), *input_theme, 30);
        if action & .ENTERED {
            m.text = unescape_newlines(text);
            ed.dirty = true;
        }
        if state && state.active  focused.* = true;
        text_label(*c, "(\\n = line break, Enter to apply)");
    }

    // ---- 问题列表
    section(*c, tprint("Problems (%)", ed.problems.count));
    list_rect := get_rect(c.x, right_rect.y + 4, c.w, max(c.y - right_rect.y - 8, row_height()));
    region, inside := begin_scrollable_region(list_rect, *scroll_theme);
    s := inside;
    s.h = row_height() * 0.9;
    s.y = inside.y + inside.h - s.h + problems_scroll;
    for ed.problems {
        label(s, it, *label_theme);
        s.y -= s.h;
    }
    end_scrollable_region(region, s.x + s.w, s.y, *problems_scroll);
}

draw_status_bar :: () {
    r := shrink(bottom_rect, 2);
    text := tprint("%   |   zoom %   |   %   |   LMB apply  RMB erase  MMB/Space drag pan  wheel zoom  Ctrl+Z/Y undo/redo  Ctrl+S save  F5 play  Shift+F5 play from cursor",
                   ed.status, formatFloat(active_camera.zoom, trailing_width = 2), TOOL_NAMES[ed.tool]);
    label(r, text, *label_theme);
}

cell_summary :: (c: Cell, letter: u8) -> string {
    b: String_Builder;
    b.allocator = temp;
    part :: (flag: bool, s: string) #expand { if flag  print_to_builder(*b, "% ", s); }
    part((c.obj & .WALL)   != 0, "wall");
    part((c.obj & .SUNK)   != 0, "sunk");
    part((c.obj & .THING)  != 0, "thing");
    part((c.obj & .PLAYER) != 0, "player");
    part((c.obj & .TOGGLE) != 0, ifx c.obj & .JUST_O then "toggle(pressed)" else "toggle");
    for ENTITY_KINDS  part((it.obj && (c.obj & it.obj)) || (it.mark && (c.mark & it.mark)), it.name);
    if letter  print_to_builder(*b, "letter:% ", string.{1, *letter});
    s := builder_to_string(*b,, temp);
    return ifx s then s else "empty";
}
