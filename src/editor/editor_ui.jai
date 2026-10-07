// 编辑器面板（GetRect）。布局：顶栏（文件）/ 左栏（工具）/ 右栏（检查器，可滚动）/ 底栏（状态），中间是画布。
// 文本弹窗盖在最上面。
// 帧流程见 main.jai：事件先交给 getrect_handle_event，再 ui_per_frame_update → 画布 → 面板 → draw_popups。

#scope_file

theme             : Overall_Theme;
button_theme      : Button_Theme;
left_button_theme : Button_Theme;   // 文字靠左的按钮（列表行）
label_theme       : Label_Theme;
title_theme       : Label_Theme;
dim_theme         : Label_Theme;
check_theme       : Checkbox_Theme;
radio_theme       : Checkbox_Theme;
input_theme       : Text_Input_Theme;
scroll_theme      : Scrollable_Region_Theme;

top_rect, left_rect, right_rect, bottom_rect, modal_rect : Rect;

style_choices :: string.["a", "b", "c", "d"];

right_scroll : float;

// 实体在面板里的名字（和 ENTITY_KINDS 一一对应）
ENTITY_LABELS :: string.[
    "Checkpoint",
    "Camera stick",
    "Camera shift left",
    "Hint text",
    "Branch left",
    "Branch right",
    "Branch once",
    "Uhh text",
    "Bad idea text",
    "Oops text",
    "Candy bowl",
    "Secret text",
    "Win spawn",
    "No link up",
    "No link",
];

#run assert(ENTITY_LABELS.count == ENTITY_KINDS.count);

