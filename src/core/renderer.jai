SPRITE_SHEET_ROW :: 1; // @Temporary

// ----------------------------------------------------------------------------: primitives

// 绘制一个纯色方块（整格）
draw_rect :: (x: int, y: int, color : Color = ORANGE) {
    tile_size := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);

    Simp.set_shader_for_color(true);
    Simp.immediate_quad(p.x, p.y, p.x + tile_size, p.y + tile_size, color);
}

// ----------------------------------------------------------------------------: sprites
//
// 注意：这里刻意不调 immediate_begin / immediate_flush。
// Simp 只在 shader 真正切换时才 flush，所以连续的 draw_sprite 会自动攒进同一批，
// 一整屏地图也只要几次 draw call。代价是调用方画完必须自己 flush 一次
// （见 draw_one_frame）。

draw_sprite :: (kind: Sprite, x: int, y: int, tint := WHITE) {
    tile_size := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);

    x0 := p.x;
    y0 := p.y;
    x1 := x0 + tile_size;
    y1 := y0 + tile_size;

    col := min(cast(int) kind, SPRITE_COLS - 1);
    row := 6 - SPRITE_SHEET_ROW;

    // UV 直接按格数算，不依赖纹理实际像素尺寸
    u0 := cast(float) col       / cast(float) SPRITE_COLS;
    u1 := cast(float)(col + 1)  / cast(float) SPRITE_COLS;
    v0 := cast(float) row       / cast(float) SPRITE_ROWS;
    v1 := cast(float)(row + 1)  / cast(float) SPRITE_ROWS;

    p0 := Vector2.{x0, y0};
    p1 := Vector2.{x1, y0};
    p2 := Vector2.{x1, y1};
    p3 := Vector2.{x0, y1};

    uv0 := Vector2.{u0, v0};
    uv1 := Vector2.{u1, v0};
    uv2 := Vector2.{u1, v1};
    uv3 := Vector2.{u0, v1};

    Simp.set_shader_for_images(*the_sprite);

    Simp.immediate_quad(p0, p1, p2, p3, tint, uv0, uv1, uv2, uv3);
}

// ----------------------------------------------------------------------------: clear background

clear_background :: (c : Color = BLACK) {
    Simp.clear_render_target(c.x, c.y, c.z, c.w);
}

clear_background :: (x: float, y: float, z: float, w: float) {
    Simp.clear_render_target(x, y, z, w);
}
