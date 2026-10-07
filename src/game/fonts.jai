basic_font   : *Font;
debug_font   : *Font;
message_font : *Font;
editor_font  : *Font;
small_font   : *Font;

init_fonts :: () {
    pixel_height := window_height / 12;

    basic_font = load_font(tprint("%/%", FONT_FOLDER, "OpenSans-BoldItalic.ttf"), pixel_height);
    assert(basic_font != null);

    debug_font = load_font(tprint("%/%", FONT_FOLDER, "OpenSans-Regular.ttf"), window_height / 45);
    assert(debug_font != null);

    message_font = load_font(tprint("%/%", FONT_FOLDER, "OpenSans-SemiBold.ttf"), window_height / 32);
    assert(message_font != null);

    editor_font = load_font(tprint("%/%", FONT_FOLDER, "OpenSans-Regular.ttf"), max(window_height / 50, 12));
    assert(editor_font != null);

    small_font = load_font(tprint("%/%", FONT_FOLDER, "OpenSans-Regular.ttf"), max(window_height / 70, 10));
    assert(small_font != null);
}

draw_text :: (text : string, color := WHITE) {
    draw_text(basic_font, text, color);
}

draw_text :: (font : *Font, text : string, color := WHITE) {
    y := window_height/2 + font.character_height/4;

    draw_text_centered(font, text, y, color);
}

// 指定 baseline，水平居中
draw_text_centered :: (font : *Font, text : string, y : int, color := WHITE) {
    text_width := prepare_text(font, text);

    x := (window_width - text_width) / 2;

    draw_prepared_text(font, x, y, color);
}
