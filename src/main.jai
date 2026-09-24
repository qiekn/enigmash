Program_Mode :: enum {
    GAME;
    EDITOR;
    MENU;
}

// ----------------------------------------------------------------------------: global variables

program_mode := Program_Mode.MENU;

saved_window_info : Saved_Window_Info;

the_window : Window_Type;
the_sprite : Simp.Texture;      // 图集（src/generated/atlas.jai）

window_width  : s32 = 1200;
window_height : s32 = 800;

render_width  : s32 = 1200;
render_height : s32 = 800;

basic_font : *Simp.Dynamic_Font;
debug_font : *Simp.Dynamic_Font;

game_should_quit := false;
show_debug       := false;      // F3

// ----------------------------------------------------------------------------: entry

main :: () {
    // 无窗口回放（和原版引擎对照测试用）
    args := get_command_line_arguments();
    for args  if it == "-replay"  exit(xx run_replay(args));

    last_time := current_time_monotonic();
    current_time : Apollo_Time;

    init_game();

    while !game_should_quit {
        // update
        current_time = current_time_monotonic();
        delta_time : s64 = to_milliseconds(current_time - last_time);
        last_time = current_time;
        dt_seconds := cast(float) delta_time / 1000.0;

        update_window_events();
        handle_window_resizes();
        handle_input();

        if program_mode == .GAME {
            update_player_input_event(delta_time);
            session_update(play_session, cast(float) delta_time);
            update_game_camera_target();
            camera_update(dt_seconds);
        } else if program_mode == .EDITOR {
            editor_update(dt_seconds);
        }

        Sound.update();

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

        // swap_buffers 自带 vsync 等待；这里再 sleep 会错过垂直同步，帧率掉到 ~40
        Simp.swap_buffers(the_window);
        reset_temporary_storage();
    }

    if !playtesting && !game.won  session_save(*game);
}

// ----------------------------------------------------------------------------: helpers

init_game :: () {
    // init window
    the_window = create_window(window_width, window_height, "ck: Enigmash");
    Simp.set_render_target(the_window);
    toggle_fullscreen(the_window, true, *saved_window_info);

    // init textures
    the_sprite = load_texture(ATLAS_PATH);
    init_sprite_uvs();

    init_fonts();
    init_menu_fonts();

    init_sounds();

    ui_init();

    // 关卡 + 存档
    if !session_load_level(*game, DEFAULT_LEVEL_PATH) {
        log_error("Can't load the level '%'.", DEFAULT_LEVEL_PATH);
        exit(1);
    }
    if !session_load_save(*game)  session_new_game(*game);

    active_camera = *game_camera;
    camera_map_w = game.level.w;
    camera_map_h = game.level.h;
    update_game_camera_target();
    camera_reset();
}

start_new_game :: () {
    playtesting  = false;
    play_session = *game;
    session_new_game(*game);
    session_save(*game);
    active_camera = *game_camera;
    camera_map_w = game.level.w;
    camera_map_h = game.level.h;
    update_game_camera_target();
    camera_reset();
}

// 镜头跟随原版的 camera 对象（隧道里飞、camerastick / camerashiftleft 都靠它）
update_game_camera_target :: () {
    s := play_session;
    p, ok := session_camera_cell(s);
    if !ok  return;
    w := grid_to_world(*s.level, p);
    game_camera.target = .{w.x + 0.5, w.y + 0.5};
}

handle_window_resizes :: () {
    for get_window_resizes() {
        if it.window == the_window {
            window_width = it.width;
            window_height = it.height;
            render_width  = window_width;
            render_height = window_height;
            Simp.update_window(it.window);
            init_fonts();
            init_menu_fonts();
            game_camera.zoom = camera_view_zoom();
        }
    }
}

handle_input :: () {
    for events_this_frame {
        if it.type == .QUIT  game_should_quit = true;

        if program_mode == .EDITOR {
            getrect_handle_event(it);
        }

        if it.type == {
            case .MOUSE_WHEEL;
                if program_mode == .GAME    handle_camera_wheel(it);
                if program_mode == .EDITOR  editor_handle_event(it);

            case .KEYBOARD;
                if program_mode == .MENU {
                    handle_menu_input(it.key_code, it.key_pressed);
                    continue;
                }

                if it.key_code == .ESCAPE && it.key_pressed {
                    if program_mode == .EDITOR && editor_text_focused {
                        active_widget_deactivate_all();
                        continue;
                    }
                    if program_mode == .GAME && playtesting { editor_stop_playtest(); continue; }
                    open_menu();
                    continue;
                }

                if it.key_code == .F3 && it.key_pressed { show_debug = !show_debug; continue; }

                if program_mode == .EDITOR {
                    editor_handle_event(it);
                    continue;
                }

                // 摄像机先挑走它关心的键（Tab / 0 / F / FREE 模式下的方向键）
                if handle_camera_key(it.key_code, it.key_pressed)  continue;

                handle_player_input(it.key_code, it.key_pressed);
        }
    }
}

draw_game_frame :: () {
    clear_background(GAME_CLEAR_COLOR);

    s := play_session;
    active_camera = *game_camera;
    draw_level(*s.level, *s.state);

    // draw_sprite 自己不 flush（为了攒批），这里统一收口
    Simp.immediate_flush();

    draw_hud();
    if show_debug  draw_camera_debug();
}

draw_editor_frame :: () {
    clear_background(GAME_CLEAR_COLOR);
    active_camera = *editor_camera;

    x, y, width, height := get_dimensions(the_window, true);
    ui_per_frame_update(the_window, width, height, seconds_since_init());

    editor_draw_canvas();
    Simp.immediate_flush();

    editor_draw_panels();
    draw_popups();
}


// ----------------------------------------------------------------------------: modules

#import "Basic";

#import "Input";
#import "Math";
#import "Random";

Simp :: #import "Simp";
using Sound :: #import "Sound_Player";
#import "Window_Creation";
#import "GetRect";

#import "String";
#import "File";
#import "File_Utilities";
#import "Sort";

#load "generated/atlas.jai";

#load "core/sprites.jai";
#load "core/camera.jai";
#load "core/renderer.jai";
#load "core/sounds.jai";
#load "core/fonts.jai";

#load "config.jai"; // All constants
#load "menu.jai";

#load "player_input.jai";

#load "game/types.jai";
#load "game/level.jai";
#load "game/engine.jai";
#load "game/rules_normal.jai";
#load "game/rules_late.jai";
#load "game/session.jai";
#load "game/replay.jai";

#load "render/draw_world.jai";
#load "render/draw_hud.jai";

#load "editor/editor.jai";
#load "editor/editor_ui.jai";
