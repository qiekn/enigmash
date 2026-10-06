// ----------------------------------------------------------------------------: drawing

// 屏幕坐标以左下角为原点。绘制只入批，调用方在世界 / UI 边界提交。
draw_screen_rect :: (x0: float, y0: float, x1: float, y1: float, color: Color) {
    Simp.set_shader_for_color(true);
    Simp.immediate_quad(x0, y0, x1, y1, color);
}

draw_texture_region :: (texture: *Texture, x0: float, y0: float, x1: float, y1: float,
                        u0: float, v0: float, u1: float, v1: float, tint := WHITE) {
    begin_texture_batch(texture);
    draw_texture_quad(x0, y0, x1, y1, u0, v0, u1, v1, tint);
}

// Simp 选择纹理时会 flush；大量同图集精灵只绑定一次，再连续追加 quad。
begin_texture_batch :: (texture: *Texture) {
    Simp.set_shader_for_images(texture);
}

// 使用 begin_texture_batch 选中的纹理；批内不能穿插文字或纯色绘制。
draw_texture_quad :: (x0: float, y0: float, x1: float, y1: float,
                      u0: float, v0: float, u1: float, v1: float, tint := WHITE) {
    Simp.immediate_quad(.{x0, y0}, .{x1, y0}, .{x1, y1}, .{x0, y1}, tint,
                        .{u0, v0}, .{u1, v0}, .{u1, v1}, .{u0, v1});
}

flush_graphics :: () { Simp.immediate_flush(); }
set_graphics_target :: (window: Window_Type) { Simp.set_render_target(window); }
resize_graphics :: (window: Window_Type) { Simp.update_window(window); }
present_graphics :: (window: Window_Type) { Simp.swap_buffers(window); }

draw_rect :: (camera: *Camera, x: int, y: int, color : Color = ORANGE) {
    tile_size := camera_tile_px(camera);
    p  := world_to_screen(camera, cast(float) x, cast(float) y);

    draw_screen_rect(p.x, p.y, p.x + tile_size, p.y + tile_size, color);
}

draw_world_rect :: (camera: *Camera, x0: float, y0: float, x1: float, y1: float, color: Color) {
    a := world_to_screen(camera, x0, y0);
    b := world_to_screen(camera, x1, y1);
    draw_screen_rect(a.x, a.y, b.x, b.y, color);
}

draw_cell_outline :: (camera: *Camera, x: int, y: int, color: Color, thickness := 2.0) {
    ts := camera_tile_px(camera);
    p  := world_to_screen(camera, cast(float) x, cast(float) y);
    t  := thickness;
    draw_screen_rect(p.x,          p.y,          p.x + ts, p.y + t,  color);
    draw_screen_rect(p.x,          p.y + ts - t, p.x + ts, p.y + ts, color);
    draw_screen_rect(p.x,          p.y,          p.x + t,  p.y + ts, color);
    draw_screen_rect(p.x + ts - t, p.y,          p.x + ts, p.y + ts, color);
}

// ----------------------------------------------------------------------------: frame

clear_background :: (c : Color = BLACK) {
    Simp.clear_render_target(c.x, c.y, c.z, c.w);
}

clear_background :: (x: float, y: float, z: float, w: float) {
    Simp.clear_render_target(x, y, z, w);
}

// ----------------------------------------------------------------------------: colors

Color :: Vector4;
BLACK :: Vector4.{0, 0, 0, 1};
WHITE :: Vector4.{1, 1, 1, 1};
RED   :: Vector4.{1, 0, 0, 1};
GREEN :: Vector4.{0, 1, 0, 1};
BLUE  :: Vector4.{0, 0, 1, 1};
CYAN :: Vector4.{0, 1, 1, 1};

ORANGE :: Vector4.{0.92, 0.54, 0.19, 1};

#scope_file
Simp :: #import "Simp";
