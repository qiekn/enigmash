// 世界渲染：原版 late 段的装饰规则（ps:2237-2396）改为绘制时现算，按原版碰撞层顺序叠画。
//
// 每格收集若干 (层, 精灵)，按层号从小到大画。层号 = 原脚本 COLLISIONLAYERS 的行序（从 1 数起）。
// 精灵来自 tools/gen_atlas.jai 生成的图集，枚举名 = 原版对象名（小写，数字开头的加 n）。

// 当前要画的关卡 / 状态（游戏和编辑器共用这套渲染）
rv_level : *Level;
rv_state : *Game_State;

Draw_Item :: struct { layer: u8; sprite: Sprite; }

Cell_Draw :: struct {
    items : [24] Draw_Item;
    count : int;
}

put :: (d: *Cell_Draw, layer: u8, s: Sprite) {
    // 同层只保留最后一个（原版同层对象互斥）
    for i: 0..d.count-1  if d.items[i].layer == layer { d.items[i].sprite = s; return; }
    if d.count >= d.items.count  return;
    d.items[d.count] = .{layer, s};
    d.count += 1;
}

remove_layer :: (d: *Cell_Draw, layer: u8) {
    for i: 0..d.count-1 {
        if d.items[i].layer == layer {
            d.items[i] = d.items[d.count - 1];
            d.count -= 1;
            return;
        }
    }
}

// ---------------------------------------------------------------------------- 访问（越界返回 null）

rcell :: (x: s32, y: s32) -> *Cell {
    if x < 0 || y < 0 || x >= rv_level.w || y >= rv_level.h  return null;
    return *rv_state.cells[x * rv_level.h + y];
}

r_has :: (c: *Cell, o: Obj) -> bool { return c && (c.obj & o) == o; }
r_any :: (c: *Cell, o: Obj) -> bool { return c && (c.obj & o) != 0; }
r_w   :: (c: *Cell) -> World { return ifx c then c.num else .NONE; }

r_wallfour :: (x: s32, y: s32) -> bool {
    c := rcell(x, y);
    if !r_has(c, .WALL) || c.num != .FOUR  return false;
    for d: DIRS4 {
        dx, dy := dir_delta(d);
        n := rcell(x + dx, y + dy);
        if n && !(n.obj & .WALL) && n.num == .FOUR  return true;
    }
    return false;
}

// 世界 6 的墙：某一侧没有墙就描边（原版 trimu/trimd/…）
r_trim :: (x: s32, y: s32, d: Dir) -> bool {
    c := rcell(x, y);
    if !r_has(c, .WALL) || c.num != .SIX  return false;
    dx, dy := dir_delta(d);
    n := rcell(x + dx, y + dy);
    return n && !(n.obj & .WALL);
}

// 世界 3：某一侧是开放的水面边（原版 u3/d3/l3/r3）
r_open3 :: (x: s32, y: s32, d: Dir) -> bool {
    dx, dy := dir_delta(d);
    n := rcell(x + dx, y + dy);
    return n && !(n.obj & (.WALL | .SUNK));
}

// 蛇身自身的连接件（来自蛇标记）
r_own_five :: (c: *Cell, d: Dir) -> bool {
    if !c || c.num != .FIVE  return false;
    return (c.obj & m5_of(d)) != 0;
}

// 世界 5 一格的连接件（ps:2325-2338），bit 顺序同 DIRS4：1 上，2 下，4 左，8 右
// = 自身的蛇标记 + 相邻格指向自己的标记（反向补一半）+ efive
five_bits :: (x: s32, y: s32) -> u8 {
    c := rcell(x, y);
    if !c || c.num != .FIVE  return 0;
    bits: u8;
    for dir, k: DIRS4 {
        dx, dy := dir_delta(dir);
        n := rcell(x + dx, y + dy);
        if r_own_five(c, dir) || r_own_five(n, opposite(dir))  bits |= cast(u8)(1 << k);
    }
    if c.obj & .E5U  bits |= 1;
    if c.obj & .E5D  bits |= 2;
    if c.obj & .E5L  bits |= 4;
    if c.obj & .E5R  bits |= 8;
    return bits;
}

