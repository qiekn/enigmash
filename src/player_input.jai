#scope_file

key_is_held := false;

held_key : Key_Code;
held_timer : s64; // milliseconds

is_player_move_key :: (key: Key_Code) -> bool {
    return key == #char "W"
        || key == #char "S"
        || key == #char "A"
        || key == #char "D";
}

eat_player_input :: (key: Key_Code) {
    // Handle player move
         if key == #char "W" player_try_move(0, 1);
    else if key == #char "S" player_try_move(0, -1);
    else if key == #char "A" player_try_move(-1, 0);
    else if key == #char "D" player_try_move(1, 0);
    
}

#scope_export

handle_player_input :: (key: Key_Code, pressed: u32) {
    if !is_player_move_key(key) return;

    if pressed {
        // already held this key
        if key_is_held && held_key == key then return;

        // the first time press this key
        held_key     = key;
        key_is_held = true;
        held_timer   = 0;

        // handle move input immediately for the first time
        eat_player_input(key);

    } else {
        // key release
        if key_is_held && held_key == key {
            key_is_held = false;
            held_timer   = 0;
        }
    }
}

update_player_input_event :: (dt: s64) {
    if !key_is_held return;

    held_timer += dt;

    if held_timer >= MOVE_REPEAT_INTERVAL {
        held_timer -= MOVE_REPEAT_INTERVAL;
        eat_player_input(held_key);
    }
}
