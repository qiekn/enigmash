// 2D 网格摄像机
//
// Simp 的投影矩阵是写死的屏幕正交投影（immediate_set_2d_projection），没有公开的自定义
// 矩阵入口，所以 world(grid) -> screen(pixel) 的变换在 CPU 侧做，全部收敛到
// world_to_screen() / screen_to_world() 这一对互逆函数里。

Camera_Mode :: enum {
    FOLLOW;  // 平滑跟随玩家
    FREE;    // 开发用自由摄像机
}

Camera :: struct {
    pos  : Vector2;                 // 摄像机中心，单位 = grid（float，允许在格子之间）
    zoom := CAMERA_DEFAULT_ZOOM;    // 1 tile = FIXED_TILE_SIZE * zoom 像素
    mode := Camera_Mode.FOLLOW;
}

// ----------------------------------------------------------------------------: 坐标变换

// tile 的实际边长。取整到整数像素，否则 5x5 的像素画在非整数缩放下会粗细不均、
// tile 之间还会露出缝。
camera_tile_px :: () -> float {
    px := floor(FIXED_TILE_SIZE * the_camera.zoom + 0.5);
    return max(px, 1.0);
}

// world (0,0) 这个角落落在屏幕上的像素位置。同样取整，这样 tile 边界永远压在整像素上。
camera_origin :: () -> Vector2 {
    ts := camera_tile_px();
    return .{
        floor(cast(float) render_width  * 0.5 - the_camera.pos.x * ts + 0.5),
        floor(cast(float) render_height * 0.5 - the_camera.pos.y * ts + 0.5),
    };
}

world_to_screen :: (wx: float, wy: float) -> Vector2 {
    ts := camera_tile_px();
    o  := camera_origin();
    return .{wx * ts + o.x, wy * ts + o.y};
}

// world_to_screen 的精确逆运算 —— 「缩放锚定鼠标」手感正确的前提。
screen_to_world :: (sx: float, sy: float) -> Vector2 {
    ts := camera_tile_px();
    o  := camera_origin();
    return .{(sx - o.x) / ts, (sy - o.y) / ts};
}

// 当前可见的 grid 范围（闭区间，两端都向外取整一格），用来做剔除。
// 注意 Simp 是 y 轴朝上的，所以屏幕 (0,0) 是左下角，对应 world 的最小 y。
camera_visible_grid :: () -> (x0: int, y0: int, x1: int, y1: int) {
    lo := screen_to_world(0.0, 0.0);
    hi := screen_to_world(cast(float) render_width, cast(float) render_height);

    return cast(int) floor(lo.x), cast(int) floor(lo.y),
           cast(int) ceil (hi.x), cast(int) ceil (hi.y);
}

// ----------------------------------------------------------------------------: 内部

#scope_file

is_key_down :: (key: Key_Code) -> bool {
    return (input_button_states[key] & .DOWN) != 0;
}

screen_center :: () -> Vector2 {
    return .{cast(float) render_width * 0.5, cast(float) render_height * 0.5};
}

player_center :: () -> Vector2 {
    // tile 占 [x, x+1)，要对准格子中心
    return .{cast(float) the_player.x + 0.5, cast(float) the_player.y + 0.5};
}

// 留 margin 是为了开发时能看清地图边界，而不是被硬卡在边上
camera_clamp :: () {
    max_x := cast(float) MAP_WIDTH  + CAMERA_CLAMP_MARGIN;
    max_y := cast(float) MAP_HEIGHT + CAMERA_CLAMP_MARGIN;

    the_camera.pos.x = clamp(the_camera.pos.x, -CAMERA_CLAMP_MARGIN, max_x);
    the_camera.pos.y = clamp(the_camera.pos.y, -CAMERA_CLAMP_MARGIN, max_y);
}

// 方向键平移，只在 FREE 模式下生效
camera_pan :: (dt: float) {
    dx := 0.0;
    dy := 0.0;

    if is_key_down(.ARROW_LEFT)   dx -= 1;
    if is_key_down(.ARROW_RIGHT)  dx += 1;
    if is_key_down(.ARROW_DOWN)   dy -= 1;
    if is_key_down(.ARROW_UP)     dy += 1;

    if dx == 0 && dy == 0  return;

    // 斜向要归一化，否则比直线快 sqrt(2) 倍
    len := sqrt(dx*dx + dy*dy);
    dx /= len;
    dy /= len;

    // 速度随 zoom 归一化：放大时慢、缩小时快，屏幕上看到的移动速度才是恒定的
    speed := CAMERA_PAN_SPEED * CAMERA_DEFAULT_ZOOM / the_camera.zoom;

    the_camera.pos.x += dx * speed * dt;
    the_camera.pos.y += dy * speed * dt;
}

#scope_export

// ----------------------------------------------------------------------------: 状态更新

