#import "Compiler";
TAS_TEST_MAIN :: true;
#load "../src/main.jai";
#run set_build_options_dc(.{output_path = "../.build", output_executable_name = "camera_tests"});

near :: (actual: Vector2, expected: Vector2) {
    assert(abs(actual.x - expected.x) < 0.002 && abs(actual.y - expected.y) < 0.002,
           "Expected (%, %), got (%, %)", expected.x, expected.y, actual.x, actual.y);
}

settle_camera :: (camera: *Camera) {
    for 0..119 camera_update(camera, 1.0 / 60.0);
}

test_dead_zone :: () {
    for viewport: Vector2.[.{1200, 800}, .{800, 1200}] {
        for zoom: float.[4, 16] {
            base := make_game_camera();
            base.viewport = viewport;
            base.zoom = zoom;
            base.bounds = .{1000, 1000};
            base.pos = .{500, 500};
            half := viewport * (0.35 / camera_tile_px(*base));
            base.target = base.pos + half * 0.9;
            base.vel = .{3, -3};
            settle_camera(*base);
            near(base.pos, .{500, 500});
            near(base.vel, .{});

            for direction: Vector2.[.{1, 0}, .{-1, 0}, .{0, 1}, .{0, -1}, .{1, 1}] {
                camera := base;
                camera.target = base.pos + .{direction.x * (half.x + 1), direction.y * (half.y + 1)};
                camera_update(*camera, 1.0 / 60.0);
                distance := camera.pos - base.pos;
                assert(abs(distance.x) < 1 && abs(distance.y) < 1, "Edge follow must ease in");
                assert(distance.x * direction.x + distance.y * direction.y > 0);
                settle_camera(*camera);
                near(camera.pos, base.pos + direction);
                screen := world_to_screen(*camera, camera.target.x, camera.target.y);
                assert(screen.x >= viewport.x * 0.15 - 1 && screen.x <= viewport.x * 0.85 + 1);
                assert(screen.y >= viewport.y * 0.15 - 1 && screen.y <= viewport.y * 0.85 + 1);

                // Turning back into the interior stops both motion and residual velocity.
                camera.target += direction * 3;
                camera_update(*camera, 1.0 / 60.0);
                stopped := camera.pos;
                camera.target = stopped;
                settle_camera(*camera);
                near(camera.pos, stopped);
                near(camera.vel, .{});
            }

            // A wider view admits the same player position without moving the camera.
            base.target = base.pos + .{half.x + 1, 0};
            base.viewport *= 2;
            settle_camera(*base);
            near(base.pos, .{500, 500});
            base.viewport = viewport;
            base.zoom = zoom * 0.5;
            settle_camera(*base);
            near(base.pos, .{500, 500});
        }
    }

    // Continuous grid movement remains visible at the normal 150 ms input cadence.
    for fps: int.[30, 60, 120] {
        camera := make_game_camera();
        camera.bounds = .{1000, 1000};
        camera.target = .{500, 500};
        camera_reset(*camera);
        for frame: 0..fps*3-1 {
            camera.target.x = 500 + floor(cast(float) frame / cast(float) fps / 0.15);
            camera_update(*camera, 1.0 / cast(float) fps);
            screen := world_to_screen(*camera, camera.target.x, camera.target.y);
            assert(screen.x >= 0 && screen.x < camera.viewport.x);
        }
    }
}

send_key :: (key: Key_Code, repeat := false, pressed: u32 = 1) {
    array_reset(*events_this_frame);
    array_add(*events_this_frame, Event.{type = .KEYBOARD, key_code = key, key_pressed = pressed, repeat = repeat});
    handle_input();
    array_reset(*events_this_frame);
}

