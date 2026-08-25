#import "Basic";
#import "Input";
#import "Math";
Simp :: #import "Simp";
#import "Window_Creation";

RED   :: Vector4.{1, 0, 0, 1};
GREEN :: Vector4.{0, 1, 0, 1};
BLUE  :: Vector4.{0, 0, 1, 1};

main :: () {
    window_width  := 800;   
    window_height := 600;

    p0 := Vector3.{0, 0, 0};
    p1 := Vector3.{xx window_width, 0, 0};
    p2 := Vector3.{xx window_width / 2.0, xx window_height, 0};

    the_window := create_window(window_width, window_height, "Hello, Sailor");   
    Simp.set_render_target(the_window);
    Simp.set_shader_for_color(true);

    quit := false;
    while !quit {                          
        Simp.clear_render_target(0.02, 0.15, 0.15, 1);
        update_window_events();

        for events_this_frame {
            if it.type == .QUIT then quit = true;
        }

        Simp.immediate_triangle(p0, p1, p2, RED, GREEN, BLUE);

        Simp.swap_buffers(the_window);
        sleep_milliseconds(10);
        reset_temporary_storage();   
    }
}
