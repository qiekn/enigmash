// 贴图表 sprites_all.png 的网格：SPRITE_ROWS 行（一行一个世界），
// SPRITE_COLS 列 = Player / Box / Ground / Wall / Switch（列序和 Sprite 枚举一致）。

// 世界一~六对应第 0~5 行。World_Id.NONE 和 SEVEN 没有自己的行，落到第 0 行 ——
// 由调用方叠色把它们标出来。
world_row :: (world: World_Id) -> int {
    row := cast(int) world - 1;
    if row < 0  return 0;
    return min(row, SPRITE_ROWS - 1);
}

// ----------------------------------------------------------------------------: 基本图元

// 绘制一个纯色方块（整格）
draw_rect :: (x: int, y: int, color : Color = ORANGE) {
    ts := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);

    Simp.set_shader_for_color(true);
    Simp.immediate_quad(p.x, p.y, p.x + ts, p.y + ts, color);
}

// 屏幕空间的纯色矩形，用来画世界边界线
draw_screen_rect :: (x0: float, y0: float, x1: float, y1: float, color: Color) {
    Simp.set_shader_for_color(true);
    Simp.immediate_quad(x0, y0, x1, y1, color);
}

// ----------------------------------------------------------------------------: 精灵
//
// 注意：这里刻意不调 immediate_begin / immediate_flush。
// Simp 只在 shader 真正切换时才 flush，所以连续的 draw_sprite 会自动攒进同一批，
// 一整屏地图也只要几次 draw call。代价是调用方画完必须自己 flush 一次
// （见 draw_one_frame）。

draw_sprite :: (kind: Sprite, world: World_Id, x: int, y: int, tint := WHITE) {
    ts := camera_tile_px();
    p  := world_to_screen(cast(float) x, cast(float) y);

    x0 := p.x;
    y0 := p.y;
    x1 := x0 + ts;
    y1 := y0 + ts;

    col := min(cast(int) kind, SPRITE_COLS - 1);
    row := world_row(world);

    // UV 直接按格数算，不依赖纹理实际像素尺寸
    u0 := cast(float) col       / cast(float) SPRITE_COLS;
    u1 := cast(float)(col + 1)  / cast(float) SPRITE_COLS;
    v0 := cast(float) row       / cast(float) SPRITE_ROWS;
    v1 := cast(float)(row + 1)  / cast(float) SPRITE_ROWS;

    p0 := Vector2.{x0, y0};
    p1 := Vector2.{x1, y0};
    p2 := Vector2.{x1, y1};
    p3 := Vector2.{x0, y1};

    // 屏幕 y 轴朝上、纹理 v 轴朝下，所以下边缘取 v1、上边缘取 v0
    uv0 := Vector2.{u0, v1};
    uv1 := Vector2.{u1, v1};
    uv2 := Vector2.{u1, v0};
    uv3 := Vector2.{u0, v0};

    Simp.set_shader_for_images(*the_sprite);

    Simp.immediate_quad(
        p0, p1, p2, p3,
        tint,
        uv0 = uv0,
        uv1 = uv1,
        uv2 = uv2,
        uv3 = uv3,
    );
}

// ----------------------------------------------------------------------------: 背景清除

clear_background :: (c : Color = BLACK) {
    Simp.clear_render_target(c.x, c.y, c.z, c.w);
}

clear_background :: (x: float, y: float, z: float, w: float) {
    Simp.clear_render_target(x, y, z, w);
}
