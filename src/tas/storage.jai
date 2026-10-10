// A TAS file contains a starting snapshot and a readable WASD script. It is tied
// to the current level; loading never changes a campaign or runs a start tick.
TAS_MAGIC :: "ENGTAS01";

tas_fingerprint :: (l: *Level) -> u64 {
    h := level_hash(l);
    mix :: (h: *u64, text: string) {
        for text { h.* ^= it; h.* *= 1099511628211; }
        h.* ^= 255; h.* *= 1099511628211;
    }
    mix(*h, tprint("% % % %", l.w, l.h, size_of(Cell), size_of(Travel)));
    for l.tunnels for e: it.ends mix(*h, tprint("% % % %", e.pos.x, e.pos.y, e.start_open, e.message));
    for l.messages { mix(*h, it.id); mix(*h, it.text); }
    return h;
}

tas_encode :: (t: *Tas) -> string {
    b: String_Builder;
    defer free_buffers(*b);
    append(*b, TAS_MAGIC);
    put :: (b: *String_Builder, value: $T) { append(b, cast(*u8) *value, size_of(T)); }
    put(*b, tas_fingerprint(*t.session.level));
    put(*b, cast(u32) t.keys.count);
    put(*b, cast(u32) t.start.message.count);
    put(*b, cast(u8) t.start.againing);
    put(*b, cast(u8) t.start.won);
    put(*b, t.start.again_ms);
    put(*b, t.delay_ms);
    for st: Game_State.[t.start.state, t.start.restart] {
        append(*b, cast(*u8) st.cells.data, st.cells.count * size_of(Cell));
        put(*b, st.travel);
        put(*b, st.open);
    }
    append(*b, t.start.message);
    append(*b, string.{t.keys.count, t.keys.data});
    return builder_to_string(*b);
}

tas_decode :: (t: *Tas, data: string) -> string {
    cursor := data;
    valid := true;
    take :: (n: int) -> string #expand {
        if n < 0 || n > cursor.count { valid = false; return ""; }
        result := slice(cursor, 0, n);
        advance(*cursor, n);
        return result;
    }
    get :: ($T: Type) -> T #expand {
        bytes := take(size_of(T));
        value: T;
        if bytes.count == size_of(T) memcpy(*value, bytes.data, size_of(T));
        return value;
    }
    if take(TAS_MAGIC.count) != TAS_MAGIC return "Not an Enigmash TAS file (version 1).";
    hash := get(u64);
    if hash != tas_fingerprint(*t.session.level) return "This recording belongs to a different level/version.";
    count := get(u32);
    message_size := get(u32);
    againing := get(u8);
    won := get(u8);
    again_ms := get(float);
    delay := get(float);
    if !valid || count > TAS_KEY_LIMIT || message_size > 1048576 || againing > 1 || won > 1 ||
       !(again_ms >= 0 && again_ms <= 86400000) || !(delay >= 1 && delay <= 10000) return "Invalid TAS header.";

    next: Tas;
    defer tas_free(*next);
    next.session.level = t.session.level;
    next.delay_ms = delay;
    next.start.againing = againing != 0;
    next.start.won = won != 0;
    next.start.again_ms = again_ms;
    for st: (*Game_State).[*next.start.state, *next.start.restart] {
        n := t.session.level.initial.cells.count;
        bytes := take(n * size_of(Cell));
        if !valid return "Truncated TAS snapshot.";
        state_alloc(st, n);
        memcpy(st.cells.data, bytes.data, bytes.count);
        st.travel = get(Travel);
        st.open = get(u32);
        for st.cells {
            if cast(u8) it.num > 7 || cast(u8) it.hide > 7 return "Invalid world in TAS snapshot.";
        }
        if st.travel.active {
            if st.travel.tunnel < 0 || st.travel.tunnel >= next.session.level.tunnels.count return "Invalid TAS tunnel.";
            if st.travel.step < 0 || st.travel.step >= next.session.level.tunnels[st.travel.tunnel].path.count return "Invalid TAS travel step.";
        }
    }
    next.start.message = copy_string(take(message_size));
    keys := take(count);
    if !valid || cursor.count return "Truncated TAS file or unexpected trailing data.";
    for keys {
        if !tas_key_valid(it) return "Invalid key in TAS file.";
        array_add(*next.keys, it);
    }
    tas_restore(*next);
    tas_free(t);
    t.* = next;
    next = .{};
    session_bind(*t.session);
    return "";
}

#scope_file
#import "Basic";
#import "String";
