the_sprite : Texture;

// ----------------------------------------------------------------------------: game atlas

init_sprites :: () {
    the_sprite = load_texture(ATLAS_PATH);
    init_sprite_uvs();
}

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

draw_sprite :: (camera: *Camera, kind: Sprite, x: int, y: int, tint := WHITE) {
    tile_size := camera_tile_px(camera);
    p  := world_to_screen(camera, cast(float) x, cast(float) y);
    draw_sprite_screen(kind, p.x, p.y, tile_size, tint);
}

// 屏幕像素位置（左下角）和边长
draw_sprite_screen :: (kind: Sprite, x0: float, y0: float, size: float, tint := WHITE) {
    u0, v0, u1, v1 := sprite_uv(kind);

    x1 := x0 + size;
    y1 := y0 + size;

    draw_texture_region(*the_sprite, x0, y0, x1, y1, u0, v0, u1, v1, tint);
}
