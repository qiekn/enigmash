Font :: Simp.Dynamic_Font;

load_font :: (name: string, size: int) -> *Font {
    for font_cache  if it.name == name && it.height == size  return it.font;

    memory, ok := data_file(name);
    if !ok  return null;

    font := Simp.get_font_at_size(memory, size);
    // 调用方可传临时拼接的路径，缓存键必须拥有自己的内存。
    array_add(*font_cache, .{copy_string(name), size, font});
    return font;
}

// prepare_text 会更新该字体的待绘制文本；测量和 draw_prepared_text 必须配对使用。
prepare_text :: (font: *Font, text: string) -> int { return Simp.prepare_text(font, text); }
draw_prepared_text :: (font: *Font, x: int, y: int, color: Color) {
    Simp.draw_prepared_text(font, x, y, color);
}
draw_text :: (font: *Font, text: string, x: int, y: int, color: Color) {
    Simp.draw_text(font, x, y, text, color);
}

#scope_file
Cached_Font :: struct { name: string; height: int; font: *Font; }
font_cache : [..] Cached_Font;
Simp :: #import "Simp";
