#import "Basic";
#import "Input";
Simp :: #import "Simp";
#import "System";
#import "Window_Creation";


main :: () {
    window_width  : s32 = 1200;
    window_height : s32 = 800;
    render_width  : s32 = 1200;
    render_height : s32 = 800;

    the_windows := create_window(window_width, window_height, "Hello, Sailor");
    Simp.set_render_target(the_windows);
    quit := false;
    while !quit {
        update_window_events();
        for get_window_resizes() {
            if it.window == the_windows {
                window_width  = it.width;
                window_height = it.height;
                render_width  = window_width;
                render_height = window_height;
                Simp.update_window(the_windows);
            }
        }

        Simp.clear_render_target(0.02, 0.15, 0.15, 1);
        for events_this_frame {
            if it.type == .QUIT then 
            quit = true;
        }

        sleep_milliseconds(10);
        Simp.swap_buffers(the_windows);
        reset_temporary_storage();
    }
}