// dt 单位是秒
camera_update :: (dt: float) {
    if the_camera.mode == .FOLLOW {
        // 指数平滑，帧率无关
        t := 1.0 - exp(-CAMERA_FOLLOW_SPEED * dt);
        the_camera.pos = lerp(the_camera.pos, player_center(), t);
    } else {
        camera_pan(dt);
    }

    camera_clamp();
}

// steps 是滚轮格数，可以是小数（细分滚轮）
camera_zoom_by :: (steps: float, anchor_screen: Vector2) {
    if steps == 0  return;

    // 记下锚点当前对应的 world 坐标，缩放后再把摄像机挪回去，
    // 这样锚点底下的那个格子就不会跑
    before := screen_to_world(anchor_screen.x, anchor_screen.y);

    new_zoom := the_camera.zoom * pow(CAMERA_ZOOM_STEP, steps);
    the_camera.zoom = clamp(new_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM);

    after := screen_to_world(anchor_screen.x, anchor_screen.y);
    the_camera.pos += before - after;

    camera_clamp();
}

// 回到默认缩放、吸附玩家、切回跟随
camera_reset :: () {
    the_camera.zoom = CAMERA_DEFAULT_ZOOM;
    the_camera.mode = .FOLLOW;
    the_camera.pos  = player_center();
}

// 缩放到整张地图刚好铺满屏幕
camera_fit_map :: () {
    zx := cast(float) render_width  / cast(float) (MAP_WIDTH  * FIXED_TILE_SIZE);
    zy := cast(float) render_height / cast(float) (MAP_HEIGHT * FIXED_TILE_SIZE);

    the_camera.zoom = clamp(min(zx, zy), CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM);
    the_camera.pos  = .{cast(float) MAP_WIDTH * 0.5, cast(float) MAP_HEIGHT * 0.5};
    the_camera.mode = .FREE;    // 看整张地图必然要脱离玩家
}

// ----------------------------------------------------------------------------: 输入

// 返回 true 表示这个按键归摄像机管，不要再往下传给玩家
handle_camera_key :: (key: Key_Code, pressed: u32) -> handled: bool {
    if !pressed  return false;

    if key == {
        case .TAB;
            if the_camera.mode == .FOLLOW  the_camera.mode = .FREE;
            else                           the_camera.mode = .FOLLOW;
            return true;

        case #char "0";
            camera_reset();
            return true;

        case #char "F";
            camera_fit_map();
            return true;
    }

    // 方向键是「持续按住」生效的（camera_pan 每帧轮询 input_button_states），
    // 这里只负责在 FREE 模式下把事件吞掉
    if the_camera.mode == .FREE {
        if key == {
            case .ARROW_LEFT;  #through;
            case .ARROW_RIGHT; #through;
            case .ARROW_UP;    #through;
            case .ARROW_DOWN;
                return true;
        }
    }

    return false;
}

handle_camera_wheel :: (event: Event) {
    if event.typical_wheel_delta == 0  return;

    // 用 float 相除，细分滚轮才不会被截断成 0
    steps := cast(float) event.wheel_delta / cast(float) event.typical_wheel_delta;

    anchor := screen_center();

    // FOLLOW 模式摄像机锁在玩家身上，挪不动，只能以屏幕中心为锚点
    if the_camera.mode == .FREE {
        mx, my, ok := get_mouse_pointer_position(the_window, true);
        if ok  anchor = .{cast(float) mx, cast(float) my};
    }

    camera_zoom_by(steps, anchor);
}

// ----------------------------------------------------------------------------: 调试

// HUD 用的是 OpenSans，没有 CJK 字形，所以这里一律用 ASCII
draw_camera_debug :: () {
    if !debug_font  return;

    vx0, vy0, vx1, vy1 := camera_visible_grid();

    line_h := debug_font.character_height * 3 / 2;
    x      := 20;
    y      := window_height - line_h;

    draw_text(debug_font, tprint("camera  %", the_camera.mode), x, y, DEBUG_TEXT_COLOR);
    y -= line_h;

    draw_text(debug_font, tprint("pos     %, %",
                                 formatFloat(the_camera.pos.x, trailing_width = 1),
                                 formatFloat(the_camera.pos.y, trailing_width = 1)), x, y, DEBUG_TEXT_COLOR);
    y -= line_h;

    draw_text(debug_font, tprint("zoom    %  (tile = % px)",
                                 formatFloat(the_camera.zoom, trailing_width = 2),
                                 camera_tile_px()), x, y, DEBUG_TEXT_COLOR);
    y -= line_h;

    draw_text(debug_font, tprint("visible %,% .. %,%", vx0, vy0, vx1, vy1), x, y, DEBUG_TEXT_COLOR);
    y -= line_h;

    draw_text(debug_font, tprint("player  %, %", the_player.x, the_player.y), x, y, DEBUG_TEXT_COLOR);
    y -= line_h * 2;

    draw_text(debug_font, "Tab: follow/free   arrows: pan   wheel: zoom   0: reset   F: fit map", x, y, DEBUG_TEXT_COLOR);
}