test_playback_camera :: () {
    // An isolated world exercises real command/event routing without graphics or saves.
    game.level.w = 40;
    game.level.h = 40;
    state_alloc(*game.level.initial, 1600);
    game.level.letters = NewArray(1600, u8);
    for * game.level.initial.cells it.num = .ONE;
    game.level.initial.cells[20 * 40 + 20].obj = .PLAYER | .CAMERA;
    state_copy(*game.state, game.level.initial);
    state_copy(*game.restart_target, game.level.initial);
    game.headless = true;
    game.no_save = true;
    play_session = *game;
    program_mode = .GAME;
    game_camera = make_game_camera();
    assert(!do_command("D3 -delay 150"));
    assert(do_active && !tas_active && play_session == *do_run.session);
    start: Game_State;
    state_copy(*start, do_run.session.state);
    defer state_free(*start);

    send_key(.TAB);
    assert(game_camera.mode == .FREE);
    send_key(.TAB, repeat = true);
    send_key(.TAB, pressed = 0);
    assert(game_camera.mode == .FREE);
    game_camera.pos = .{3, 3};
    send_key(.SPACEBAR);
    assert(game_camera.gliding && game_camera.mode == .FREE);
    near(game_camera.glide_goal, .{20.5, 19.5});
    settle_camera(*game_camera);
    near(game_camera.pos, .{20.5, 19.5});
    assert(!game_camera.gliding && game_camera.mode == .FREE);

    send_key(.TAB);
    assert(game_camera.mode == .FOLLOW);
    game_camera.pos.x -= 3;
    send_key(.SPACEBAR);
    assert(game_camera.gliding);
    camera_update(*game_camera, 1.0 / 60.0);
    velocity := game_camera.vel;
    send_key(.SPACEBAR, repeat = true);
    near(game_camera.vel, velocity);
    settle_camera(*game_camera);
    near(game_camera.pos, .{20.5, 19.5});
    assert(game_camera.mode == .FOLLOW);

    send_key(#char "W");
    send_key(.ARROW_LEFT, repeat = true);
    assert(do_active && do_run.playing && do_run.playhead == 0);
    assert(state_equal(start, do_run.session.state), "Camera keys must not inject a TAS turn");
    assert(state_equal(start, game.state), "Playback must not alter the campaign");
    do_update(150);
    assert(do_run.playhead == 1, "Camera controls must not interrupt playback");
    p, ok := session_player_cell(play_session);
    assert(ok && p == Pos.{21, 20});

    // Cancel any in-progress recentering when freezing, fitting, or resetting.
    send_key(.SPACEBAR);
    send_key(.TAB);
    frozen := game_camera.pos;
    settle_camera(*game_camera);
    near(game_camera.pos, frozen);
    assert(!game_camera.gliding && game_camera.mode == .FREE);
    send_key(.SPACEBAR);
    send_key(#char "F");
    frozen = game_camera.pos;
    settle_camera(*game_camera);
    near(game_camera.pos, frozen);
    assert(!game_camera.gliding);
    send_key(.SPACEBAR);
    update_game_camera_target();
    send_key(#char "0");
    assert(!game_camera.gliding && game_camera.mode == .FOLLOW);
    near(game_camera.pos, game_camera.target);

    send_key(.ESCAPE);
    send_key(.ESCAPE, pressed = 0);
    assert(!do_active && program_mode == .GAME);
    game_camera.pos.x -= 3;
    send_key(.SPACEBAR);
    settle_camera(*game_camera);
    near(game_camera.pos, .{21.5, 19.5});
    play_session.message = "Keep Space as the manual message action.";
    send_key(.SPACEBAR);
    assert(!play_session.message && !game_camera.gliding);
    tas_active = true;
    tas.recording = true;
    assert(!handle_game_camera_event(.{type = .KEYBOARD, key_code = .SPACEBAR, key_pressed = 1}));
    tas_active = false;
    tas.recording = false;
}

main :: () {
    test_dead_zone();
    test_playback_camera();
    print("Camera checks passed: dead zone, edge/reversal, zoom/resize, playback keys and input isolation.\n");
}
