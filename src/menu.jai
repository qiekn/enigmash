#scope_file

title\   _font  : *Simp.Dynamic_Font;
body\    _font  : *Simp.Dynamic_Font;
version\ _font  : *Simp.Dynamic_Font;


Menu_Action :: enum {
    RESUME;
    LOAD_CAMPAIGN;
    NEW_CAMPAIGN;
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
    .{.RESUME,        "Resume Game",                ""},
    .{.EDITOR,        "Level Editor",               ""},
    .{.OPTIONS,       "Options",                    ""},
    .{.LOAD_CAMPAIGN, "Load a Different Campaign",  ""},
    .{.NEW_CAMPAIGN,  "Start a New Campaign",       "Choose Again to Restart"},
    .{.QUIT,          "Quit",                       "Quit (Are you sure?)"},
];

Submenu :: enum {
    NONE;
    OPTIONS;
    CAMPAIGNS;
}

selected_index        := 0;
pending_confirm_index := -1;    // 正在等待二次确认的那一项，-1 表示没有

submenu       := Submenu.NONE;
submenu_index := 0;

OPTION_COUNT :: 2;              // Music / Back

campaign_ids : [..] int;        // 打开战役列表时扫一遍存档目录

reset_confirmation :: () {
    pending_confirm_index = -1;
}

reset_menu_state :: () {
    selected_index        = 0;
    pending_confirm_index = -1;
    submenu               = .NONE;
    submenu_index         = 0;
}

open_campaign_list :: () {
    array_reset(*campaign_ids);
    for list_campaigns()  array_add(*campaign_ids, it);
    submenu = .CAMPAIGNS;
    submenu_index = 0;
    for campaign_ids  if it == current_campaign  submenu_index = it_index;
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

        case .LOAD_CAMPAIGN;
            open_campaign_list();

        case .NEW_CAMPAIGN;
            start_new_campaign();
            menu_return_mode = .GAME;
            close_menu();

        case .EDITOR;
            enter_editor();

        case .OPTIONS;
            submenu = .OPTIONS;
            submenu_index = 0;

        case .QUIT;
            game_should_quit = true;
    }
}

handle_submenu_input :: (key: Key_Code) {
    count := ifx submenu == .OPTIONS then OPTION_COUNT else campaign_ids.count + 1;   // 最后一项是 Back

    if key == {
        case .ESCAPE;
            submenu = .NONE;

        case #char "W"; #through;
        case .ARROW_UP;
            submenu_index = (submenu_index + count - 1) % count;

        case #char "S"; #through;
        case .ARROW_DOWN;
            submenu_index = (submenu_index + 1) % count;

        case .SPACEBAR; #through;
        case .ENTER;
            if submenu_index == count - 1 {
                submenu = .NONE;
            } else if submenu == .OPTIONS {
                set_music_enabled(!music_enabled);
            } else {
                load_campaign(campaign_ids[submenu_index]);
                menu_return_mode = .GAME;
                close_menu();
            }
    }
}

#scope_export

menu_return_mode := Program_Mode.GAME;

init_menu_fonts :: () {
    base_height := cast(int) (window_height / 18);

    title_font   = load_font("Karmina-Bold.otf", xx (base_height * 1.6));
    body_font    = load_font("Karmina-Bold.otf", base_height);
    version_font = load_font("OpenSans-Regular.ttf", xx (base_height * 0.4));
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

    if submenu != .NONE {
        handle_submenu_input(key);
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

    if submenu == .OPTIONS {
        draw_text_centered(title_font, "Options", title_y, WHITE);
        draw_menu_item(tprint("Music: %", ifx music_enabled "On" else "Off"), 0, submenu_index, item_y);
        draw_menu_item("Back", 1, submenu_index, item_y - stride);
        return;
    }

    if submenu == .CAMPAIGNS {
        draw_text_centered(title_font, "Campaigns", title_y, WHITE);

        // 存档多了就只画选中项附近的一段
        first := clamp(submenu_index - MENU_VISIBLE_CAMPAIGNS / 2, 0, max(0, campaign_ids.count - MENU_VISIBLE_CAMPAIGNS));
        last  := min(first + MENU_VISIBLE_CAMPAIGNS, campaign_ids.count) - 1;
        for i: first..last {
            id := campaign_ids[i];
            label := ifx id == current_campaign then tprint("Campaign % (current)", id) else tprint("Campaign %", id);
            draw_menu_item(label, i, submenu_index, item_y);
            item_y -= stride;
        }
        if !campaign_ids  draw_text_centered(body_font, "No saved campaigns", item_y, HINT_TEXT_COLOR);
        if !campaign_ids  item_y -= stride;
        draw_menu_item("Back", campaign_ids.count, submenu_index, item_y);
        return;
    }

    //
    // Title
    //
    draw_text_centered(title_font, "Enigmash - Rewrite", title_y, WHITE);

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
