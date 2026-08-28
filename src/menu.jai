#scope_file

title\   _font  : *Simp.Dynamic_Font;
body\    _font  : *Simp.Dynamic_Font;
version\ _font  : *Simp.Dynamic_Font;


Menu_Action :: enum {
    RESUME;
    OPTIONS;
    LOAD_CAMPAIGN;
    NEW_CAMPAIGN;
    QUIT;
}

Menu_Item :: struct {
    action        : Menu_Action;
    label         : string;
    confirm_label : string;
}

menu_items :: Menu_Item.[
    .{.RESUME,        "Resume Game",               ""},
    .{.OPTIONS,       "Options",                   ""},
    .{.LOAD_CAMPAIGN, "Load a Different Campaign", ""},
    .{.NEW_CAMPAIGN,  "Start a New Campaign",      "Choose Again to Restart"},
    .{.QUIT,          "Quit",                      "Quit (Are you sure?)"},
];

selected_index        := 0;
pending_confirm_index := -1;    // 正在等待二次确认的那一项，-1 表示没有

in_options_submenu := false;    // 目前只有这一个子菜单，所以不需要栈

reset_confirmation :: () {
    pending_confirm_index = -1;
}

reset_menu_state :: () {
    selected_index        = 0;
    pending_confirm_index = -1;
    in_options_submenu    = false;
}

handle_confirm :: () {
    item := menu_items[selected_index];

    // 需要二次确认、而且还没确认过 -> 这次 Enter 只是进入确认状态
    if item.confirm_label && pending_confirm_index != selected_index {
        pending_confirm_index = selected_index;
        return;
    }

    reset_confirmation();

    if item.action == {
        case .RESUME;
            toggle_menu();

        case .OPTIONS;
            in_options_submenu = true;

        case .LOAD_CAMPAIGN;
            // @Incomplete 还没有 campaign 的加载流程

        case .NEW_CAMPAIGN;
            // @Incomplete 还没有 campaign 的重开流程

        case .QUIT;
            game_should_quit = true;
    }
}

#scope_export

init_menu_fonts :: () {
    base_height := cast(int) (window_height / 18);

    title_font   = Simp.get_font_at_size(FONT_FOLDER, "Karmina-Bold.otf", xx (base_height * 1.6));
    body_font    = Simp.get_font_at_size(FONT_FOLDER, "Karmina-Bold.otf", base_height);
    version_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-Regular.ttf", xx (base_height * 0.4));
    assert(title_font != null);
}

toggle_menu :: () {
    using Program_Mode;

    if program_mode == GAME {
        program_mode = MENU;
        reset_menu_state();
    } else {
        program_mode = GAME;
    }
}

handle_menu_input :: (key: Key_Code, pressed: u32) {
    if !pressed return;    // 菜单只关心按下的那一帧

    if in_options_submenu {
        // 子菜单目前是空的，只能退回主菜单
        if key == .ESCAPE  in_options_submenu = false;
        return;
    }

    if key == {
        case .ESCAPE;
            reset_confirmation();
            toggle_menu();

        case #char "W"; #through;
        case .ARROW_UP;
            reset_confirmation();
            selected_index -= 1;
            if selected_index < 0  selected_index = menu_items.count - 1;

        case #char "S"; #through;
        case .ARROW_DOWN;
            reset_confirmation();
            selected_index += 1;
            if selected_index >= menu_items.count  selected_index = 0;

        case .SPACEBAR; #through;
        case .ENTER;
            handle_confirm();
    }
}

draw_menu_item :: (item: Menu_Item, index: int, y: int) {
    is_selected   := index == selected_index;
    is_confirming := index == pending_confirm_index;

    label := ifx is_confirming then item.confirm_label else item.label;
    color := ifx is_selected   then ORANGE             else WHITE;

    draw_text_centered(body_font, label, y, color);
}

draw_menu :: () {
    clear_background(BACKGROUND_COLOR);

    if in_options_submenu {
        draw_text(title_font, "Hello, Options");
        return;    // 子菜单内容暂时留空
    }

    //
    // Title
    //
    title_y := cast(int)(window_height * 0.72);
    draw_text_centered(title_font, "ENIGMASH - Jai Rewrite", title_y, WHITE);

    //
    // Items
    //
    stride := body_font.character_height * 3 / 2;
    item_y := title_y - title_font.character_height - stride;

    for menu_items {
        draw_menu_item(it, it_index, item_y);
        item_y -= stride;
    }
}

draw_version :: () {
    font := body_font;
    assert(font != null);

    // @Speed
    text := sprint("Version %.%.%", MAJOR_VERSION, MINOR_VERSION, BABY_VERSION);
    defer free(text);

    text_width := Simp.prepare_text(font, text);
    text_x := window_width - text_width - 20;
    text_y := 20;

    draw_text(font, text, text_x, text_y, WHITE);
}
