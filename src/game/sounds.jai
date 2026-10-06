// SFX
push_box       :  Audio_Clip;
push_ball      :  Audio_Clip;
push_rock      :  Audio_Clip;
rock_drop      :  Audio_Clip;
snake_move     :  Audio_Clip;
world_mutation :  Audio_Clip;

music : Audio_Clip;
music_available := false;   // data/sounds/bgm.ogg 是可选的；没有就不放背景音乐

started_bgm := false;

init_sounds :: () {
    push_box       = load_sound(tprint("%/push_box.wav", SOUND_FOLDER));
    push_ball      = load_sound(tprint("%/push_ball.wav", SOUND_FOLDER));
    push_rock      = load_sound(tprint("%/push_rock.wav", SOUND_FOLDER));
    rock_drop      = load_sound(tprint("%/rock_drop.wav", SOUND_FOLDER));
    snake_move     = load_sound(tprint("%/snake_move.wav", SOUND_FOLDER));
    world_mutation = load_sound(tprint("%/world_mutation.wav", SOUND_FOLDER));
    music, music_available = load_sound(tprint("%/bgm.ogg", SOUND_FOLDER), optional = true);
}

play_music :: () {
    if started_bgm || !music_available  return; // Current, there is only one bgm

    play_sound(*music, category = .MUSIC, repeat = true);
    started_bgm = true;

}

music_enabled := false;

set_music_enabled :: (enabled: bool) {
    music_enabled = enabled;
    if enabled {
        play_music();
    } else if started_bgm {
        stop_sound(*music);
        started_bgm = false;
    }
}

// 保留每个 tick 的顺序和重复音效；每帧在规则更新后消费。
play_session_sounds :: (s: *Session) {
    for s.sound_commands  play_tick_sounds(it);
    array_reset(*s.sound_commands);
}

#scope_file

play_tick_sounds :: (c: Cmd) {
    if c & .SFX0  play_sound(*push_box);
    if c & .SFX1  play_sound(*push_box);    // 原版世界 2 跳 / 爬的音效没有素材，按审阅决定用推箱子音效代替
    if c & .SFX2  play_sound(*rock_drop);
    if c & .SFX3  play_sound(*push_rock);
    if c & .SFX4  play_sound(*push_ball);   // 原版 SFX4 与 SFX5 是同一个种子
    if c & .SFX5  play_sound(*push_ball);
    if c & .SFX6  play_sound(*snake_move);
    if c & .SFX7  play_sound(*world_mutation);
}
