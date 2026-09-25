// SFX
push_box       :  Sound_Data;
push_ball      :  Sound_Data;
push_rock      :  Sound_Data;
rock_drop      :  Sound_Data;
snake_move     :  Sound_Data;
world_mutation :  Sound_Data;

music : Sound_Data;
music_available := false;   // data/sounds/bgm.ogg 是可选的；没有就不放背景音乐

started_bgm := false;

init_sounds :: () {
    load_sound :: (basename: string, extension := "wav", optional := false) -> Sound_Data, bool {
        name := tprint("%/%.%", SOUND_FOLDER, basename, extension);
        bytes, ok := data_file_string(name, optional);
        if !ok {
            if optional  return .{}, false;
            exit(1);
        }

        data := load_audio_data(name, bytes);
        if !data.loaded exit(1);

        return data, true;
    }

    push_box       = load_sound("push_box");
    push_ball      = load_sound("push_ball");
    push_rock      = load_sound("push_rock");
    rock_drop      = load_sound("rock_drop");
    snake_move     = load_sound("snake_move");
    world_mutation = load_sound("world_mutation");

    music, music_available = load_sound("bgm", "ogg", optional = true);

    success := sound_player_init(.{});
    assert(success);
}

shutdown_sounds :: () {
    sound_player_shutdown();

    // @TODO free all Sound_Data
}

play_sound :: (data: *Sound_Data, perturb: bool = false, category := Sound_Category.GENERAL_SFX) {
    stream := Sound.make_stream(data, category);

    if perturb {
        stream.user_volume_scale = random_get_within_range(0.5,  1);
        stream.rate_scale        = random_get_within_range(0.75, 1.22);
    }

    Sound.start_playing(stream);
}

play_music :: () {
    if started_bgm || !music_available  return; // Current, there is only one bgm

    stream := make_stream(*music, .MUSIC);
    set_repeating(stream, true);
    start_playing(stream);
    started_bgm = true;

}

music_enabled := false;   // 默认不开背景音乐，菜单 Options 里可以打开

set_music_enabled :: (enabled: bool) {
    music_enabled = enabled;
    if enabled {
        play_music();
    } else if started_bgm {
        stop_stream_abruptly(*music);
        started_bgm = false;
    }
}
