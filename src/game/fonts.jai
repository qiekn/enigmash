basic_font : *Font;
debug_font : *Font;
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

// With defaut font
draw_text :: (text : string, color := WHITE) {
    draw_text(basic_font, text, color);
}

// 屏幕正中，水平居中
draw_text :: (font : *Font, text : string, color := WHITE) {
    text_y := window_height/2 + font.character_height/4;

    draw_text_centered(font, text, text_y, color);
}

// 指定 baseline，水平居中
draw_text_centered :: (font : *Font, text : string, y : int, color := WHITE) {
    // 测量并复用准备好的文本，避免居中绘制时重复排版。
    text_width := prepare_text(font, text);

    text_x := (window_width - text_width) / 2;

    draw_prepared_text(font, text_x, y, color);
}