setup_themes :: () {
    theme = default_theme_procs[Default_Themes.Default]();
    set_default_theme(theme);

    font := editor_font;
    button_theme = theme.button_theme;
    button_theme.font = font;

    left_button_theme = button_theme;
    left_button_theme.label_theme.alignment = .Left;
    left_button_theme.label_theme.alignment_pad_ems = 0.5;

    label_theme = theme.label_theme;
    label_theme.font = font;
    label_theme.alignment = .Left;
    label_theme.alignment_pad_ems = 0.3;

    title_theme = label_theme;
    title_theme.text_color = .{1, 0.8, 0.4, 1};

    dim_theme = label_theme;
    dim_theme.text_color = .{0.6, 0.6, 0.65, 1};

    check_theme = theme.checkbox_theme;
    check_theme.font = font;

    radio_theme = theme.checkbox_theme;
    radio_theme.font = font;
    radio_theme.is_radio_button = true;

    input_theme = theme.text_input_theme;
    input_theme.font = font;

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

text_label :: (c: *Column, text: string, theme := *label_theme) {
    label(next_row(c), text, theme);
}

// 把一行按比例切成几块；weights 之和随意
split_row :: (r: Rect, weights: ..float) -> [] Rect {
    MARGIN :: 4.0;
    total: float;
    for weights  total += it;
    rects := NewArray(weights.count, Rect,, temp);
    x := r.x;
    usable := r.w - MARGIN * (weights.count - 1);
    for weights {
        rects[it_index] = get_rect(x, r.y, usable * it / total, r.h);
        x += rects[it_index].w + MARGIN;
    }
    return rects;
}

// 一行预览文字：换行显示成 " / "，太长截断
preview_text :: (s: string, max_chars := 28) -> string {
    if !s  return "(empty)";
    t := replace(s, "\n", " / ",, temp);
    if t.count > max_chars  t = tprint("%...", slice(t, 0, max_chars));
    return t;
}

#scope_export

mouse_over_panels :: () -> bool {
    if ed.modal_open  return true;
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
    right_w  := max(300.0, W * 0.22);

    top_rect    = get_rect(0, H - top_h, W, top_h);
    bottom_rect = get_rect(0, 0, W, bottom_h);
    left_rect   = get_rect(0, bottom_h, left_w, H - top_h - bottom_h);
    right_rect  = get_rect(W - right_w, bottom_h, right_w, H - top_h - bottom_h);

    panel_bg(top_rect);  panel_bg(bottom_rect);  panel_bg(left_rect);  panel_bg(right_rect);
    flush_graphics();

    focused := false;
    draw_top_bar(*focused);
    draw_left_panel(*focused);
    draw_right_panel(*focused);
    draw_status_bar();
    if ed.modal_open {
        draw_message_modal();
        focused = true;
    }
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
            section(*c, "World");
            for WORLD_NAMES  radio_button(next_row(*c), it, *ed.world_value, cast(s32) it_index, *radio_theme, it_index);
            gap(*c, 0.2);
            if base_checkbox(next_row(*c), "Hidden side (toggle)", ed.world_hidden, *check_theme, 0)  ed.world_hidden = !ed.world_hidden;
            gap(*c, 0.2);
            radio_button(next_row(*c), "Paint cells (drag)", *ed.world_fill, false, *radio_theme, 10);
            radio_button(next_row(*c), "Fill region (Shift)", *ed.world_fill, true, *radio_theme, 11);
            if !ed.world_fill {
                if base_checkbox(next_row(*c), "Auto edges", ed.world_auto_edges, *check_theme, 1)  ed.world_auto_edges = !ed.world_auto_edges;
                text_label(*c, "Borders follow world changes", *dim_theme);
            }

        case .ENTITY;
            section(*c, "Entity (LMB place, RMB clear)");
            for COMMON_ENTITIES  radio_button(next_row(*c), ENTITY_LABELS[it], *ed.entity_index, it, *radio_theme, it);
            radio_button(next_row(*c), "Letter", *ed.entity_index, cast(s32) ENTITY_KINDS.count, *radio_theme, ENTITY_KINDS.count);
            if ed.entity_index == ENTITY_KINDS.count {
                row := next_row(*c);
                l, field := cut_left(row, editor_font.character_height * 3.0, 4);
                label(l, "char", *label_theme);
                action, text, state := text_input(field, ed.letter_text, *input_theme);
                if action & .ENTERED  modify_string(*ed.letter_text, text);
                if state && state.active  focused.* = true;
            }

            gap(*c, 0.2);
            if base_checkbox(next_row(*c), "All entities", ed.entity_show_all, *check_theme, 0)  ed.entity_show_all = !ed.entity_show_all;
            if ed.entity_show_all {
                for ENTITY_KINDS {
                    if array_find(COMMON_ENTITIES, cast(s32) it_index)  continue;
                    radio_button(next_row(*c), ENTITY_LABELS[it_index], *ed.entity_index, cast(s32) it_index, *radio_theme, 100 + it_index);
                }
            }

            if ed.entity_index < ENTITY_KINDS.count && ENTITY_MESSAGE[ed.entity_index] {
                gap(*c, 0.3);
                id := ENTITY_MESSAGE[ed.entity_index];
                m := editor_find_message(id);
                text_label(*c, tprint("\"%\"", preview_text(ifx m then m.text else "", 24)), *dim_theme);
                if button(next_row(*c), "Edit text...", *button_theme, 1)  editor_open_message(id);
            }

        case .EDGE;
            section(*c, "Region edges");
            text_label(*c, "Drag from corner to corner");
            text_label(*c, "LMB add, RMB remove");
            text_label(*c, "Click near an edge to toggle", *dim_theme);

        case .TUNNEL;
            section(*c, "Tunnel click mode");
            radio_button(next_row(*c), "Set end A",                 *ed.tunnel_stage, .END0, *radio_theme, 0);
            radio_button(next_row(*c), "Add path point (RMB undo)", *ed.tunnel_stage, .PATH, *radio_theme, 1);
            radio_button(next_row(*c), "Set end B",                 *ed.tunnel_stage, .END1, *radio_theme, 2);
            text_label(*c, "Tunnel list: right panel", *dim_theme);

        case .PICK;
            section(*c, "Pick");
            text_label(*c, "Click a cell to copy it");
            text_label(*c, "into the brush.");
    }

    gap(*c);
    section(*c, "View");
    if base_checkbox(next_row(*c), "Schematic (Tab)", ed.schematic, *check_theme, 10)       ed.schematic     = !ed.schematic;
    if base_checkbox(next_row(*c), "Hidden worlds (H)", ed.show_hidden, *check_theme, 11)   ed.show_hidden   = !ed.show_hidden;
    if base_checkbox(next_row(*c), "Regions (G)", ed.show_regions, *check_theme, 12)        ed.show_regions  = !ed.show_regions;
    if base_checkbox(next_row(*c), "Edges", ed.show_edges, *check_theme, 13)                ed.show_edges    = !ed.show_edges;
    if base_checkbox(next_row(*c), "Entity labels", ed.show_entities, *check_theme, 14)     ed.show_entities = !ed.show_entities;
}

