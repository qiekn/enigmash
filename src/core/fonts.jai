Font :: Simp.Dynamic_Font;

text_width :: (font: *Font, text: string) -> int { return Simp.prepare_text(font, text); }

load_font :: (name: string, size: int) -> *Font {
    // @Improvement It's a little bit silly.
    for font_cache {
        if it.name == name && it.height == size {
            return it.font;
        }
    }

    memory, ok := data_file(name);
    if !ok  return null;

    font := Simp.get_font_at_size(memory, size);
    // 调用方可传临时拼接的路径，缓存键必须拥有自己的内存。
    array_add(*font_cache, .{copy_string(name), size, font});
    return font;
}

draw_text :: (font: *Font, text: string, x: int, y: int, color: Color) {
    Simp.draw_text(font, x, y, text, color);
}

#scope_file

Cached_Font :: struct {
    name: string;
    height: int;
    font: *Font;
}

font_cache : [..] Cached_Font;
