// ----------------------------------------------------------------------------: primitives

// 绘制一个纯色方块（整格）
draw_rect :: (x: int, y: int, color : Color = ORANGE) {
    tile_size := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);

    Simp.set_shader_for_color(true);
    Simp.immediate_quad(p.x, p.y, p.x + tile_size, p.y + tile_size, color);
}

// 世界坐标里的任意矩形（格为单位，可以是小数）
draw_world_rect :: (x0: float, y0: float, x1: float, y1: float, color: Color) {
    a := world_to_screen(x0, y0);
    b := world_to_screen(x1, y1);
    Simp.set_shader_for_color(true);
    Simp.immediate_quad(a.x, a.y, b.x, b.y, color);
}

// 屏幕像素矩形
draw_screen_rect :: (x0: float, y0: float, x1: float, y1: float, color: Color) {
    Simp.set_shader_for_color(true);
    Simp.immediate_quad(x0, y0, x1, y1, color);
}

// 格子描边（thickness 为像素）
draw_cell_outline :: (x: int, y: int, color: Color, thickness := 2.0) {
    ts := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);
    t  := thickness;
    Simp.set_shader_for_color(true);
    Simp.immediate_quad(p.x,          p.y,          p.x + ts, p.y + t,  color);
    Simp.immediate_quad(p.x,          p.y + ts - t, p.x + ts, p.y + ts, color);
    Simp.immediate_quad(p.x,          p.y,          p.x + t,  p.y + ts, color);
    Simp.immediate_quad(p.x + ts - t, p.y,          p.x + ts, p.y + ts, color);
}

// ----------------------------------------------------------------------------: sprites
//
// 注意：这里刻意不调 immediate_begin / immediate_flush。
// Simp 只在 shader 真正切换时才 flush，所以连续的 draw_sprite 会自动攒进同一批，
// 一整屏地图也只要几次 draw call。代价是调用方画完必须自己 flush 一次
// （见 draw_one_frame）。

Sprite_UV :: struct { u0, v0, u1, v1: float; }

// 启动时算一次（缩小看全图时每帧要画几万个精灵，别每次都做除法）
sprite_uv_table : [#run enum_highest_value(Sprite) + 1] Sprite_UV;

init_sprite_uvs :: () {
    for * sprite_uv_table {
        u0, v0, u1, v1 := sprite_uv_compute(cast(Sprite) it_index);
        it.* = .{u0, v0, u1, v1};
    }
}

sprite_uv :: inline (kind: Sprite) -> (u0: float, v0: float, u1: float, v1: float) {
    t := *sprite_uv_table[cast(int) kind];
    return t.u0, t.v0, t.u1, t.v1;
}

sprite_uv_compute :: (kind: Sprite) -> (u0: float, v0: float, u1: float, v1: float) {
    idx := cast(int) kind;
    col := idx % ATLAS_COLS;
    row := idx / ATLAS_COLS;

    tw := cast(float)(ATLAS_COLS * ATLAS_CELL);
    th := cast(float)(ATLAS_ROWS * ATLAS_CELL);

    // 每个格子中间 5x5 是本体，外圈 1px 是复制出来的边缘（防止采样串到隔壁精灵）
    px0 := cast(float)(col * ATLAS_CELL + 1);
    py0 := cast(float)(row * ATLAS_CELL + 1);   // 从图片顶部数

    // Simp 的 shader 里有 1 - v，所以 v = 0 是图片底部
    return px0 / tw, 1.0 - (py0 + 5) / th, (px0 + 5) / tw, 1.0 - py0 / th;
}

draw_sprite :: (kind: Sprite, x: int, y: int, tint := WHITE) {
    tile_size := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);
    draw_sprite_screen(kind, p.x, p.y, tile_size, tint);
}

// 屏幕像素位置（左下角）和边长
draw_sprite_screen :: (kind: Sprite, x0: float, y0: float, size: float, tint := WHITE) {
    u0, v0, u1, v1 := sprite_uv(kind);

    x1 := x0 + size;
    y1 := y0 + size;

    Simp.set_shader_for_images(*the_sprite);
    Simp.immediate_quad(.{x0, y0}, .{x1, y0}, .{x1, y1}, .{x0, y1}, tint, .{u0, v0}, .{u1, v0}, .{u1, v1}, .{u0, v1});
}

// ----------------------------------------------------------------------------: clear background

clear_background :: (c : Color = BLACK) {
    Simp.clear_render_target(c.x, c.y, c.z, c.w);
}

clear_background :: (x: float, y: float, z: float, w: float) {
    Simp.clear_render_target(x, y, z, w);
}
