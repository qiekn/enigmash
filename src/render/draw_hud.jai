// 游戏画面上的覆盖层：消息框、按键提示、通关画面。字体没有 CJK 字形，文本一律 ASCII。

draw_hud :: () {
    s := play_session;
    if s.won {
        draw_ending();
        return;
    }

    if s.message  draw_message_box(s.message);
    else          draw_hint_line();
}

#scope_file

draw_hint_line :: () {
    font := debug_font;
    if !font  return;
    text := "WASD/Arrows move   Z undo   R restart   X action   Esc menu";
    if playtesting  text = "PLAYTEST   WASD/Arrows move   Z undo   R restart   Esc back to editor";
    w := Simp.prepare_text(font, text);
    Simp.draw_prepared_text(font, (window_width - w) / 2, font.character_height / 2, HINT_TEXT_COLOR);
}

// 原版的消息是整屏文字；这里画在屏幕下半部的半透明框里，按行动键关闭
draw_message_box :: (text: string) {
    font := message_font;
    if !font  return;

    margin := window_height / 20;
    box_w  := min(window_width - margin * 2, window_height * 3 / 2);
    pad    := font.character_height;
    max_w  := box_w - pad * 2;

    lines := wrap_text(font, text, max_w);
    line_h := font.character_height * 3 / 2;
    box_h := line_h * (lines.count + 1) + pad * 2;

    x0 := (window_width - box_w) / 2;
    y0 := margin;
    draw_screen_rect(xx x0, xx y0, xx (x0 + box_w), xx (y0 + box_h), MESSAGE_BOX_COLOR);

    y := y0 + box_h - pad - font.character_height;
    for lines {
        Simp.draw_text(font, x0 + pad, y, it, MESSAGE_TEXT_COLOR);
        y -= line_h;
    }

    hint := "X to continue";
    hw := Simp.prepare_text(font, hint);
    Simp.draw_prepared_text(font, x0 + box_w - pad - hw, y0 + pad, HINT_TEXT_COLOR);
}

draw_ending :: () {
    clear_background(0, 0, 0, 1);
    title := title_font_for_hud();
    if !title return;

    y := cast(int) window_height * 3 / 5;
    draw_text_centered(title, "THANKS FOR PLAYING", y, WHITE);
    y -= title.character_height * 2;
    draw_text_centered(message_font, "ENIGMASH - original PuzzleScript game by Jack Lance", y, WHITE);
    y -= message_font.character_height * 2;
    draw_text_centered(message_font, "Jai rewrite", y, HINT_TEXT_COLOR);
    y -= message_font.character_height * 3;
    draw_text_centered(message_font, "Press Enter to return to the menu", y, HINT_TEXT_COLOR);
}

title_font_for_hud :: () -> *Simp.Dynamic_Font { return basic_font; }

#scope_export

// 按单词折行；\n 强制换行
wrap_text :: (font: *Simp.Dynamic_Font, text: string, max_width: int) -> [..] string {
    lines: [..] string;
    lines.allocator = temp;

    for paragraph: split(text, "\n",, temp) {
        current := "";
        for word: split(paragraph, " ",, temp) {
            if !word continue;
            candidate := ifx current then tprint("% %", current, word) else word;
            if current && Simp.prepare_text(font, candidate) > max_width {
                array_add(*lines, current);
                current = word;
            } else {
                current = candidate;
            }
        }
        array_add(*lines, current);
    }
    return lines;
}
