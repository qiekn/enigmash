// ----------------------------------------------------------------------------: constants

JAILOR :: "Qiekn";

// ----------------------------------------------------------------------------: variables

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
