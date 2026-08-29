draw_background :: () {
    draw_checkerboard();
}

#scope_file

color_yes :: Vector4.{0,0,0,0.3};

// 只画摄像机可见范围 ∩ 地图范围的那部分格子。
// 这样棋盘格既会跟着摄像机滚动，又顺便把地图边界画了出来。
draw_checkerboard :: () {
    vx0, vy0, vx1, vy1 := camera_visible_grid();

    x0 := max(vx0, 0);
    y0 := max(vy0, 0);
    x1 := min(vx1, MAP_WIDTH  - 1);
    y1 := min(vy1, MAP_HEIGHT - 1);

    if x0 > x1 || y0 > y1  return;    // 摄像机完全跑到地图外了

    for col: x0..x1 {
        for row: y0..y1 {
            // 另一半格子留空（露出 clear color），不用白画一遍全透明的 quad
            if (col + row) % 2 != 0  continue;
            draw_rect(col, row, color_yes);
        }
    }
}
