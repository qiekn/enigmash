// 绘制一个纯色方块
draw_colored_rect :: (x: int, y: int, color : Color = ORANGE) {
    x0 := cast(float)(x * tile_size);
    y0 := cast(float)(y * tile_size);

    x1 := x0 + cast(float) tile_size;
    y1 := y0 + cast(float) tile_size;

    Simp.set_shader_for_color(true);
    Simp.immediate_quad(x0, y0, x1, y1, color);
}

draw_sprite :: (sprite: Sprite, x: int, y: int) {
    x0 := cast(float)(x * tile_size);
    y0 := cast(float)(y * tile_size);

    x1 := x0 + cast(float) tile_size;
    y1 := y0 + cast(float) tile_size;

    // @HACK sprites.png 5x5 pixels tile 横向排列
    // 我这里单独处理的 the_sprite
    sprite_index := cast(int) sprite;
    u0 := cast(float)(sprite_index * FIXED_TILE_SIZE) / cast(float)the_sprite.width;
    u1 := cast(float)((sprite_index + 1) * FIXED_TILE_SIZE) / cast(float)the_sprite.width;

    v0 := 0.0;
    v1 := 1.0;

    p0 := Vector2.{x0, y0};
    p1 := Vector2.{x1, y0};
    p2 := Vector2.{x1, y1};
    p3 := Vector2.{x0, y1};

    uv0 := Vector2.{u0, v0};
    uv1 := Vector2.{u1, v0};
    uv2 := Vector2.{u1, v1};
    uv3 := Vector2.{u0, v1};

    Simp.set_shader_for_images(*the_sprite);

    Simp.immediate_begin();

    Simp.immediate_quad(
        p0, p1, p2, p3,
        uv0 = uv0,
        uv1 = uv1,
        uv2 = uv2,
        uv3 = uv3,
    );

    Simp.immediate_flush();
}
