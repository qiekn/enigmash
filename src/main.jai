Program_Mode :: enum {
    GAME;
    EDITOR;
    MENU;
}

// ----------------------------------------------------------------------------: global variables

program_mode := Program_Mode.GAME;

saved_window_info : Saved_Window_Info;

the_window : Window_Type;
the_sprite : Simp.Texture;

window_width  : s32 = 1200;
window_height : s32 = 800;

render_width  : s32 = 1200;
render_height : s32 = 800;

basic_font : *Simp.Dynamic_Font;
debug_font : *Simp.Dynamic_Font;

game_should_quit := false;

// ----------------------------------------------------------------------------: game state

the_player : Player;
the_camera : Camera;

// ----------------------------------------------------------------------------: entry

main :: () {
    last_time := current_time_monotonic();
    current_time : Apollo_Time;

    init_game();

    // play_music(); // @NOTE current, we don't want enable background music. Maybe add an option in menu

    while !game_should_quit {
        clear_background(0.16, 0.17, 0.2, 1);

        // update
        current_time = current_time_monotonic();
        delta_time : s64 = to_milliseconds(current_time - last_time);
        last_time = current_time;

        update_player_input_event(delta_time);
        update_window_events();
        handle_window_resizes();
        handle_input();

        // 菜单里方向键是用来选菜单项的，别让它偷偷推着摄像机跑
        if program_mode == .GAME {
            camera_update(cast(float) delta_time / 1000.0);
        }

        Sound.update();

        // render
        if program_mode == .GAME {
            draw_one_frame();
        } else if program_mode == .EDITOR {

        } else if program_mode == .MENU {
            draw_menu();
            draw_version();
        }


        Simp.swap_buffers(the_window);
        sleep_milliseconds(10);
        reset_temporary_storage();   
    }
}

// ----------------------------------------------------------------------------: helpers

init_game :: () {
    // init window
    the_window = create_window(window_width, window_height, "ck: Enigmash");   
    Simp.set_render_target(the_window);
    toggle_fullscreen(the_window, true, *saved_window_info);

    // init textures
    the_sprite = load_texture(SPRITE_PATH);

    init_fonts();
    init_menu_fonts();

    init_sounds();

    camera_reset();
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
        }
    }
}

handle_input :: () {
    for events_this_frame {
        if it.type == {
            case .QUIT;
                game_should_quit = true;

            case .MOUSE_WHEEL;
                if program_mode == .GAME  handle_camera_wheel(it);

            case .KEYBOARD;
                if program_mode == .MENU {
                    handle_menu_input(it.key_code, it.key_pressed);
                    continue;
                }

                if it.key_code == .ESCAPE {
                    if it.key_pressed then toggle_menu();
                }

                // 摄像机先挑走它关心的键（Tab / 0 / F / 方向键）
                if handle_camera_key(it.key_code, it.key_pressed)  continue;

                handle_player_input(it.key_code, it.key_pressed);
        }
    }
}

draw_one_frame :: () {

    /*
    p0 := Vector3.{0, 0, 0};
    p1 := Vector3.{xx window_width, 0, 0};
    p2 := Vector3.{xx window_width / 2.0, xx window_height, 0};
    Simp.immediate_triangle(p0, p1, p2, RED, GREEN, BLUE);
    */

    draw_background();

    // 玩家永远在最上层
    draw_sprite(.Player, the_player.x, the_player.y);

    // draw_sprite 自己不 flush（为了攒批），这里统一收口
    Simp.immediate_flush();

    draw_camera_debug();
}


// ----------------------------------------------------------------------------: modules

#import "Basic";

#import "Input";
#import "Math";
#import "Random";

Simp :: #import "Simp";
using Sound :: #import "Sound_Player";
#import "Window_Creation";

#load "core/sprites.jai";
#load "core/camera.jai";
#load "core/renderer.jai";
#load "core/sounds.jai";
#load "core/fonts.jai";

#load "config.jai"; // All constants
#load "menu.jai";

#load "entities.jai";
#load "player_input.jai";
#load "move_system.jai";

#load "helpers/checkboard.jai";

