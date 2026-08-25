draw_background :: () {
    draw_checkerboard();
}

#scope_file

color_no  :: Vector4.{};
color_yes :: Vector4.{0,0,0,0.3};

draw_checkerboard :: () {
    cols := window_width / tile_size + 1;
    rows := window_height / tile_size + 1;

    for col: 0..cols-1 {
        for row: 0..rows-1 {
            color := ifx (col + row) % 2 == 0 then color_yes else color_no;
            draw_colored_rect(col, row, color);
        }
    }
}
