// Reversible cell deltas at settled input boundaries, including checkpoints.
Tas_Cell_Change :: struct { index: int; before, after: Cell; }
Tas_Cached_Turn :: struct {
    cells, restart_cells: [..] Tas_Cell_Change;
    travel, restart_travel: Travel;
    open, restart_open: u32;
    message: string;
    againing, won: bool;
}
Tas_Cache :: struct {
    turns: [..] Tas_Cached_Turn;
    state, restart: Game_State;
    position: int;
}

tas_cache_trim :: (t: *Tas, last: int) {
    while t.cache.turns.count > last + 1 {
        turn := pop(*t.cache.turns);
        array_free(turn.cells);
        array_free(turn.restart_cells);
        free(turn.message);
    }
}

tas_cache_free :: (t: *Tas) {
    tas_cache_trim(t, -1);
    array_free(t.cache.turns);
    state_free(*t.cache.state);
    state_free(*t.cache.restart);
    t.cache = .{};
}

tas_cache_diff :: (before: Game_State, after: Game_State) -> [..] Tas_Cell_Change {
    result: [..] Tas_Cell_Change;
    for c, i: after.cells {
        if memcmp(*before.cells[i], *c, size_of(Cell)) != 0
            array_add(*result, .{i, before.cells[i], c});
    }
    return result;
}

tas_cache_move :: (t: *Tas, target: int) {
    c := *t.cache;
    while c.position > target {
        turn := *c.turns[c.position];
        for turn.cells c.state.cells[it.index] = it.before;
        for turn.restart_cells c.restart.cells[it.index] = it.before;
        c.position -= 1;
    }
    while c.position < target {
        c.position += 1;
        turn := *c.turns[c.position];
        for turn.cells c.state.cells[it.index] = it.after;
        for turn.restart_cells c.restart.cells[it.index] = it.after;
    }
    turn := *c.turns[target];
    c.state.travel = turn.travel;
    c.state.open = turn.open;
    c.restart.travel = turn.restart_travel;
    c.restart.open = turn.restart_open;
}

tas_cache_capture :: (t: *Tas) {
    s := *t.session;
    if s.againing && !s.message && !s.won return;
    c := *t.cache;
    if c.turns.count {
        if t.playhead < c.turns.count { tas_cache_move(t, t.playhead); return; }
        assert(t.playhead == c.turns.count && c.position == t.playhead - 1);
    } else assert(t.playhead == 0);
    turn: Tas_Cached_Turn;
    if c.turns.count {
        turn.cells = tas_cache_diff(c.state, s.state);
        turn.restart_cells = tas_cache_diff(c.restart, s.restart_target);
    }
    turn.travel = s.state.travel;
    turn.open = s.state.open;
    turn.restart_travel = s.restart_target.travel;
    turn.restart_open = s.restart_target.open;
    turn.message = copy_string(s.message);
    turn.againing = s.againing;
    turn.won = s.won;
    array_add(*c.turns, turn);
    state_copy(*c.state, s.state);
    state_copy(*c.restart, s.restart_target);
    c.position = t.playhead;
}

tas_cache_restore :: (t: *Tas, target: int) {
    tas_cache_move(t, target);
    s := *t.session;
    session_clear(s);
    state_copy(*s.state, t.cache.state);
    state_copy(*s.restart_target, t.cache.restart);
    turn := *t.cache.turns[target];
    s.message = turn.message;
    s.againing = turn.againing;
    s.won = turn.won;
    s.no_save = true;
    s.no_undo = true;
    s.inputs_since_save = 0;
    t.playhead = target;
    t.caret = target;
    t.anchor = target;
    session_bind(s);
}

#scope_file
#import "Basic";
#import "String";
