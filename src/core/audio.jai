Audio_Clip :: Sound.Sound_Data;
Audio_Category :: Sound.Sound_Category;

init_audio :: () {
    success := Sound.sound_player_init(.{});
    assert(success);
}
update_audio :: () { Sound.update(); }
shutdown_audio :: () { Sound.sound_player_shutdown(); }

load_sound :: (name: string, optional := false) -> Audio_Clip, bool {
    bytes, ok := data_file_string(name, optional);
    if !ok {
        if optional  return .{}, false;
        exit(1);
    }
    data := Sound.load_audio_data(name, bytes);
    if !data.loaded  exit(1);
    return data, true;
}

play_sound :: (data: *Audio_Clip, perturb := false, category := Audio_Category.GENERAL_SFX, repeat := false) {
    stream := Sound.make_stream(data, category);
    if perturb {
        stream.user_volume_scale = random_get_within_range(0.5, 1);
        stream.rate_scale = random_get_within_range(0.75, 1.22);
    }
    Sound.set_repeating(stream, repeat);
    Sound.start_playing(stream);
}

stop_sound :: (data: *Audio_Clip) { Sound.stop_stream_abruptly(data); }

#scope_file
Sound :: #import "Sound_Player";