draw_right_panel :: (focused: *bool) {
    l := *ed.level;

    region, inside := begin_scrollable_region(right_rect, *scroll_theme);
    c := Column.{inside.x + 6, inside.w - 12, inside.y + inside.h - 4 + right_scroll};

    // ---- 悬停格
    section(*c, "Cell");
    if ed.hover_valid {
        editor_update_regions();
        i := ed_index(ed.hover);
        cell := l.initial.cells[i];
        text_label(*c, tprint("(%, %)  region %  world %/%", ed.hover.x, ed.hover.y, ed.region_of[i], cast(int) cell.num, cast(int) cell.hide));
        text_label(*c, cell_summary(cell, l.letters[i]), *dim_theme);
    } else {
        text_label(*c, "-", *dim_theme);
        text_label(*c, "");
    }

    draw_tunnels(*c);

    // ---- 文本（实体 / 隧道触发的消息）
    section(*c, "Texts");
    for * m, mi: l.messages {
        if button(next_row(*c), tprint("%: %", m.id, preview_text(m.text, 22)), *left_button_theme, 200 + mi)  editor_open_message(m.id);
    }

    // ---- 问题列表（每次编辑后自动检查）
    section(*c, ifx ed.problems.count then tprint("Problems (%)", ed.problems.count) else "No problems");
    for ed.problems  text_label(*c, it, *dim_theme);

    end_scrollable_region(region, c.x + c.w, c.y - 4, *right_scroll);
}

