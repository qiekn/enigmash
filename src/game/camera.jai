game_camera : Camera;

// 游戏与编辑器共用像素网格设置，各自持有独立的状态和地图边界。
make_game_camera :: () -> Camera {
    camera: Camera;
    camera.viewport = .{cast(float) render_width, cast(float) render_height};
    camera.bounds = .{cast(float) MAP_WIDTH, cast(float) MAP_HEIGHT};
    camera.tile_pixels = FIXED_TILE_SIZE;
    camera.zoom = CAMERA_DEFAULT_ZOOM;
    camera.min_zoom = CAMERA_MIN_ZOOM;
    camera.max_zoom = CAMERA_MAX_ZOOM;
    camera.zoom_step = CAMERA_ZOOM_STEP;
    camera.clamp_margin = CAMERA_CLAMP_MARGIN;
    camera.smooth_time = CAMERA_FOLLOW_SMOOTH_TIME;
    camera.follow_dead_zone = CAMERA_FOLLOW_DEAD_ZONE;
    return camera;
}

camera_view_zoom :: (camera: *Camera) -> float {
    tile := floor(cast(float) camera.viewport.y / VIEW_TILES);
    return clamp(tile / FIXED_TILE_SIZE, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM);
}

camera_reset :: (camera: *Camera) {
    camera.zoom = camera_view_zoom(camera);
    camera.mode = .FOLLOW;
    camera_snap(camera);
}

camera_pan :: (camera: *Camera, dt: float) -> moved: bool {
    dx := 0.0;
    dy := 0.0;

    if is_key_down(.ARROW_LEFT)   dx -= 1;
    if is_key_down(.ARROW_RIGHT)  dx += 1;
    if is_key_down(.ARROW_DOWN)   dy -= 1;
    if is_key_down(.ARROW_UP)     dy += 1;

    if dx == 0 && dy == 0  return false;

    // 斜向要归一化，否则比直线快 sqrt(2) 倍
    len := sqrt(dx*dx + dy*dy);
    dx /= len;
    dy /= len;

    // 速度随 zoom 归一化：放大时慢、缩小时快，屏幕上看到的移动速度才是恒定的
    speed := CAMERA_PAN_SPEED * CAMERA_DEFAULT_ZOOM / camera.zoom;

    camera.pos.x += dx * speed * dt;
    camera.pos.y += dy * speed * dt;
    return true;
}

handle_camera_key :: (camera: *Camera, key: Key_Code, pressed: u32) -> handled: bool {
    if !pressed  return false;

    if key == {
        case .TAB;
            if camera.mode == .FOLLOW  camera.mode = .FREE;
            else                              camera.mode = .FOLLOW;
            camera.vel = .{};
            camera.gliding = false;
            return true;

        case #char "0";
            camera_reset(camera);
            return true;

        case #char "F";
            camera_fit_map(camera);
            return true;
    }

    // 方向键是「持续按住」生效的（camera_pan 每帧轮询 input_button_states），
    // 这里只负责在 FREE 模式下把事件吞掉
    if camera.mode == .FREE {
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

handle_game_camera_event :: (event: Event) -> bool {
    if event.type != .KEYBOARD return false;
    // Ignore OS key repeats so holding Tab cannot toggle follow on and off.
    if event.repeat && (event.key_code == .TAB || event.key_code == #char "0" || event.key_code == #char "F") return true;
    if handle_camera_key(*game_camera, event.key_code, event.key_pressed) return true;

    // During playback Space only moves the camera. In manual play messages and
    // the ending retain their action key, and TAS recording retains its X input.
    if event.key_code != .SPACEBAR return false;
    if !do_active && (play_session.message || play_session.won) return false;
    if tas_active && tas.recording && game_camera.mode == .FOLLOW return false;
    if event.key_pressed && !event.repeat {
        p, ok := session_player_cell(play_session);
        if ok {
            w := grid_to_world(*play_session.level, p);
            camera_glide_to(*game_camera, .{w.x + 0.5, w.y + 0.5});
        }
    }
    return true;
}

handle_camera_wheel :: (camera: *Camera, event: Event, always_anchor_mouse := false) {
    if event.typical_wheel_delta == 0  return;

    // 用 float 相除，细分滚轮才不会被截断成 0
    steps := cast(float) event.wheel_delta / cast(float) event.typical_wheel_delta;

    anchor := camera.viewport * 0.5;

    // 跟随时以屏幕中心缩放，自由模式以鼠标位置缩放。
    if camera.mode == .FREE || always_anchor_mouse {
        mx, my, ok := get_mouse_pointer_position(the_window, true);
        if ok  anchor = .{cast(float) mx, cast(float) my};
    }

    camera_zoom_by(camera, steps, anchor);
}

update_camera_controls :: (camera: *Camera, dt: float, pan_with_arrows := true) {
    if camera.mode == .FREE && pan_with_arrows && camera_pan(camera, dt)  camera.gliding = false;
    camera_update(camera, dt);
}

reset_game_camera :: () {
    game_camera.bounds.x = cast(float) game.level.w;
    game_camera.bounds.y = cast(float) game.level.h;
    update_game_camera_target();
    camera_reset(*game_camera);
}

update_game_camera_target :: () {
    s := play_session;
    p, ok := session_camera_cell(s);
    if !ok  return;
    w := grid_to_world(*s.level, p);
    game_camera.target = .{w.x + 0.5, w.y + 0.5};
}

#scope_file

is_key_down :: (key: Key_Code) -> bool {
    return (input_button_states[key] & .DOWN) != 0;
}
