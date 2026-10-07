// 游戏里的按键：移动 / 撤销长按会按原版节奏重复（150ms），其余按一次算一次。
//   WASD / 方向键   移动（方向键在 FREE 镜头模式下归摄像机）
//   Z               撤销
//   R               重开到最近的检查点
//   X / 空格 / 回车 行动（终局用）、关闭消息

#scope_file

key_is_held := false;

held_key   : Key_Code;
held_timer : s64; // milliseconds

Game_Key :: enum { NONE; UP; DOWN; LEFT; RIGHT; UNDO; }

classify :: (key: Key_Code) -> Game_Key {
    if key == {
        case #char "W"; #through;
        case .ARROW_UP;
            return .UP;

        case #char "S"; #through;
        case .ARROW_DOWN;
            return .DOWN;

        case #char "A"; #through;
        case .ARROW_LEFT;
            return .LEFT;

        case #char "D"; #through;
        case .ARROW_RIGHT;
            return .RIGHT;

        case #char "Z";
            return .UNDO;
    }
    return .NONE;
}

eat_game_key :: (key: Key_Code) {
    if classify(key) == {
        case .UP;    session_input(play_session, .UP);
        case .DOWN;  session_input(play_session, .DOWN);
        case .LEFT;  session_input(play_session, .LEFT);
        case .RIGHT; session_input(play_session, .RIGHT);
        case .UNDO;  session_undo(play_session);
    }
}

is_action_key :: (key: Key_Code) -> bool {
    return key == #char "X" || key == #char "C" || key == .SPACEBAR || key == .ENTER;
}

#scope_export

handle_player_input :: (key: Key_Code, pressed: u32) {
    s := play_session;

    // 通关画面：回车回菜单
    if s.won {
        if pressed && (key == .ENTER || key == .SPACEBAR) {
            if playtesting  editor_stop_playtest();
            else            open_menu();
        }
        return;
    }

    // 消息框：任意行动键关闭
    if s.message {
        if pressed && is_action_key(key)  session_dismiss_message(s);
        return;
    }

    if pressed {
        if key == #char "R" { session_restart(s); return; }
        if is_action_key(key) { session_input(s, .ACTION); return; }
    }

    if classify(key) == .NONE  return;

    if pressed {
        // already held this key
        if key_is_held && held_key == key then return;

        // the first time press this key
        held_key    = key;
        key_is_held = true;
        held_timer  = 0;

        // handle input immediately for the first time
        eat_game_key(key);
    } else {
        // key release
        if key_is_held && held_key == key {
            key_is_held = false;
            held_timer  = 0;
        }
    }
}

update_player_input_event :: (dt: s64) {
    if !key_is_held return;

    // 窗口失焦等情况可能收不到松开事件
    if !(input_button_states[held_key] & .DOWN) {
        key_is_held = false;
        return;
    }

    held_timer += dt;

    if held_timer >= MOVE_REPEAT_INTERVAL {
        held_timer -= MOVE_REPEAT_INTERVAL;
        eat_game_key(held_key);
    }
}

release_player_keys :: () {
    key_is_held = false;
    held_timer  = 0;
}