draw_tunnels :: (c: *Column) {
    l := *ed.level;

    section(c, tprint("Tunnels (%)", l.tunnels.count));
    row := split_row(next_row(c), 1, 1);
    if button(row[0], "+ New", *button_theme, 0) {
        begin_stroke(); stroke_touch_tunnels();
        t := array_add(*l.tunnels);
        p := ifx ed.hover_valid then ed.hover else Pos.{0, 0};
        t.ends[0] = .{p, true,  "", #char "a"};
        t.ends[1] = .{p, false, "", #char "b"};
        end_stroke();
        ed.tunnel_index = cast(s32) l.tunnels.count - 1;
        ed.tool = .TUNNEL;
        ed.tunnel_stage = .END0;
        editor_set_status("New tunnel: click end A, then path points, then end B");
    }
    if button(row[1], "Delete", *button_theme, 1) && ed.tunnel_index >= 0 && ed.tunnel_index < l.tunnels.count {
        begin_stroke(); stroke_touch_tunnels();
        array_free(l.tunnels[ed.tunnel_index].path);
        array_ordered_remove_by_index(*l.tunnels, ed.tunnel_index);
        end_stroke();
        clamp_tunnel_index();
    }

    // 列表：每条一行，点一下选中
    for t, ti: l.tunnels {
        a := t.ends[0].pos;
        b := t.ends[1].pos;
        text := tprint("#%   A %,%  ->  B %,%   % pts", ti, a.x, a.y, b.x, b.y, t.path.count);
        radio_button(next_row(c), text, *ed.tunnel_index, cast(s32) ti, *radio_theme, 300 + ti);
    }

    if ed.tunnel_index < 0 || ed.tunnel_index >= l.tunnels.count  return;
    ti := ed.tunnel_index;
    t := *l.tunnels[ti];

    gap(c, 0.3);
    label(next_row(c), tprint("Tunnel #%", ti), *title_theme);

    for * e, ei: t.ends {
        name := ifx ei == 0 then "A" else "B";

        // 位置 + 重新放置 + 初始是否激活
        r := split_row(next_row(c), 2.2, 1.2, 1.6);
        label(r[0], tprint("End %  (%, %)", name, e.pos.x, e.pos.y), *label_theme);
        if button(r[1], "Place", *button_theme, 400 + ei) {
            ed.tool = .TUNNEL;
            ed.tunnel_stage = ifx ei == 0 then Tunnel_Stage.END0 else .END1;
        }
        if base_checkbox(r[2], "Open", e.start_open, *check_theme, 410 + ei) {
            begin_stroke(); stroke_touch_tunnels();
            e.start_open = !e.start_open;
            end_stroke();
        }

        // 端点贴图
        r = split_row(next_row(c), 1.6, 1, 1, 1, 1);
        label(r[0], "  style", *dim_theme);
        for s, si: style_choices {
            v := e.style;
            if radio_button(r[si + 1], s, *v, s[0], *radio_theme, 420 + ei * 10 + si) && v != e.style {
                begin_stroke(); stroke_touch_tunnels();
                e.style = v;
                end_stroke();
            }
        }

        // 抵达时弹出的文本
        r = split_row(next_row(c), 1.6, 4);
        label(r[0], "  text", *dim_theme);
        m := ifx e.message then editor_find_message(e.message) else null;
        caption := ifx e.message then preview_text(ifx m then m.text else "", 20) else "(none) - click to add";
        if button(r[1], caption, *left_button_theme, 440 + ei) {
            if !e.message {
                begin_stroke(); stroke_touch_tunnels();
                e.message = unused_message_id("warp");
                end_stroke();
            }
            editor_open_message(e.message);
        }
    }

    r := split_row(next_row(c), 2.2, 1.2, 1.2, 0.4);
    label(r[0], tprint("Path  % points", t.path.count), *label_theme);
    if button(r[1], "Draw", *button_theme, 450) {
        ed.tool = .TUNNEL;
        ed.tunnel_stage = .PATH;
    }
    if button(r[2], "Clear", *button_theme, 451) && t.path.count {
        begin_stroke(); stroke_touch_tunnels();
        t.path.count = 0;
        end_stroke();
    }
}

// 找一个关卡里还没用过的消息 id：warp1、warp2……（堆上）
unused_message_id :: (prefix: string) -> string {
    n := 1;
    while true {
        id := tprint("%1%2", prefix, n);
        used := editor_find_message(id) != null;
        for t: ed.level.tunnels  for e: t.ends  if e.message == id  used = true;
        if !used  return copy_string(id);
        n += 1;
    }
    return "";
}

draw_message_modal :: () {
    W := cast(float) window_width;
    H := cast(float) window_height;
    rh := row_height();

    m := editor_find_message(ed.modal_id);
    if !m { editor_close_modal(); return; }

    draw_screen_rect(0, 0, W, H, .{0, 0, 0, 0.55});
    bw := min(W - 40, max(W * 0.5, 520.0));
    bh := rh * 5.2;
    modal_rect = get_rect((W - bw) / 2, (H - bh) / 2, bw, bh);
    b := 2.0;
    draw_screen_rect(modal_rect.x - b, modal_rect.y - b, modal_rect.x + modal_rect.w + b, modal_rect.y + modal_rect.h + b, .{1, 0.8, 0.4, 0.8});
    draw_screen_rect(modal_rect.x, modal_rect.y, modal_rect.x + modal_rect.w, modal_rect.y + modal_rect.h, .{0.12, 0.12, 0.15, 1});
    flush_graphics();

    c := Column.{modal_rect.x + 12, modal_rect.w - 24, modal_rect.y + modal_rect.h - 8};
    label(next_row(*c), tprint("Text: %", ed.modal_id), *title_theme);

    // 每次打开用新的 identifier，文本框从当前文本开始；一直保持激活，直接就能打字
    action, text, state := text_input(next_row(*c, 1.3), escape_newlines(m.text), *input_theme, ed.modal_serial, input_action = .ACTIVATE);
    apply := false;
    new_text: string;
    if action & .ENTERED { apply = true; new_text = text; }

    text_label(*c, "\\n = line break    Enter = OK    Esc = cancel", *dim_theme);

    gap(*c, 0.2);
    r := next_row(*c);
    bwid := editor_font.character_height * 4.5;
    rest, cancel := cut_right(r, bwid, 6);
    rest2, ok := cut_right(rest, bwid, 6);
    if button(ok, "OK", *button_theme, 1) && state { apply = true; new_text = state.text; }
    if button(cancel, "Cancel", *button_theme, 2)  editor_close_modal();

    if apply {
        m.text = unescape_newlines(new_text);
        ed.dirty = true;
        editor_set_status("Text '%' updated", m.id);
        editor_close_modal();
    }
}

draw_status_bar :: () {
    r := shrink(bottom_rect, 2);
    text := tprint("%   |   zoom %   |   %   |   LMB apply  RMB erase  MMB/Space drag pan  wheel zoom  Ctrl+Z/Y undo/redo  Ctrl+S save  F5 play  Shift+F5 play from cursor",
                   ed.status, formatFloat(editor_camera.zoom, trailing_width = 2), TOOL_NAMES[ed.tool]);
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
