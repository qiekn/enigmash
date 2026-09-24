message_font : *Simp.Dynamic_Font;
editor_font  : *Simp.Dynamic_Font;   // 编辑器面板 / 画布标注
small_font   : *Simp.Dynamic_Font;

init_fonts :: () {
    pixel_height := window_height / 12;

    basic_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-BoldItalic.ttf", pixel_height);
    assert(basic_font != null);

    debug_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-Regular.ttf", window_height / 45);
    assert(debug_font != null);

    message_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-SemiBold.ttf", window_height / 32);
    assert(message_font != null);

    editor_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-Regular.ttf", max(window_height / 50, 12));
    assert(editor_font != null);

    small_font = Simp.get_font_at_size(FONT_FOLDER, "OpenSans-Regular.ttf", max(window_height / 70, 10));
    assert(small_font != null);
}

// With defaut font
draw_text :: (text : string, color := WHITE) {
    draw_text(basic_font, text, color);
}

// 屏幕正中，水平居中
draw_text :: (font : *Simp.Dynamic_Font, text : string, color := WHITE) {
    text_y := window_height/2 + font.character_height/4;

    draw_text_centered(font, text, text_y, color);
}

// 指定 baseline，水平居中
draw_text_centered :: (font : *Simp.Dynamic_Font, text : string, y : int, color := WHITE) {
    // We could just call Simp.draw_text to draw text! But we want to know the width
    // so that we can center the text, and to find the width, we have to do all the
    // text layout. So it makes sense just to draw the prepared text after that,
    // so there's a special routine, "draw_prepared_text", that draws the thing
    // you just prepared and got the width of.
    text_width := Simp.prepare_text(font, text);

    text_x := (window_width - text_width) / 2;

    Simp.draw_prepared_text(font, text_x, y, color);
}

draw_text :: (font: *Simp.Dynamic_Font, text : string, x : int, y : int, color : Color) {
    Simp.draw_text(font, x, y, text, color);
}
