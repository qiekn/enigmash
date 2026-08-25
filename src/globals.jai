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


game_should_quit := false;

zoom := 16; // @HACK 后面会实现鼠标滚轮缩放的功能
tile_size := FIXED_TILE_SIZE * 16;

// ----------------------------------------------------------------------------: game state

the_player : Player;
