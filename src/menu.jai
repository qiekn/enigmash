#scope_file

title\   _font  : *Simp.Dynamic_Font;
body\    _font  : *Simp.Dynamic_Font;
version\ _font  : *Simp.Dynamic_Font;


Menu_Action :: enum {
    RESUME;
    NEW_GAME;
    EDITOR;
    OPTIONS;
    QUIT;
}

Menu_Item :: struct {
    action        : Menu_Action;
    label         : string;
    confirm_label : string;
}

menu_items :: Menu_Item.[
    .{.RESUME,   "Continue",     ""},
    .{.NEW_GAME, "New Game",     "Start Over? (progress will be lost)"},
    .{.EDITOR,   "Level Editor", ""},
    .{.OPTIONS,  "Options",      ""},
    .{.QUIT,     "Quit",         "Quit (Are you sure?)"},
];

selected_index        := 0;
pending_confirm_index := -1;    // 正在等待二次确认的那一项，-1 表示没有

in_options_submenu := false;    // 目前只有这一个子菜单，所以不需要栈
options_index      := 0;

OPTION_COUNT :: 2;              // Music / Back

reset_confirmation :: () {
    pending_confirm_index = -1;
}

reset_menu_state :: () {
    selected_index        = 0;
    pending_confirm_index = -1;
    in_options_submenu    = false;
    options_index         = 0;
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
            close_menu();

        case .NEW_GAME;
            start_new_game();
            menu_return_mode = .GAME;
            close_menu();

        case .EDITOR;
            enter_editor();

        case .OPTIONS;
            in_options_submenu = true;
            options_index = 0;

        case .QUIT;
            game_should_quit = true;
    }
}

handle_options_input :: (key: Key_Code) {
    if key == {
        case .ESCAPE;
            in_options_submenu = false;

        case #char "W"; #through;
        case .ARROW_UP;
            options_index = (options_index + OPTION_COUNT - 1) % OPTION_COUNT;

        case #char "S"; #through;
        case .ARROW_DOWN;
            options_index = (options_index + 1) % OPTION_COUNT;

        case .SPACEBAR; #through;
        case .ENTER;
            if options_index == 0  set_music_enabled(!music_enabled);
            else                   in_options_submenu = false;
    }
}

#scope_export

menu_return_mode := Program_Mode.GAME;

init_menu_fonts :: () {
    base_height := cast(int) (window_height / 18);

    title_font   = Simp.get_font_at_size(FONT_FOLDER, "Karmina-Bold.otf", xx (base_height * 1.6));
    body_font    = Simp.get_font_at_size(FONT_FOLDER, "Karmina-Bold.otf", base_height);
    version_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-Regular.ttf", xx (base_height * 0.4));
    assert(title_font != null);
}

open_menu :: () {
    if program_mode != .MENU  menu_return_mode = program_mode;
    program_mode = .MENU;
    reset_menu_state();
    release_player_keys();
}

close_menu :: () {
    program_mode = menu_return_mode;
    if program_mode == .GAME  active_camera = *game_camera;
    if program_mode == .EDITOR  active_camera = *editor_camera;
}

toggle_menu :: () {
    if program_mode == .MENU  close_menu();
    else                      open_menu();
}

handle_menu_input :: (key: Key_Code, pressed: u32) {
    if !pressed return;    // 菜单只关心按下的那一帧

    if in_options_submenu {
        handle_options_input(key);
        return;
    }

    if key == {
        case .ESCAPE;
            reset_confirmation();
            close_menu();

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

draw_menu_item :: (label: string, index: int, selected: int, y: int) {
    color := ifx index == selected then ORANGE else WHITE;
    draw_text_centered(body_font, label, y, color);
}

draw_menu :: () {
    clear_background(BACKGROUND_COLOR);

    title_y := cast(int)(window_height * 0.72);
    stride := body_font.character_height * 3 / 2;
    item_y := title_y - title_font.character_height - stride;

    if in_options_submenu {
        draw_text_centered(title_font, "Options", title_y, WHITE);
        draw_menu_item(tprint("Music: %", ifx music_enabled "On" else "Off"), 0, options_index, item_y);
        draw_menu_item("Back", 1, options_index, item_y - stride);
        return;
    }

    //
    // Title
    //
    draw_text_centered(title_font, "ENIGMASH - Jai Rewrite", title_y, WHITE);

    //
    // Items
    //
    for menu_items {
        label := ifx it_index == pending_confirm_index then it.confirm_label else it.label;
        draw_menu_item(label, it_index, selected_index, item_y);
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
