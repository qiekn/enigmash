// 翻转波的显示平滑（只影响画面，不影响逻辑）。
//
// 原版的翻转波前 15 个 tick 每 tick 扩一圈，第 16 个 tick 用 swap15 把区域剩下的部分一次翻完（ps:2095-2100），
// 大区域上看起来就是「扩一小片然后突变」。逻辑保持和原版逐 tick 一致，这里只推迟画面：
//
//   某一帧有一批格子同时换了世界，就以「刚翻过的格子」为起点在这批格子里做 BFS，
//   距离 d 的格子晚 d * SWAP_WAVE_RING_MS 才显示新世界，在那之前继续画旧世界。
//
// 逐圈扩散的那 tick，新的一圈都紧挨着上一圈，d 全是 0，照常显示。
// 撤销 / 重开 / 读档（Session.jumps 变了）不做过渡，直接同步。

wave_fx_update :: (s: *Session, dt_ms: float) {
    using fx;
    n := s.state.cells.count;
    if session != s || jumps != s.jumps || last_num.count != n {
        wave_fx_reset(s);
        return;
    }

    any_pending = false;
    for i: 0..n-1 {
        if pending_ms[i] > 0 {
            pending_ms[i] -= dt_ms;
            if pending_ms[i] > 0  any_pending = true;
        }
        if since_ms[i] < RECENT_MS  since_ms[i] += dt_ms;
    }

    // 这一帧换了世界的格子
    changed: [..] s32;
    changed.allocator = temp;
    cells := s.state.cells;
    for i: 0..n-1 {
        c := *cells[i];
        if c.num == last_num[i] && c.hide == last_hide[i]  continue;
        // 已经在等待中的格子保留更早的旧世界
        if pending_ms[i] <= 0 {
            old_num[i]  = last_num[i];
            old_hide[i] = last_hide[i];
        }
        last_num[i]  = c.num;
        last_hide[i] = c.hide;
        array_add(*changed, cast(s32) i);
    }
    if !changed.count  return;

    // BFS：起点 = 这批格子里挨着「刚翻过的格子」的那些
    h := s.level.h;
    w := s.level.w;
    dist := NewArray(n, s32,, temp);
    for * dist  it.* = -1;
    in_batch := NewArray(n, bool,, temp);
    for changed  in_batch[it] = true;

    queue: [..] s32;
    queue.allocator = temp;
    for i: changed {
        x := i / h;
        y := i % h;
        for d: DIRS4 {
            dx, dy := dir_delta(d);
            nx, ny := x + dx, y + dy;
            if nx < 0 || ny < 0 || nx >= w || ny >= h  continue;
            j := nx * h + ny;
            if !in_batch[j] && since_ms[j] < RECENT_MS {
                dist[i] = 0;
                array_add(*queue, i);
                break;
            }
        }
    }

    head := 0;
    while head < queue.count {
        i := queue[head];
        head += 1;
        x := i / h;
        y := i % h;
        for d: DIRS4 {
            dx, dy := dir_delta(d);
            nx, ny := x + dx, y + dy;
            if nx < 0 || ny < 0 || nx >= w || ny >= h  continue;
            j := nx * h + ny;
            if in_batch[j] && dist[j] < 0 {
                dist[j] = dist[i] + 1;
                array_add(*queue, j);
            }
        }
    }

    for i: changed {
        since_ms[i] = 0;
        d := dist[i];
        if d > 0 {
            pending_ms[i] = d * SWAP_WAVE_RING_MS;
            any_pending = true;
        } else {
            pending_ms[i] = 0;     // 起点、以及和起点不连通的格子（例如整块同时翻的第一个 tick）直接显示
        }
    }
}

// 要画的状态：有格子还在等待时，返回一份把这些格子换回旧世界的拷贝
wave_fx_display_state :: (s: *Session) -> *Game_State {
    using fx;
    if session != s || jumps != s.jumps || !any_pending || last_num.count != s.state.cells.count  return *s.state;

    n := s.state.cells.count;
    if display.cells.count != n {
        array_free(display.cells);
        display.cells = NewArray(n, Cell);
    }
    memcpy(display.cells.data, s.state.cells.data, n * size_of(Cell));
    display.travel = s.state.travel;
    display.open   = s.state.open;
    for i: 0..n-1 {
        if pending_ms[i] > 0 {
            display.cells[i].num  = old_num[i];
            display.cells[i].hide = old_hide[i];
        }
    }
    return *display;
}

// 还有格子在等待显示新世界
wave_fx_busy :: () -> bool { return fx.any_pending; }

#scope_file

RECENT_MS :: 1000.0;   // 多久以内翻过的格子算「刚翻过」（BFS 起点的判定）

Wave_FX :: struct {
    session     : *Session;
    jumps       : int;
    last_num    : [] World;     // 上一帧看到的逻辑世界
    last_hide   : [] World;
    old_num     : [] World;     // 等待中的格子要画的旧世界
    old_hide    : [] World;
    pending_ms  : [] float;     // > 0：还要等多久才显示新世界
    since_ms    : [] float;     // 距这一格上次换世界过了多久（封顶 RECENT_MS）
    any_pending : bool;
    display     : Game_State;
}

fx : Wave_FX;

wave_fx_reset :: (s: *Session) {
    using fx;
    n := s.state.cells.count;
    if last_num.count != n {
        for a: (*[] World).[*last_num, *last_hide, *old_num, *old_hide] {
            array_free(a.*);
            a.* = NewArray(n, World);
        }
        array_free(pending_ms);  pending_ms = NewArray(n, float);
        array_free(since_ms);    since_ms   = NewArray(n, float);
    }
    for i: 0..n-1 {
        last_num[i]   = s.state.cells[i].num;
        last_hide[i]  = s.state.cells[i].hide;
        pending_ms[i] = 0;
        since_ms[i]   = RECENT_MS;
    }
    session     = s;
    jumps       = s.jumps;
    any_pending = false;
}
