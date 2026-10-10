Program_Mode :: enum {
    GAME;
    EDITOR;
    MENU;
}

// ----------------------------------------------------------------------------: global variables

program_mode := Program_Mode.MENU;

saved_window_info : Saved_Window_Info;

the_window : Window_Type;

window_width  : s32 = 1200;
window_height : s32 = 800;

render_width  : s32 = 1200;
render_height : s32 = 800;

game_should_quit := false;

// ----------------------------------------------------------------------------: entry

#if !#exists(TAS_TEST_MAIN) {
    main :: () { run_application(); }
}

run_application :: () {
    last_time := current_time_monotonic();
    current_time : Apollo_Time;

    init_game();
    defer shutdown_audio();

    while !game_should_quit {
        // update
        current_time = current_time_monotonic();
        delta_time : s64 = to_milliseconds(current_time - last_time);
        last_time = current_time;
        dt_seconds := cast(float) delta_time / 1000.0;

        update_window_events();
        handle_window_resizes();
        handle_input();

        if !input_application_has_focus {
            release_player_keys();
            if do_active do_stop();
            if tas_active { tas_pause(*tas); tas.recording = false; tas_dragging = false; }
        }

        if program_mode == .GAME {
            if !terminal.open && input_application_has_focus {
                if tas_active tas_update_pointer();
                if do_active do_update(cast(float) delta_time);
                else {
                    update_player_input_event(delta_time);
                    if tas_active tas_update(*tas, cast(float) delta_time);
                    else session_update(play_session, cast(float) delta_time);
                }
            }
            wave_fx_update(play_session, cast(float) delta_time);
            update_game_camera_target();
            update_camera_controls(*game_camera, dt_seconds, !terminal.open && !tas_active);
        } else if program_mode == .EDITOR && !terminal.open {
            editor_update(dt_seconds);
        }

        play_session_sounds(play_session);
        update_audio();

        // render
        if program_mode == {
            case .GAME;
                draw_game_frame();
            case .EDITOR;
                draw_editor_frame();
            case .MENU;
                draw_menu();
                draw_version();
        }

        draw_tas_panel();
        draw_terminal();
        flush_graphics();
        present_graphics(the_window);
        reset_temporary_storage();
    }

    if !playtesting && !game.won  session_save(*game);
}

// ----------------------------------------------------------------------------: helpers

init_game :: () {
    // 资源包（同时把工作目录切到 exe 所在目录）
    init_data_package();

    // init window
    the_window = create_window(window_width, window_height, "ck: Enigmash");
    set_graphics_target(the_window);
    toggle_fullscreen(the_window, true, *saved_window_info);

    // init textures
    init_sprites();
    game_camera = make_game_camera();
    editor_camera = make_game_camera();

    init_fonts();
    init_menu_fonts();
    terminal_init_font();

    init_audio();
    init_sounds();

    ui_init();

    // 关卡 + 存档（默认接着玩最近写过的那个战役）
    if !session_load_default_level(*game) {
        log_error("Can't load the level '%'.", DEFAULT_LEVEL_NAME);
        exit(1);
    }
    current_campaign = latest_campaign();
    if !current_campaign  current_campaign = 1;
    if !session_load_save(*game)  session_new_game(*game);

    reset_game_camera();
}

handle_window_resizes :: () {
    for get_window_resizes() {
        if it.window == the_window {
            window_width, window_height = it.width, it.height;
            render_width, render_height = window_width, window_height;
            resize_graphics(it.window);
            init_fonts();
            init_menu_fonts();
            game_camera.viewport = .{cast(float) render_width, cast(float) render_height};
            editor_camera.viewport = game_camera.viewport;
            game_camera.zoom = camera_view_zoom(*game_camera);
        }
    }
}

handle_input :: () {
    for events_this_frame {
        if it.type == .QUIT  game_should_quit = true;

        if do_handle_event(it) continue;
        if terminal_handle_event(it) continue;
        if tas_handle_event(it) continue;

        if program_mode == .EDITOR {
            getrect_handle_event(it);
        }

        if it.type == {
            case .MOUSE_WHEEL;
                if program_mode == .GAME    handle_camera_wheel(*game_camera, it);
                if program_mode == .EDITOR  editor_handle_event(it);

            case .KEYBOARD;
                if program_mode == .MENU {
                    handle_menu_input(it.key_code, it.key_pressed);
                    continue;
                }

                if it.key_code == .ESCAPE && it.key_pressed {
                    if program_mode == .EDITOR && ed.modal_open {
                        editor_close_modal();
                        continue;
                    }
                    if program_mode == .EDITOR && editor_text_focused {
                        active_widget_deactivate_all();
                        continue;
                    }
                    if program_mode == .GAME && playtesting { editor_stop_playtest(); continue; }
                    open_menu();
                    continue;
                }

                if program_mode == .EDITOR {
                    editor_handle_event(it);
                    continue;
                }

                // 普通游戏与 do 播放共用相机按键，Space 定位在两种镜头模式下都可用。
                if handle_game_camera_event(it) continue;

                handle_player_input(it.key_code, it.key_pressed);
        }
    }
}

// ----------------------------------------------------------------------------: modules

#import "Basic";

#import "Input";
#import "Math";
#import "Random";

#import "Window_Creation";
#import "GetRect";

#import "String";
#import "File";
#import "File_Utilities";
#import "Sort";

#import "GL";
using Simp :: #import "Simp";

#load "core/package.jai";
#load "core/textures.jai";
#load "core/camera.jai";
#load "core/graphics.jai";
#load "core/audio.jai";
#load "core/fonts.jai";
#load "core/colors.jai";

#load "config.jai"; // All constants
#load "game/menu.jai";

#load "game/input.jai";

#load "game/types.jai";
#load "game/level.jai";
#load "game/simulation.jai";
#load "game/rules_normal.jai";
#load "game/rules_late.jai";
#load "game/session.jai";
#load "game/camera.jai";
#load "game/sprites.jai";
#load "game/sounds.jai";
#load "game/fonts.jai";

#load "game/render/draw_world.jai";
#load "game/render/draw_hud.jai";
#load "game/render/wave_fx.jai";

#load "editor/editor.jai";
#load "editor/editor_ui.jai";

#load "tas/timeline.jai";
#load "tas/storage.jai";
#load "tas/editor.jai";
#load "tas/playback.jai";
#load "terminal/terminal.jai";
#load "terminal/view.jai";
