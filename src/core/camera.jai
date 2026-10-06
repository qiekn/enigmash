// 网格摄像机：世界单位为格，屏幕单位为像素，y 轴向上。
// 视口、边界与参数由调用方设置；坐标变换保持像素取整和精确互逆。
Camera_Mode :: enum { FOLLOW; FREE; }

Camera :: struct {
    pos, target, vel: Vector2;
    zoom := 1.0;
    mode := Camera_Mode.FOLLOW;
    gliding: bool;
    glide_goal: Vector2;

    viewport: Vector2;
    bounds: Vector2;
    tile_pixels := 1.0;
    min_zoom := 0.01;
    max_zoom := 100.0;
    zoom_step := 1.15;
    clamp_margin: float;
    smooth_time := 0.15;
}

camera_tile_px :: (camera: *Camera) -> float {
    px := floor(camera.tile_pixels * camera.zoom + 0.5);
    return max(px, 1.0);
}

camera_origin :: (camera: *Camera) -> Vector2 {
    ts := camera_tile_px(camera);
    return .{
        floor(cast(float) camera.viewport.x  * 0.5 - camera.pos.x * ts + 0.5),
        floor(cast(float) camera.viewport.y * 0.5 - camera.pos.y * ts + 0.5),
    };
}

world_to_screen :: (camera: *Camera, wx: float, wy: float) -> Vector2 {
    ts := camera_tile_px(camera);
    o  := camera_origin(camera);
    return .{wx * ts + o.x, wy * ts + o.y};
}

screen_to_world :: (camera: *Camera, sx: float, sy: float) -> Vector2 {
    ts := camera_tile_px(camera);
    o  := camera_origin(camera);
    return .{(sx - o.x) / ts, (sy - o.y) / ts};
}

camera_visible_grid :: (camera: *Camera) -> (x0: int, y0: int, x1: int, y1: int) {
    lo := screen_to_world(camera, 0.0, 0.0);
    hi := screen_to_world(camera, cast(float) camera.viewport.x, cast(float) camera.viewport.y);

    return cast(int) floor(lo.x), cast(int) floor(lo.y),
           cast(int) ceil (hi.x), cast(int) ceil (hi.y);
}

camera_clamp :: (camera: *Camera) {
    max_x := cast(float) camera.bounds.x + camera.clamp_margin;
    max_y := cast(float) camera.bounds.y + camera.clamp_margin;

    camera.pos.x = clamp(camera.pos.x, -camera.clamp_margin, max_x);
    camera.pos.y = clamp(camera.pos.y, -camera.clamp_margin, max_y);
}

camera_update :: (camera: *Camera, dt: float) {
    if camera.mode == .FOLLOW {
        camera.gliding = false;
        camera.pos = smooth_damp(camera.pos, camera.target, *camera.vel, camera.smooth_time, dt);
    } else {
        if camera.gliding {
            camera.pos = smooth_damp(camera.pos, camera.glide_goal, *camera.vel, camera.smooth_time, dt);
            d := camera.pos - camera.glide_goal;
            if d.x*d.x + d.y*d.y < 0.0001 {
                camera.pos = camera.glide_goal;
                camera.gliding = false;
            }
        }
    }

    camera_clamp(camera);
}

camera_glide_to :: (camera: *Camera, p: Vector2) {
    camera.glide_goal = p;
    camera.gliding    = true;
    camera.vel        = .{};
}

smooth_damp :: (current: Vector2, target: Vector2, vel: *Vector2, smooth_time: float, dt: float) -> Vector2 {
    if dt <= 0  return current;
    omega := 2.0 / max(smooth_time, 0.0001);
    x     := omega * dt;
    decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);

    change := current - target;
    temp   := (vel.* + change * omega) * dt;
    vel.*   = (vel.* - temp * omega) * decay;
    return target + (change + temp) * decay;
}

camera_snap :: (camera: *Camera) {
    camera.pos = camera.target;
    camera.vel = .{};
    camera_clamp(camera);
}

camera_zoom_by :: (camera: *Camera, steps: float, anchor_screen: Vector2) {
    if steps == 0  return;

    // 记下锚点当前对应的 world 坐标，缩放后再把摄像机挪回去，
    // 这样锚点底下的那个格子就不会跑
    before := screen_to_world(camera, anchor_screen.x, anchor_screen.y);

    new_zoom := camera.zoom * pow(camera.zoom_step, steps);
    camera.zoom = clamp(new_zoom, camera.min_zoom, camera.max_zoom);

    after := screen_to_world(camera, anchor_screen.x, anchor_screen.y);
    camera.pos += before - after;

    camera_clamp(camera);
}

camera_fit_map :: (camera: *Camera) {
    zx := cast(float) camera.viewport.x  / cast(float)(camera.bounds.x * camera.tile_pixels);
    zy := cast(float) camera.viewport.y / cast(float)(camera.bounds.y * camera.tile_pixels);

    camera.zoom = clamp(min(zx, zy), camera.min_zoom, camera.max_zoom);
    camera.pos  = .{camera.bounds.x * 0.5, camera.bounds.y * 0.5};
    camera.mode = .FREE;
}

camera_drag :: (camera: *Camera, delta: Vector2) {
    ts := camera_tile_px(camera);
    camera.pos.x -= delta.x / ts;
    camera.pos.y -= delta.y / ts;
    camera_clamp(camera);
}