// DIRS4 下标 k 的反方向下标
opposite_bit :: (k: int) -> int {
    if k == {
        case 0; return 1;
        case 1; return 0;
        case 2; return 3;
    }
    return 2;
}

WORLD_BG     :: Sprite.[.backgroundone, .backgroundtwo, .backgroundthree, .backgroundfour, .backgroundfive, .backgroundsix];
WORLD_TOGGLE :: Sprite.[.toggleone, .toggletwo, .togglethree, .togglefour, .togglefive, .togglesix];

LETTER_SPRITES :: struct { c: u8; s: Sprite; }.[
    .{#char "A", .lettera}, .{#char "C", .letterc}, .{#char "E", .lettere}, .{#char "F", .letterf},
    .{#char "G", .letterg}, .{#char "H", .letterh}, .{#char "I", .letteri}, .{#char "K", .letterk},
    .{#char "L", .letterl}, .{#char "N", .lettern}, .{#char "O", .lettero}, .{#char "P", .letterp},
    .{#char "R", .letterr}, .{#char "S", .letters}, .{#char "T", .lettert}, .{#char "t", .littlert},
    .{#char "U", .letteru}, .{#char "X", .letterx}, .{#char "Y", .lettery}, .{#char "!", .letter},
];

// ---------------------------------------------------------------------------- 一格的全部精灵

collect_cell :: (x: s32, y: s32, d: *Cell_Draw) {
    d.count = 0;
    c := rcell(x, y);
    if !c  return;
    wd := c.num;
    in_world := wd >= .ONE && wd <= .SIX;
    wi := cast(int) wd - 1;

    up    := rcell(x, y - 1);
    down  := rcell(x, y + 1);
    left  := rcell(x - 1, y);
    right := rcell(x + 1, y);

    // ---- 世界背景（整格，会盖住下面的基础对象）
    if in_world {
        put(d, 16, WORLD_BG[wi]);
    } else {
        put(d, 1, .background);
        if c.obj & .PLAYER   put(d, 5, .p);
        if c.obj & .WALL     put(d, 6, .wall);
        if c.obj & .THING    put(d, 7, .thing);
        if c.obj & .TOGGLE   put(d, 9, .toggle);
        if c.obj & .STOP_D   put(d, 10, .stopdown);
        if c.obj & .STOP_L   put(d, 11, .stopleft);
        if c.obj & .STOP_U   put(d, 12, .stopup);
        if c.obj & .STOP_R   put(d, 13, .stopright);
        if c.obj & .SEVENWALL put(d, 14, .sevenwall);
    }

    letter := rv_level.letters[x * rv_level.h + y];
    if letter  for LETTER_SPRITES  if it.c == letter  put(d, 15, it.s);

    wall  := (c.obj & .WALL)  != 0;
    thing := (c.obj & .THING) != 0;

    // ---- 墙（ps:2254, 2262, 2283-2284, 2305-2306, 2319, 2356）
    if wall && in_world {
        if wd == {
            case .ONE;   put(d, 17, .wallone);
            case .TWO;   put(d, 17, .walltwo);
            case .THREE; put(d, 17, .wallthree);
            case .FOUR;  put(d, 17, ifx r_wallfour(x, y) then Sprite.wallfour else .wallfour2);
            case .FIVE;  put(d, 17, .wallfive);
            case .SIX;   put(d, 17, .wallsix);
        }
    }
    if (c.obj & .SUNK) && wd == .THREE  put(d, 17, .sunkthree);

    // ---- 世界 6 墙描边（ps:2368-2375）
    if wall && wd == .SIX {
        if r_trim(x, y, .UP)     put(d, 18, .trimu);
        if r_trim(x, y, .DOWN)   put(d, 19, .trimd);
        if r_trim(x, y, .RIGHT)  put(d, 20, .trimr);
        if r_trim(x, y, .LEFT)   put(d, 21, .triml);
        if r_trim(x + 1, y, .UP)    put(d, 23, .trimur);
        if r_trim(x + 1, y, .DOWN)  put(d, 24, .trimdr);
        if r_trim(x - 1, y, .UP)    put(d, 22, .trimul);
        if r_trim(x - 1, y, .DOWN)  put(d, 25, .trimdl);
    }

    // ---- 世界 3 水面圆角（ps:2289-2300）
    if wd == .THREE {
        u3 := r_open3(x, y, .UP);    d3 := r_open3(x, y, .DOWN);
        l3 := r_open3(x, y, .LEFT);  r3 := r_open3(x, y, .RIGHT);
        if wall {
            if u3 && l3  put(d, 22, .n3uly);
            if u3 && r3  put(d, 23, .n3ury);
            if d3 && l3  put(d, 25, .n3dly);
            if d3 && r3  put(d, 24, .n3dry);
        } else if !(c.obj & .SUNK) {
            if !u3 && !l3  put(d, 22, .n3ulb);
            if !u3 && !r3  put(d, 23, .n3urb);
            if !d3 && !l3  put(d, 25, .n3dlb);
            if !d3 && !r3  put(d, 24, .n3drb);
        }
    }

    // ---- 开关
    if (c.obj & .TOGGLE) && in_world  put(d, 26, WORLD_TOGGLE[wi]);

    // ---- 玩家（ps:2257, 2269-2276, 2286, 2310-2311, 2358-2361）
    if c.obj & .PLAYER {
        if wd == {
            case .ONE;   put(d, 29, .playerone);
            case .TWO;
                if c.obj & .WENT_L {
                    put(d, 29, .playertwoleft);
                    if c.obj & .CLIMB1  put(d, 29, .playerl1);
                    if c.obj & .CLIMB2  put(d, 29, .playerl2);
                }
                if c.obj & .WENT_R {
                    put(d, 29, .playertworight);
                    if c.obj & .CLIMB1  put(d, 29, .playerr1);
                    if c.obj & .CLIMB2  put(d, 29, .playerr2);
                }
            case .THREE; put(d, 29, .playerthree);
            case .FOUR;
                if c.obj & .WENT_L  put(d, 29, .playerfourleft);
                if c.obj & .WENT_R  put(d, 29, .playerfourright);
            case .SIX;
                if c.obj & .M6U  put(d, 29, .playersix1);
                if c.obj & .M6D  put(d, 29, .playersix2);
                if c.obj & .M6L  put(d, 29, .playersix3);
                if c.obj & .M6R  put(d, 29, .playersix4);
        }
        // 还没有朝向 / 重力标记（编辑器刚放的玩家、还没动过）：给个默认朝向，别画成隐形
        if wd == .TWO  && !(c.obj & (.WENT_L | .WENT_R))                put(d, 29, .playertworight);
        if wd == .FOUR && !(c.obj & (.WENT_L | .WENT_R))                put(d, 29, .playerfourright);
        if wd == .SIX  && !(c.obj & (.M6U | .M6D | .M6L | .M6R))        put(d, 29, .playersix2);
    }

    // 世界 2 攀爬的中间帧画在旁边的格子上（ps:2272-2278）
    climbing :: (c: *Cell, went: Obj) -> bool {
        return c && (c.obj & (.PLAYER | .CLIMB1 | went)) == (.PLAYER | .CLIMB1 | went) && c.num == .TWO;
    }
    if climbing(left, .WENT_L)                       put(d, 29, .playerl1a);
    if climbing(rcell(x - 1, y - 1), .WENT_L)        put(d, 29, .playerl1b);
    if climbing(right, .WENT_R)                      put(d, 29, .playerr1a);
    if climbing(rcell(x + 1, y - 1), .WENT_R)        put(d, 29, .playerr1b);

    // ---- 箱子（ps:2255, 2267, 2285, 2308, 2323-2324, 2357）
    if thing && in_world {
        if wd == {
            case .ONE;   put(d, 32, .thingone);
            case .TWO;   put(d, 32, .thingtwo);
            case .THREE; put(d, 32, .thingthree);
            case .FOUR;  put(d, 32, .thingfour);
            case .FIVE;  put(d, 32, ifx c.obj & MARK5 then Sprite.thingfive2 else .thingfive);
            case .SIX;   put(d, 32, .thingsix);
        }
    }

    // ---- 世界 2 墙边缘（ps:2263-2266）
    if wall && wd == .TWO {
        if !(c.obj & .STOP_U) && up && !(up.obj & (.WALL | .STOP_D))  put(d, 36, .walltwoup);
        if down && !(down.obj & .WALL) {
            put(d, 33, .walltwodown);
            if left  && !(left.obj  & .WALL)  put(d, 34, .walltwoleft);
            if right && !(right.obj & .WALL)  put(d, 35, .walltworight);
        }
    }

    // ---- 墙上的箱子
    if wall && thing {
        if wd == .ONE  put(d, 37, .wallthingone);
        if wd == .TWO  put(d, 37, .wallthingtwo);
        if wd == .FOUR && r_wallfour(x, y)  put(d, 37, .wallthingfour);
    }

    // ---- 世界 4 高墙顶沿，画在墙上方那一格（ps:2307）
    if wd == .FOUR && down && (down.obj & .WALL) && down.num == .FOUR && !r_wallfour(x, y + 1)  put(d, 38, .wallfour2down);

    // ---- 边界线（ps:2380-2396）
    if wd != .SEVEN {
        if (c.obj & .STOP_U) && up   && up.num   != .SEVEN  put(d, 54, .barrierup2);
        if (c.obj & .STOP_L) && left && left.num != .SEVEN  put(d, 56, .barrierleft2);
        if in_world {
            if up   && up.num   != wd  put(d, 54, .barrierup);
            if left && left.num != wd  put(d, 56, .barrierleft);
        }
        if down  && down.num  >= .ONE && down.num  <= .SIX && down.num  != wd  put(d, 55, .barrierdown);
        if right && right.num >= .ONE && right.num <= .SIX && right.num != wd  put(d, 57, .barrierright);
    }

    // ---- 连接件：世界 6 的箱子连接（逻辑对象本身）、世界 3 的筏、世界 5 的蛇身
    if c.obj & .LU  put(d, 59, .ulink);
    if c.obj & .LD  put(d, 60, .dlink);
    if c.obj & .LR  put(d, 61, .rlink);
    if c.obj & .LL  put(d, 62, .llink);

    if wd == .THREE && thing {
        three_thing :: (n: *Cell) -> bool { return n && n.num == .THREE && (n.obj & .THING); }
        if three_thing(up)     put(d, 59, .ulink3);
        if three_thing(down)   put(d, 60, .dlink3);
        if three_thing(right)  put(d, 61, .rlink3);
        if three_thing(left)   put(d, 62, .llink3);
    }

    if wd == .FIVE {
        bits := five_bits(x, y);

        // ps:2345-2348  late up [p fiveup | fivedown no thing] -> [p |]  …
        // 蛇头和它相邻的空格之间的连接件两边都不画
        for dir, k: DIRS4 {
            if !(bits & (1 << k))  continue;
            dx, dy := dir_delta(dir);
            n := rcell(x + dx, y + dy);
            if !n  continue;
            back := cast(u8)(1 << opposite_bit(k));
            nbits := five_bits(x + dx, y + dy);
            if (c.obj & .PLAYER) && (nbits & back) && !(n.obj & .THING)  bits &= ~cast(u8)(1 << k);
            if (n.obj & .PLAYER) && (nbits & back) && !thing             bits &= ~cast(u8)(1 << k);
        }

        if bits & 1  put(d, 59, .fiveup);
        if bits & 2  put(d, 60, .fivedown);
        if bits & 4  put(d, 62, .fiveleft);
        if bits & 8  put(d, 61, .fiveright);

        // 蛇头（ps:2340-2344）
        if c.obj & .PLAYER {
            s := Sprite.playerfiveu;
            if c.obj & .M5U  s = .playerfived;
            if c.obj & .M5D  s = .playerfiveu;
            if c.obj & .M5L  s = .playerfiver;
            if c.obj & .M5R  s = .playerfivel;
            put(d, 63, s);
        }
    }

    // ---- 腿（ps:2364-2367）
    if c.obj & .LEGS {
        for dir: DIRS4 {
            dx, dy := dir_delta(dir);
            n := rcell(x + dx, y + dy);
            if !n || !(n.obj & .PLAYER) || n.num != .SIX  continue;
            if n.obj & .M6U  put(d, 64, .legs1);
            if n.obj & .M6D  put(d, 64, .legs2);
            if n.obj & .M6L  put(d, 64, .legs3);
            if n.obj & .M6R  put(d, 64, .legs4);
        }
    }

    // ---- 隧道端点（已激活的才画）
    for t, ti: rv_level.tunnels  for e, ei: t.ends {
        if e.pos.x != x || e.pos.y != y  continue;
        if !(rv_state.open & tunnel_open_bit(ti, ei))  continue;
        s := Sprite.awarpa;
        if e.style == #char "b"  s = .awarpb;
        if e.style == #char "c"  s = .awarpc;
        if e.style == #char "d"  s = .awarpd;
        put(d, 64, s);
    }

    // ---- 彩蛋
    if c.obj & .SECRET  put(d, 77, .messag);

    // 按层排序（插入排序，每格最多十几个）
    for i: 1..d.count-1 {
        item := d.items[i];
        j := i - 1;
        while j >= 0 && d.items[j].layer > item.layer {
            d.items[j + 1] = d.items[j];
            j -= 1;
        }
        d.items[j + 1] = item;
    }
}

// ---------------------------------------------------------------------------- 绘制

// 把关卡画出来。可见范围来自当前镜头；逻辑行 row 在屏幕上是 world y = h-1-row
draw_level :: (level: *Level, state: *Game_State) {
    rv_level = level;
    rv_state = state;

    vx0, vy0, vx1, vy1 := camera_visible_grid();
    x0 := max(vx0, 0);
    x1 := min(vx1, level.w - 1);
    wy0 := max(vy0, 0);
    wy1 := min(vy1, level.h - 1);
    if x0 > x1 || wy0 > wy1  return;

    // 缩小看全图时一帧上万个精灵：tile 尺寸 / 原点只算一次，shader 只设一次，直接出 quad
    ts := camera_tile_px();
    o  := camera_origin();
    Simp.set_shader_for_images(*the_sprite);

    d: Cell_Draw;
    for x: x0..x1 {
        sx0 := x * ts + o.x;
        sx1 := sx0 + ts;
        for wy: wy0..wy1 {
            row := cast(s32)(level.h - 1 - wy);
            collect_cell(cast(s32) x, row, *d);
            if !d.count  continue;

            sy0 := wy * ts + o.y;
            sy1 := sy0 + ts;
            for i: 0..d.count-1 {
                u0, v0, u1, v1 := sprite_uv(d.items[i].sprite);
                Simp.immediate_quad(.{sx0, sy0}, .{sx1, sy0}, .{sx1, sy1}, .{sx0, sy1}, WHITE, .{u0, v0}, .{u1, v0}, .{u1, v1}, .{u0, v1});
            }
        }
    }
}

// 逻辑格子 -> 渲染世界坐标（y 朝上）
grid_to_world :: (level: *Level, p: Pos) -> Vector2 {
    return .{cast(float) p.x, cast(float)(level.h - 1 - p.y)};
}

world_to_grid :: (level: *Level, wx: int, wy: int) -> Pos {
    return .{cast(s32) wx, cast(s32)(level.h - 1 - wy)};
}
