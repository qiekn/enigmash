// 普通（非 late）规则，按原脚本 RULES 段的顺序逐条翻译。
// 每条规则前面是原文和行号（ps:行号 = .refs/enigmash_puzzlescript.txt 的行号）。
//
// 写法约定：
//   for pass: stable() ...                        一个规则组，反复执行直到不再改变
//   for scan(d, len) { it = 第一个格子 }     一次按原版顺序的匹配遍历，D = d
//   c1 := nb(it, D)                         pattern 里的下一个格子

rules_normal :: () {
    // ---------------------------------------------------------------- 开场

    // ps:1737  down [2 | 2 down player | 2] -> cancel
    for scan(.DOWN, 3) {
        c1 := nb(it, D);  c2 := nb(c1, D);
        if w(it) == .TWO && has(c1, .CAMERA) && mv(c1, .CAMERA) == .DOWN && w(c1) == .TWO && w(c2) == .TWO  queue(.CANCEL);
    }

    // ps:1738  [o no mark5] -> [o dangthisissohackyblargh]
    for pass: stable() for scan(.DOWN)  if has(it, .THING) && !any(it, MARK5)  add(it, .DANG);

    // ps:1739  [winspawn] -> [winspawn winner]
    for pass: stable() for scan(.DOWN)  if has(it, .WINSPAWN)  add(it, .WINNER);

    // ps:1740  [winner][hideseven] -> [][hideseven]
    if exists((i: s32) -> bool { return hw(i) == .SEVEN; }) {
        for pass: stable() for scan(.DOWN)  if has(it, .WINNER)  del(it, .WINNER);
    }

    // ps:1741  [action player][winner] -> win
    if exists((i: s32) -> bool { return has(i, .CAMERA) && mv(i, .CAMERA) == .ACTION; })
    && exists((i: s32) -> bool { return has(i, .WINNER); }) {
        queue(.WIN);
    }

    // ps:1745  [moving camera][ p] -> [stationary camera][ moving p]
    for pass: stable() for m: MOVING {
        p := first_cell((i: s32) -> bool { return has(i, .PLAYER); });
        if p < 0  continue;
        for scan(.DOWN)  if has(it, .CAMERA) && mv(it, .CAMERA) == m {
            set_mv(it, .CAMERA, .NONE);
            for scan(.DOWN)  if has(it, .PLAYER)  set_mv(it, .P, m);
        }
    }

    // ps:1749  [moving p sevenwall] -> [stationary p sevenwall]
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | .SEVENWALL) && !still(it, .P)  set_mv(it, .P, .NONE);

    // ps:1750-1776  隧道（原版用 awarp/connector/wait 对象实现，这里是等价的显式状态机）
    tunnel_rules();

    // ps:1780  [went no p] -> []
    for pass: stable() for scan(.DOWN)  if any(it, WENT) && !has(it, .PLAYER)  del(it, WENT);

    // ps:1783-1786  global down/left/right/up [num no swap no stopX no swapped | no num no stopY] -> [num | num]
    for pass: stable() {
        flood_world(.DOWN, false);  flood_world(.LEFT, false);
        flood_world(.RIGHT, false); flood_world(.UP, false);
    }
    // ps:1788-1791  同上，隐藏世界
    for pass: stable() {
        flood_world(.DOWN, true);  flood_world(.LEFT, true);
        flood_world(.RIGHT, true); flood_world(.UP, true);
    }

    // ps:1793  [moving p][o exitmark] -> [moving p][exitmark]
    if exists((i: s32) -> bool { return has(i, .PLAYER) && !still(i, .P); }) {
        for pass: stable() for scan(.DOWN)  if has(it, .THING | .EXIT)  del(it, .THING);
    }

    // ps:1795  [> p | o mark5] -> [stationary p | o mark5]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && has(c1, .THING) && any(c1, MARK5)  set_mv(it, .P, .NONE);
    }

    // ---------------------------------------------------------------- 世界 1

    // ps:1799  [> p 1| o no mark5] -> [> p 1| > o]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .ONE && has(c1, .THING) && !any(c1, MARK5)  set_mv(c1, .THING, D);
    }

    // ---------------------------------------------------------------- 世界 2

    rules_world2();

    // ---------------------------------------------------------------- 世界 3

    // ps:1837  [> p 3 | o 2 | x 2] -> [stationary p 3 | o 2 | x 2]
    for pass: stable() for d: DIRS4 for scan(d, 3) {
        c1 := nb(it, D);  c2 := nb(c1, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .THREE
        && has(c1, .THING) && w(c1) == .TWO && has(c2, .WALL) && w(c2) == .TWO  set_mv(it, .P, .NONE);
    }

    // ps:1838  [> p 3 |o no x] -> [> p 3 | > o no x]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .THREE && has(c1, .THING) && !has(c1, .WALL)  set_mv(c1, .THING, D);
    }

    // ps:1839-1840
    world3_raft_group();

    // ---------------------------------------------------------------- 世界 4

    // ps:1843  [> p 4|o ] -> [> p 4|> o]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .FOUR && has(c1, .THING)  set_mv(c1, .THING, D);
    }

    // ps:1845-1848  [o umark4 4] -> [up o 4]  …（四条各自成组）
    for d: DIRS4 {
        mark := m4_of(d);
        for pass: stable() for scan(.DOWN)  if has(it, .THING | mark) && w(it) == .FOUR {
            del(it, mark);
            set_mv(it, .THING, d);
        }
    }

    // ps:1850  [mark4 4] -> [4]
    for pass: stable() for d: DIRS4 {
        mark := m4_of(d);
        for scan(.DOWN)  if has(it, mark) && w(it) == .FOUR  del(it, mark);
    }

    // ps:1852-1855  right/up/left/down [> o |4 no o] -> [> o|4 Xmark4] again
    world4_slide_marks();

    // ps:1857  [> o 4|o] -> [stationary o 4| o]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == D && w(it) == .FOUR && has(c1, .THING)  set_mv(it, .THING, .NONE);
    }

    // ps:1862-1863  三号世界，再来一次
    world3_raft_group();

    // ---------------------------------------------------------------- 世界 6

    rules_world6_moves();

    // ---------------------------------------------------------------- 世界 5

    // ps:1940  [> p 5| o no mark5] -> [> p 5 | > o]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .FIVE && has(c1, .THING) && !any(c1, MARK5)  set_mv(c1, .THING, D);
    }

    // ps:1942-1945  up [up p |5 no x no mark5] -> [up p | dmark5 5 no x]  …
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && mv(it, .P) == D && w(c1) == .FIVE && !has(c1, .WALL) && !any(c1, MARK5)  add(c1, m5_of(opposite(D)));
        }
    }

    // ps:1947  [tailmark][> p 5| no 5 no x] -> [tailmark][exitmark > p 5|]
    if exists((i: s32) -> bool { return has(i, .TAIL); }) {
        for pass: stable() for d: DIRS4 for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .FIVE && w(c1) != .FIVE && !has(c1, .WALL)  add(it, .EXIT);
        }
    }

    // ps:1983-1986  四号世界，再来一次
    world4_slide_marks();

    // ---------------------------------------------------------------- 翻转

    // ps:2015-2033  global [one swap no swapped] -> [onetmp swap] … 交换可见 / 隐藏世界
    for i: 0..sim.cells.count-1 {
        c := *sim.cells[i];
        if c.swap == 0 || (c.obj & .SWAPPED)  continue;
        new_num  := ifx c.hide != .NONE then c.hide else ifx c.num == .SEVEN then World.SEVEN else .NONE;
        new_hide := ifx c.num >= .ONE && c.num <= .SIX then c.num else .NONE;
        c.num  = new_num;
        c.hide = new_hide;
    }

    rules_world5_swap();
    rules_swap_wave();

    // ---------------------------------------------------------------- 阻挡（STOPPING）

    rules_stopping();

    // ---------------------------------------------------------------- 朝向、虚空、消息、镜头、音效

    // ps:2248  [left p] -> [left p left wentleft]
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) && mv(it, .P) == .LEFT   add_moving(it, .WENT_L, .LEFT);
    // ps:2249  [right p] -> [right p right wentright]
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) && mv(it, .P) == .RIGHT  add_moving(it, .WENT_R, .RIGHT);
    // ps:2250-2251  [vertical p wentX] -> [vertical p vertical wentX]
    for went: Obj.[.WENT_L, .WENT_R] {
        for pass: stable() for scan(.DOWN) {
            m := mv(it, .P);
            if has(it, .PLAYER | went) && (m == .UP || m == .DOWN)  set_mv(it, .WENT, m);
        }
    }

    // ps:2400  [moving p seven] -> [stationary p seven]
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) && !still(it, .P) && w(it) == .SEVEN  set_mv(it, .P, .NONE);

    // ps:2411  left [> o | halloweenbowlpleaseonlytakeone] -> [|halloweenbowlpleaseonlytakeone] message >:|
    for pass: stable() for scan(.LEFT, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .LEFT && has(c1, .HALLOWEEN) {
            del(it, .THING);
            queue_message("candy_bowl");
        }
    }
    // ps:2412  left [> o | dontbegreedy] -> [> o | halloweenbowlpleaseonlytakeone]
    for pass: stable() for scan(.LEFT, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .LEFT && has(c1, .GREEDY)  add(c1, .HALLOWEEN);
    }

    // ps:2415  [> p 5 | uhhdont] -> message Uhhhhhhh...
    for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .FIVE && hasm(c1, .UHH)  queue_message("uhh");
    }

    // ps:2417-2420  分支提示。按审阅决定只弹一次：只有 \（branchmessage）还在时才弹，弹完就删掉它
    branch_once := exists((i: s32) -> bool { return hasm(i, .BRANCH_ONCE); });
    for scan(.RIGHT, 2) {
        c1 := nb(it, D);
        if branch_once && has(it, .PLAYER) && mv(it, .P) == .RIGHT && hasm(c1, .BRANCH_L)  queue_message("branch");
    }
    for scan(.LEFT, 2) {
        c1 := nb(it, D);
        if branch_once && has(it, .PLAYER) && mv(it, .P) == .LEFT && hasm(c1, .BRANCH_R)  queue_message("branch");
    }
    if branch_once {
        hit := false;
        for scan(.RIGHT, 2)  if has(it, .PLAYER) && mv(it, .P) == .RIGHT && hasm(nb(it, D), .BRANCH_L)  hit = true;
        for scan(.LEFT, 2)   if has(it, .PLAYER) && mv(it, .P) == .LEFT  && hasm(nb(it, D), .BRANCH_R)  hit = true;
        if hit  for scan(.DOWN)  if hasm(it, .BRANCH_ONCE)  delm(it, .BRANCH_ONCE);
    }

    // ps:2424  [> p 5 | oops] -> message Oops, puzzle design is hard...
    for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .FIVE && has(c1, .OOPS)  queue_message("oops");
    }

    // ps:2426  right [right o| branchmessageleft] -> [right o|] checkpoint
    for pass: stable() for scan(.RIGHT, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .RIGHT && hasm(c1, .BRANCH_L) { delm(c1, .BRANCH_L); queue(.CHECKPOINT); }
    }
    // ps:2427  left [left o| branchmessageright] -> [left o|] checkpoint
    for pass: stable() for scan(.LEFT, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .LEFT && hasm(c1, .BRANCH_R) { delm(c1, .BRANCH_R); queue(.CHECKPOINT); }
    }

    // ps:2432  [camera camerashift][moving p] -> [moving camera moving camerashift][moving p]
    for pass: stable() for m: MOVING {
        player_moving := false;
        for scan(.DOWN)  if has(it, .PLAYER) && mv(it, .P) == m  player_moving = true;
        if !player_moving  continue;
        for scan(.DOWN)  if has(it, .CAMERA | .CAMSHIFT) {
            set_mv(it, .CAMERA, m);
            set_mv(it, .CAMSHIFT, m);
        }
    }

    // ps:2433  [camera camerastick camerashift] -> [camera camerastick]
    for pass: stable() for scan(.DOWN)  if has(it, .CAMERA | .CAMSHIFT) && hasm(it, .CAMSTICK)  del(it, .CAMSHIFT);

    // ps:2435-2438  up [> p 5| no 5] -> [> p 5 efiveup | no 5]  …（蛇头离开世界 5 时的连接件）
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .FIVE && w(c1) != .FIVE  add(it, e5_of(D));
        }
    }

    // ps:2440-2446  音效
    if exists((i: s32) -> bool { return has(i, .THING) && !still(i, .THING) && w(i) == .ONE; })    queue(.SFX0);
    if exists((i: s32) -> bool { return has(i, .PLAYER) && mv(i, .P) == .UP && w(i) == .TWO; })     queue(.SFX1);
    if exists((i: s32) -> bool { return has(i, .PLAYER | .CLIMB1) && w(i) == .TWO; })              queue(.SFX1);
    for scan(.DOWN, 3) {
        c1 := nb(it, D);  c2 := nb(c1, D);
        if has(it, .THING) && mv(it, .THING) == .DOWN && w(it) == .TWO
        && w(c1) == .TWO && !any(c1, .WALL | .THING) && has(c2, .WALL)  queue(.SFX2);
    }
    if exists((i: s32) -> bool { return has(i, .THING) && !still(i, .THING) && w(i) == .THREE; })  queue(.SFX3);
    if exists((i: s32) -> bool { return has(i, .THING) && !still(i, .THING) && w(i) == .FOUR; })   queue(.SFX5);
    if exists((i: s32) -> bool { return has(i, .PLAYER) && !still(i, .P) && w(i) == .FIVE; })      queue(.SFX6);
}

// ----------------------------------------------------------------------------: 泛洪（世界种子）

flood_world :: (d: Dir, hidden: bool) {
    for scan(d, 2, global = true) {
        c1 := nb(it, D);
        a := ifx hidden then hw(it) else w(it);
        b := ifx hidden then hw(c1) else w(c1);
        if a != .NONE && swp(it) == 0 && !has(it, .SWAPPED) && !has(it, stop_of(D))
        && b == .NONE && !has(c1, stop_of(opposite(D))) {
            if hidden  set_hide(c1, a);
            else       set_num(c1, a);
        }
    }
}

// ----------------------------------------------------------------------------: 世界 2

rules_world2 :: () {
    // ps:1803  [tmpcheck] -> []
    for pass: stable() for scan(.DOWN)  if has(it, .TMPCHECK)  del(it, .TMPCHECK);

    // ps:1804  [> p 2| o| no y] -> [> p 2| > o|]
    for pass: stable() for d: DIRS4 for scan(d, 3) {
        c1 := nb(it, D);  c2 := nb(c1, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .TWO && has(c1, .THING) && !is_y(c2)  set_mv(c1, .THING, D);
    }

    // ps:1805  horizontal [> p 2 | y | y] -> [> p 2| y tmpcheck| y]
    for pass: stable() for d: Dir.[.LEFT, .RIGHT] for scan(d, 3) {
        c1 := nb(it, D);  c2 := nb(c1, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .TWO && is_y(c1) && is_y(c2)  add(c1, .TMPCHECK);
    }

    // ps:1806  horizontal [> p 2 | x ] -> [> p 2| x tmpcheck]
    for pass: stable() for d: Dir.[.LEFT, .RIGHT] for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .TWO && has(c1, .WALL)  add(c1, .TMPCHECK);
    }

    // ps:1807  up [p 2| y][tmpcheck] -> [p 2|y][]   头顶被挡住就不能爬
    head_blocked := false;
    for scan(.UP, 2)  if has(it, .PLAYER) && w(it) == .TWO && is_y(nb(it, D))  head_blocked = true;
    if head_blocked {
        for pass: stable() for scan(.DOWN)  if has(it, .TMPCHECK)  del(it, .TMPCHECK);
    }

    // ps:1808  random up [tmpcheck| ] -> [|tmpcheck]
    // random 组只应用一次；关卡里同时最多一个 tmpcheck，所以取第一个匹配（原版在多个匹配里随机挑）
    moved_tmpcheck := false;
    for scan(.UP, 2) {
        if !moved_tmpcheck && has(it, .TMPCHECK) {
            c1 := nb(it, D);
            del(it, .TMPCHECK);
            add(c1, .TMPCHECK);
            moved_tmpcheck = true;
        }
    }

    // ps:1810  [climb2] -> []
    for pass: stable() for scan(.DOWN)  if has(it, .CLIMB2)  del(it, .CLIMB2);
    // ps:1811  [climb1] -> [climb2] again
    for pass: stable() for scan(.DOWN)  if has(it, .CLIMB1) { add(it, .CLIMB2); queue(.AGAIN); }

    // ps:1812  right [right p 2][o tmpcheck | no y] -> [2][p wentright climb1| o] again
    // ps:1813  left  [left p 2][o tmpcheck | no y] -> [2][p wentleft climb1| o] again
    for d: Dir.[.RIGHT, .LEFT] {
        for pass: stable() {
            p: s32 = -1;
            for scan(d)  if p < 0 && has(it, .PLAYER) && mv(it, .P) == d && w(it) == .TWO  p = it;
            if p < 0  break;
            for scan(d, 2) {
                c1 := nb(it, D);
                if has(it, .THING | .TMPCHECK) && !is_y(c1) && has(p, .PLAYER) && mv(p, .P) == d {
                    del(p, .PLAYER);
                    del(it, .THING | .TMPCHECK);
                    add(it, .PLAYER);
                    add(it, ifx D == .RIGHT then Obj.WENT_R else .WENT_L);
                    add(it, .CLIMB1);
                    add(c1, .THING);
                    queue(.AGAIN);
                }
            }
        }
    }

    // ps:1815  [left p 2 went][tmpcheck no x no o no 5] -> [2][p wentleft climb1] again
    climb_onto(.LEFT, false);
    // ps:1816  [right p 2 went][tmpcheck no x no o 5] -> [2][p wentright lmark5 5 climb1] again
    climb_onto(.RIGHT, true);
    // ps:1817  [right p 2 went][tmpcheck no x no o no 5] -> [2][p wentright climb1] again
    climb_onto(.RIGHT, false);

    // ---- 重力

    // ps:1820  down [stationary p 2| no o no x] -> [down p 2 |] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && still(it, .P) && w(it) == .TWO && !any(c1, .THING | .WALL) { set_mv(it, .P, .DOWN); queue(.AGAIN); }
    }
    // ps:1821  down [stationary o 2 no x| no p no o no x] -> [down o 2 |] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && still(it, .THING) && w(it) == .TWO && !has(it, .WALL) && !any(c1, .PLAYER | .THING | .WALL) {
            set_mv(it, .THING, .DOWN); queue(.AGAIN);
        }
    }
    // ps:1822  down [stationary p 2 | down o] -> [down p 2 | down o] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && still(it, .P) && w(it) == .TWO && has(c1, .THING) && mv(c1, .THING) == .DOWN { set_mv(it, .P, .DOWN); queue(.AGAIN); }
    }
    // ps:1823  down [stationary o 2 | down p] -> [down o 2 |down p] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && still(it, .THING) && w(it) == .TWO && has(c1, .PLAYER) && mv(c1, .P) == .DOWN { set_mv(it, .THING, .DOWN); queue(.AGAIN); }
    }
    // ps:1824  down [stationary o 2 | down o] -> [down o 2 |down o] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && still(it, .THING) && w(it) == .TWO && has(c1, .THING) && mv(c1, .THING) == .DOWN { set_mv(it, .THING, .DOWN); queue(.AGAIN); }
    }
    // ps:1825  down [stationary o 2 | y 3] -> [down o 2 |y 3] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && still(it, .THING) && w(it) == .TWO && is_y(c1) && w(c1) == .THREE { set_mv(it, .THING, .DOWN); queue(.AGAIN); }
    }
    // ps:1826  down [stationary o 2 | o 6] -> [down o 2 |o 6] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && still(it, .THING) && w(it) == .TWO && has(c1, .THING) && w(c1) == .SIX { set_mv(it, .THING, .DOWN); queue(.AGAIN); }
    }
    // ps:1827  down [stationary o 2 | no mark5 o 5] -> [down o 2 |o 5] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && still(it, .THING) && w(it) == .TWO && has(c1, .THING) && !any(c1, MARK5) && w(c1) == .FIVE {
            set_mv(it, .THING, .DOWN); queue(.AGAIN);
        }
    }
    // ps:1828  down [stationary p 2 | o 3] -> [down p 2 |o 3] again
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && still(it, .P) && w(it) == .TWO && has(c1, .THING) && w(c1) == .THREE { set_mv(it, .P, .DOWN); queue(.AGAIN); }
    }
    // ps:1829  down [down o 2 | o 3] -> [down o 2 | down o 3]
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .DOWN && w(it) == .TWO && has(c1, .THING) && w(c1) == .THREE  set_mv(c1, .THING, .DOWN);
    }
    // ps:1830  down [down p 2 | o 3] -> [down p 2 | down o 3]
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == .DOWN && w(it) == .TWO && has(c1, .THING) && w(c1) == .THREE  set_mv(c1, .THING, .DOWN);
    }
    // ps:1831  down [down o 2 | o 6] -> [down o 2 | down o 6]
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .DOWN && w(it) == .TWO && has(c1, .THING) && w(c1) == .SIX  set_mv(c1, .THING, .DOWN);
    }
    // ps:1832  down [down o 2 | o 5] -> [down o 2 | down o 5]
    for pass: stable() for scan(.DOWN, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == .DOWN && w(it) == .TWO && has(c1, .THING) && w(c1) == .FIVE  set_mv(c1, .THING, .DOWN);
    }
    // ps:1833  down [p 2][down o 5 | no mark5 o 5] -> [p 2][down o 5 | down o 5]
    if exists((i: s32) -> bool { return has(i, .PLAYER) && w(i) == .TWO; }) {
        for pass: stable() for scan(.DOWN, 2) {
            c1 := nb(it, D);
            if has(it, .THING) && mv(it, .THING) == .DOWN && w(it) == .FIVE && has(c1, .THING) && !any(c1, MARK5) && w(c1) == .FIVE  set_mv(c1, .THING, .DOWN);
        }
    }
}

// ps:1815-1817  [dir p 2 went][tmpcheck no x no o (no) 5] -> [2][p wentdir (lmark5 5) climb1] again
climb_onto :: (dir: Dir, into_five: bool) {
    for pass: stable() {
        p : s32 = -1;
        for scan(dir)  if p < 0 && has(it, .PLAYER) && mv(it, .P) == dir && w(it) == .TWO && any(it, WENT)  p = it;
        if p < 0  break;
        for scan(.DOWN) {
            if !has(it, .TMPCHECK) || any(it, .WALL | .THING)  continue;
            if (w(it) == .FIVE) != into_five  continue;
            if !has(p, .PLAYER) || mv(p, .P) != dir || !any(p, WENT)  continue;
            del(p, .PLAYER | WENT);
            del(it, .TMPCHECK);
            add(it, .PLAYER);
            add(it, ifx dir == .RIGHT then Obj.WENT_R else .WENT_L);
            if into_five  add(it, .M5L);
            add(it, .CLIMB1);
            queue(.AGAIN);
        }
    }
}

// ----------------------------------------------------------------------------: 世界 3

// ps:1839  [moving o 3 | o 3] -> [moving o 3| moving o 3]
// ps:1840  + [p 3][> o no 1| o no 1] -> [p 3][> o | > o]
world3_raft_group :: () {
    for pass: stable() {
        for d: DIRS4 for scan(d, 2) {
            c1 := nb(it, D);
            m := mv(it, .THING);
            if has(it, .THING) && m != .NONE && w(it) == .THREE && has(c1, .THING) && w(c1) == .THREE  set_mv(c1, .THING, m);
        }
        if exists((i: s32) -> bool { return has(i, .PLAYER) && w(i) == .THREE; }) {
            for d: DIRS4 for scan(d, 2) {
                c1 := nb(it, D);
                if has(it, .THING) && mv(it, .THING) == D && w(it) != .ONE && has(c1, .THING) && w(c1) != .ONE  set_mv(c1, .THING, D);
            }
        }
    }
}

// ----------------------------------------------------------------------------: 世界 4

// ps:1852-1855（以及 1983-1986）  right/up/left/down [> o |4 no o] -> [> o|4 Xmark4] again
world4_slide_marks :: () {
    for d: Dir.[.RIGHT, .UP, .LEFT, .DOWN] {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .THING) && mv(it, .THING) == D && w(c1) == .FOUR && !has(c1, .THING) {
                add(c1, m4_of(D));
                queue(.AGAIN);
            }
        }
    }
}

// ----------------------------------------------------------------------------: 世界 6（移动部分）

rules_world6_moves :: () {
    // ps:1866  [mark6 sixhide no p] -> [sixhide]
    for pass: stable() for d: DIRS4 {
        mark := m6_of(d);
        for scan(.DOWN)  if has(it, mark) && hw(it) == .SIX && !has(it, .PLAYER)  del(it, mark);
    }
    // ps:1867  [mark6 6 no p] -> [6]
    for pass: stable() for d: DIRS4 {
        mark := m6_of(d);
        for scan(.DOWN)  if has(it, mark) && w(it) == .SIX && !has(it, .PLAYER)  del(it, mark);
    }

    // ps:1875  global [linked fixmypuzzle] -> [linked]
    for pass: stable() for scan(.DOWN, 1, global = true)  if has(it, .LINKED | .FIX1)  del(it, .FIX1);
    // ps:1876  global [linked fixmypuzzle2] -> [linked]
    for pass: stable() for scan(.DOWN, 1, global = true)  if has(it, .LINKED | .FIX2)  del(it, .FIX2);

    // ps:1878  [> p mark6| legs] -> [|p mark6]   朝腿的方向走 = 收腿
    for pass: stable() for d: DIRS4 for m: DIRS4 for scan(d, 2) {
        mark := m6_of(m);
        c1 := nb(it, D);
        if has(it, .PLAYER | mark) && mv(it, .P) == D && has(c1, .LEGS) {
            del(it, .PLAYER | mark);
            del(c1, .LEGS);
            add(c1, .PLAYER);
            add(c1, mark);
        }
    }

    // ps:1879  [< p 6| legs] -> [stationary p 6| legs]   不能继续伸长
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == opposite(D) && w(it) == .SIX && has(c1, .LEGS)  set_mv(it, .P, .NONE);
    }

    // ps:1881-1884  up [stationary p 6 umark6|no legs] -> [up p 6 umark6|]   按重力下落
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER | m6_of(D)) && still(it, .P) && w(it) == .SIX && !has(c1, .LEGS)  set_mv(it, .P, D);
        }
    }
    // ps:1886-1889  up [stationary p 6 umark6| legs] -> [up p 6 umark6|up legs]   连腿一起落
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER | m6_of(D)) && still(it, .P) && w(it) == .SIX && has(c1, .LEGS) {
                set_mv(it, .P, D);
                set_mv(c1, .LEGS, D);
            }
        }
    }

    // ps:1891-1894  up [up p|t sixhide] -> [up p | umark6 t sixhide] again   踩上翻出 6 的开关
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && mv(it, .P) == D && has(c1, .TOGGLE) && hw(c1) == .SIX { add(c1, m6_of(D)); queue(.AGAIN); }
        }
    }

    // ps:1896-1899  up [> p][up o|t sixhide] -> [> p > umark6][up o | t sixhide] again   把箱子推上这种开关
    for d: DIRS4 {
        for pass: stable() {
            pushing := false;
            for scan(d, 2) {
                c1 := nb(it, D);
                if has(it, .THING) && mv(it, .THING) == D && has(c1, .TOGGLE) && hw(c1) == .SIX  pushing = true;
            }
            if !pushing  break;
            for scan(.DOWN)  if has(it, .PLAYER) && mv(it, .P) == d {
                add_moving(it, m6_of(d), d);
                queue(.AGAIN);
            }
        }
    }

    // ps:1901-1904  up [up p no 6|6] -> [up p | umark6 6] again   走进世界 6：重力 = 进入方向
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && mv(it, .P) == D && w(it) != .SIX && w(c1) == .SIX { add(c1, m6_of(D)); queue(.AGAIN); }
        }
    }

    // ps:1906-1909  down [no t|up p dmark6 6] -> [|up p dmark6 legs 6]   逆重力走：腿留在原地
    // 原文四条分别是：down/up p/dmark6、up/down p/umark6、right/left p/rmark6、left/right p/lmark6
    // 四条恰好都是「规则方向 = 重力方向」
    for g: Dir.[.DOWN, .UP, .RIGHT, .LEFT] {
        for pass: stable() for scan(g, 2) {
            c1 := nb(it, D);
            if !has(it, .TOGGLE) && has(c1, .PLAYER | m6_of(g)) && mv(c1, .P) == opposite(g) && w(c1) == .SIX  add(c1, .LEGS);
        }
    }

    // ps:1916  [> p 6| o no mark5] -> [> p 6 | > o]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && mv(it, .P) == D && w(it) == .SIX && has(c1, .THING) && !any(c1, MARK5)  set_mv(c1, .THING, D);
    }
    // ps:1918  [> legs | o no mark5] -> [> legs | > o]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .LEGS) && mv(it, .LEGS) == D && has(c1, .THING) && !any(c1, MARK5)  set_mv(c1, .THING, D);
    }

    // ps:1919-1925  startloop … endloop：先只传播「向上」的连接移动
    for pass: stable() {
        world6_chain_push();
        for d: DIRS4 {
            link := link_of(d);
            for pass: stable() for scan(d, 2) {
                c1 := nb(it, D);
                if has(it, .THING | link) && mv(it, .THING) == .UP && has(c1, .THING)  set_mv(c1, .THING, .UP);
            }
        }
    }

    // ps:1926-1932  startloop … endloop：传播任意方向的连接移动
    for pass: stable() {
        world6_chain_push();
        for d: DIRS4 {
            link := link_of(d);
            for pass: stable() for scan(d, 2) {
                c1 := nb(it, D);
                m := mv(it, .THING);
                if has(it, .THING | link) && m != .NONE && has(c1, .THING)  set_mv(c1, .THING, m);
            }
        }
    }
}

// ps:1920 / 1927  [> o 6| o no 1 no mark5] -> [> o 6 | > o]
world6_chain_push :: () {
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && mv(it, .THING) == D && w(it) == .SIX && has(c1, .THING) && w(c1) != .ONE && !any(c1, MARK5)  set_mv(c1, .THING, D);
    }
}

// ----------------------------------------------------------------------------: 世界 5 与翻转

// ps:2037-2058  翻进世界 5 的那一刻，把「玩家 + 一串不分叉的箱子」变成自由蛇
rules_world5_swap :: () {
    // ps:2037  [touching] -> []
    for pass: stable() for scan(.DOWN)  if tch(it) >= 1 && tch(it) <= 3  set_touch(it, 0);

    // ps:2040  up [po | po] -> [po touchingone | po]
    for pass: stable() for scan(.UP, 2)  if is_po(it) && is_po(nb(it, D))  set_touch(it, 1);
    // ps:2041  down [po touchingone| po] -> [po touchingtwo | po]
    for pass: stable() for scan(.DOWN, 2)  if is_po(it) && tch(it) == 1 && is_po(nb(it, D))  set_touch(it, 2);
    // ps:2042  down [po no touching| po] -> [po touchingone | po]
    for pass: stable() for scan(.DOWN, 2)  if is_po(it) && !is_touching(it) && is_po(nb(it, D))  set_touch(it, 1);
    // ps:2043-2048  left / right：o 的计数饱和到 3，p 饱和到 2
    for d: Dir.[.LEFT, .RIGHT] {
        for pass: stable() for scan(d, 2)  if has(it, .THING) && tch(it) == 2 && is_po(nb(it, D))  set_touch(it, 3);
        for pass: stable() for scan(d, 2)  if is_po(it) && tch(it) == 1 && is_po(nb(it, D))  set_touch(it, 2);
        for pass: stable() for scan(d, 2)  if is_po(it) && !is_touching(it) && is_po(nb(it, D))  set_touch(it, 1);
    }

    // [swap t 5 no swapped]：开关格刚翻成世界 5
    if !exists((i: s32) -> bool { return swp(i) > 0 && has(i, .TOGGLE) && w(i) == .FIVE && !has(i, .SWAPPED); })  return;

    // ps:2050-2053  up [..][p no mark5 no touchingtwo| o no mark5 no x] -> [..][p umark5| o tailmark]  …
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && !any(it, MARK5) && tch(it) != 2 && has(c1, .THING) && !any(c1, MARK5) && !has(c1, .WALL) {
                add(it, m5_of(D));
                add(c1, .TAIL);
            }
        }
    }

    // ps:2055-2058  up [..][o tailmark no touchingthree| o no mark5 no x] -> [..][o umark5| o tailmark]  + down + left + right
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .THING | .TAIL) && tch(it) != 3 && has(c1, .THING) && !any(c1, MARK5) && !has(c1, .WALL) {
            del(it, .TAIL);
            add(it, m5_of(D));
            add(c1, .TAIL);
        }
    }
}

is_touching :: inline (i: s32) -> bool { t := tch(i); return t >= 1 && t <= 3; }

// ps:2086-2116  翻转波
rules_swap_wave :: () {
    // ps:2086  global [swapped no swap] -> []
    for pass: stable() for scan(.DOWN, 1, global = true)  if has(it, .SWAPPED) && swp(it) == 0  del(it, .SWAPPED);
    // ps:2087  global [swap swapped] -> [swapped]
    for pass: stable() for scan(.DOWN, 1, global = true)  if swp(it) > 0 && has(it, .SWAPPED)  set_swap(it, 0);
    // ps:2088  global [swap no swapped] -> [swap swapped]
    for pass: stable() for scan(.DOWN, 1, global = true)  if swp(it) > 0 && !has(it, .SWAPPED)  add(it, .SWAPPED);

    // ps:2090-2093  global down [swap swapped no stopdown| no stopup no swapped] -> [swap swapped|swap] again
    for d: Dir.[.DOWN, .LEFT, .RIGHT, .UP] {
        for pass: stable() for scan(d, 2, global = true) {
            c1 := nb(it, D);
            if swp(it) > 0 && has(it, .SWAPPED) && !has(it, stop_of(D)) && !has(c1, stop_of(opposite(D))) && !has(c1, .SWAPPED) {
                set_swap(c1, swp(it));
                queue(.AGAIN);
            }
        }
    }

    // ps:2095-2100  startloop：swap15 在区域内瞬间铺满
    for pass: stable() {
        for d: Dir.[.DOWN, .LEFT, .RIGHT, .UP] {
            for pass: stable() for scan(d, 2, global = true) {
                c1 := nb(it, D);
                if swp(it) == 15 && !has(it, .SWAPPED) && !has(it, stop_of(D))
                && !has(c1, stop_of(opposite(D))) && !has(c1, .SWAPPED) && swp(c1) != 15  set_swap(c1, 15);
            }
        }
    }

    // ps:2103-2116  [swap14] -> [swap15] … [swap1] -> [swap2]
    k: u8 = 14;
    while k >= 1 {
        for pass: stable() for scan(.DOWN)  if swp(it) == k  set_swap(it, k + 1);
        k -= 1;
    }
}

// ----------------------------------------------------------------------------: 阻挡

rules_stopping :: () {
    // ps:2120  [> p | exitmark] -> [stationary p | exitmark]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        if has(it, .PLAYER) && mv(it, .P) == D && has(nb(it, D), .EXIT)  set_mv(it, .P, .NONE);
    }

    // ps:2121-2124  up [up p | o mark5 no dmark5] -> [stationary p | o mark5]
    for d: DIRS4 {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            back := m5_of(opposite(D));
            if has(it, .PLAYER) && mv(it, .P) == D && has(c1, .THING) && any(c1, MARK5 & ~back) && !has(c1, back)  set_mv(it, .P, .NONE);
        }
    }

    // ps:2126  [> o 5| x no 3] -> [stationary o 5| x no 3]
    stop_thing(.FIVE, (i: s32) -> bool { return has(i, .WALL) && w(i) != .THREE; });
    // ps:2127  [> o 5| stationary o] -> [stationary o 5| o]
    stop_thing(.FIVE, (i: s32) -> bool { return has(i, .THING) && still(i, .THING); });

    // ps:2129  [x moving o no 3] -> [x stationary o]
    for pass: stable() for scan(.DOWN)  if has(it, .WALL | .THING) && !still(it, .THING) && w(it) != .THREE  set_mv(it, .THING, .NONE);

    // ps:2131-2132  [swap][moving o/p] -> [swap][stationary o/p]   翻转波推进期间谁都不许动
    if exists((i: s32) -> bool { return swp(i) > 0; }) {
        for pass: stable() for scan(.DOWN)  if has(it, .THING)  set_mv(it, .THING, .NONE);
        for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) set_mv(it, .P, .NONE);
    }

    // ---- 世界 1
    // ps:2134  [> o 1| o] -> [stationary o 1| o]
    stop_thing(.ONE, (i: s32) -> bool { return has(i, .THING); });
    // ps:2135  [> o| o 1] -> [stationary o| o 1]
    stop_thing(.NONE, (i: s32) -> bool { return has(i, .THING) && w(i) == .ONE; });
    // ps:2136  [> o 1| x no 3] -> [stationary o 1| x no 3]
    stop_thing(.ONE, (i: s32) -> bool { return has(i, .WALL) && w(i) != .THREE; });
    // ps:2137  [> p 1| stationary y no wallfour] -> [stationary p 1| stationary y]
    stop_player(.ONE, blocked_unless_wallfour);

    // ---- 世界 2
    // ps:2140  [> o 2 | x no 3] -> [stationary o 2 | x no 3]
    stop_thing(.TWO, (i: s32) -> bool { return has(i, .WALL) && w(i) != .THREE; });
    // ps:2141  [> p 2| stationary y no wallfour] -> [stationary p 2| stationary y]
    stop_player(.TWO, blocked_unless_wallfour);

    // ---- 世界 3
    // ps:2144  [> o 3| x no 3] -> [stationary o 3| x no 3]
    stop_thing(.THREE, (i: s32) -> bool { return has(i, .WALL) && w(i) != .THREE; });
    // ps:2145  [moving o 3 | stationary o 3] -> [stationary o 3| stationary o 3]   筏子有一块动不了就整组不动
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && !still(it, .THING) && w(it) == .THREE && has(c1, .THING) && still(c1, .THING) && w(c1) == .THREE  set_mv(it, .THING, .NONE);
    }
    // ps:2146  [> p 3 | stationary y no wallfour] -> [stationary p 3 | stationary y]
    stop_player(.THREE, blocked_unless_wallfour);

    // ---- 世界 4
    // ps:2149  [> o 4|o] -> [stationary o 4| o]
    stop_thing(.FOUR, (i: s32) -> bool { return has(i, .THING); });
    // ps:2150  [> o 4|x no three] -> [stationary o 4| x]
    stop_thing(.FOUR, (i: s32) -> bool { return has(i, .WALL) && w(i) != .THREE; });
    // ps:2151  [> o 4|p] -> [stationary o 4| p]
    stop_thing(.FOUR, (i: s32) -> bool { return has(i, .PLAYER); });
    // ps:2152  [> p 4|stationary o] -> [stationary p 4| o]
    stop_player(.FOUR, (i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
    // ps:2153  [> p 4|stationary wallfour2] -> [stationary p 4| wallfour2]
    stop_player(.FOUR, is_wallfour2);
    // ps:2154  [> p 4| wall no four] -> [stationary p 4 | wall]
    stop_player(.FOUR, (i: s32) -> bool { return has(i, .WALL) && w(i) != .FOUR; });

    // ---- 世界 5
    // ps:2160  [> p 5| stationary o] -> [stationary p 5| o]
    stop_player(.FIVE, (i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
    // ps:2162  [> p 5| x] -> [stationary p 5| x]
    stop_player(.FIVE, (i: s32) -> bool { return has(i, .WALL); });

    // ps:2164-2167  up [stationary p no 6 no 2|dmark5 dangthisissohackyblargh] -> [p|]
    // 玩家没走成时撤掉 ps:1942 刚记上的蛇标记
    for d: DIRS4 {
        back := m5_of(opposite(d));
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .PLAYER) && still(it, .P) && w(it) != .SIX && w(it) != .TWO && has(c1, back | .DANG)  del(c1, back | .DANG);
        }
    }
    // ps:2169  [dangthisissohackyblargh] -> []
    for pass: stable() for scan(.DOWN)  if has(it, .DANG)  del(it, .DANG);

    // ps:2171-2174  [up p 5 umark5] -> [stationary p 5 umark5]   不能朝脖子方向走
    for d: DIRS4 {
        mark := m5_of(d);
        for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | mark) && mv(it, .P) == d && w(it) == .FIVE  set_mv(it, .P, .NONE);
    }

    // ---- 世界 6
    // ps:2178  [> o 6| x no 3] -> [stationary o 6| x]
    stop_thing(.SIX, (i: s32) -> bool { return has(i, .WALL) && w(i) != .THREE; });
    // ps:2179  [> p 6| x no 4] -> [stationary p 6|x]
    stop_player(.SIX, (i: s32) -> bool { return has(i, .WALL) && w(i) != .FOUR; });
    // ps:2180  [> legs | x] -> [stationary legs | x]
    stop_legs((i: s32) -> bool { return has(i, .WALL); });
    // ps:2181  [> legs | stationary o] -> [stationary legs | stationary o]
    stop_legs((i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
    // ps:2182  [> p | stationary legs] -> [stationary p | stationary legs]
    stop_player(.NONE, (i: s32) -> bool { return has(i, .LEGS) && still(i, .LEGS); });
    // ps:2183  [> p | stationary o] -> [stationary p | stationary o]
    stop_player(.NONE, (i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
    // ps:2184  [> o 6 | horizontal p] -> [stationary o 6| horizontal p]
    stop_thing(.SIX, (i: s32) -> bool { m := mv(i, .P); return has(i, .PLAYER) && (m == .LEFT || m == .RIGHT); });
    // ps:2185  [> o 6 | stationary p] -> [stationary o 6| stationary p]
    stop_thing(.SIX, (i: s32) -> bool { return has(i, .PLAYER) && still(i, .P); });

    // ps:2186-2192  startloop：被挡住的箱子挡住后面的，连接组整体停下
    for pass: stable() {
        stop_thing(.NONE, (i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
        for d: DIRS4 {
            link := link_of(d);
            for pass: stable() for scan(d, 2) {
                c1 := nb(it, D);
                if has(it, .THING | link) && still(it, .THING) && has(c1, .THING)  set_mv(c1, .THING, .NONE);
            }
        }
    }

    // ps:2193  [> p | stationary o] -> [stationary p | stationary o]
    stop_player(.NONE, (i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
    // ps:2195  [> legs | stationary o] -> [stationary legs | stationary o]
    stop_legs((i: s32) -> bool { return has(i, .THING) && still(i, .THING); });
    // ps:2196  [> p | stationary legs] -> [stationary p | stationary legs]
    stop_player(.NONE, (i: s32) -> bool { return has(i, .LEGS) && still(i, .LEGS); });

    // ps:2198  [stationary p | legs] -> [stationary p | stationary legs]
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .PLAYER) && still(it, .P) && has(c1, .LEGS)  set_mv(c1, .LEGS, .NONE);
    }

    // ps:2199  [> p mark6 6| mark6 ] -> [> p 6| mark6 ]   走进带重力标记的格子：旧标记作废
    for pass: stable() for d: DIRS4 for m: DIRS4 for scan(d, 2) {
        mark := m6_of(m);
        c1 := nb(it, D);
        if has(it, .PLAYER | mark) && mv(it, .P) == D && w(it) == .SIX && any(c1, MARK6)  del(it, mark);
    }

    // ps:2200  [moving p mark6 6] -> [moving p moving mark6 6]   重力标记跟着玩家走
    for pass: stable() for scan(.DOWN) {
        m := mv(it, .P);
        if !has(it, .PLAYER) || m == .NONE || w(it) != .SIX  continue;
        for d: DIRS4 {
            mark := m6_of(d);
            if has(it, mark)  set_mv(it, m6_channel(mark), m);
        }
    }

    // ps:2201  [moving o link] -> [moving o moving link]   连接标记跟着箱子走
    for pass: stable() for scan(.DOWN) {
        m := mv(it, .THING);
        if !has(it, .THING) || m == .NONE  continue;
        for link: Obj.[.LU, .LD, .LR, .LL, .LINKED] {
            if has(it, link)  set_mv(it, link_channel(link), m);
        }
    }

    // ps:2207-2208  [^ p| legs] -> [^ p |]、[v p| legs] -> [v p| ]   侧向移动时收起腿
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        m := mv(it, .P);
        if has(it, .PLAYER) && m != .NONE && m != .ACTION && is_vertical(m) != is_vertical(D) && has(nb(it, D), .LEGS)  del(nb(it, D), .LEGS);
    }

    // ps:2214  [> o 2| stationary o 6 ] -> [stationary o 2| stationary o 6]
    stop_thing(.TWO, (i: s32) -> bool { return has(i, .THING) && still(i, .THING) && w(i) == .SIX; });
}

// [> p W | target] -> [stationary p W | target]
stop_player :: (world: World, target: (i: s32) -> bool) {
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        if has(it, .PLAYER) && mv(it, .P) == D && (world == .NONE || w(it) == world) && target(nb(it, D))  set_mv(it, .P, .NONE);
    }
}

// [> o W | target] -> [stationary o W | target]
stop_thing :: (world: World, target: (i: s32) -> bool) {
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        if has(it, .THING) && mv(it, .THING) == D && (world == .NONE || w(it) == world) && target(nb(it, D))  set_mv(it, .THING, .NONE);
    }
}

stop_legs :: (target: (i: s32) -> bool) {
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        if has(it, .LEGS) && mv(it, .LEGS) == D && target(nb(it, D))  set_mv(it, .LEGS, .NONE);
    }
}

// [> p W | stationary y no wallfour]：墙（永远静止）或静止的箱子，世界 4 的边缘矮墙除外
blocked_unless_wallfour :: (i: s32) -> bool {
    if is_wallfour(i)  return false;
    return has(i, .WALL) || (has(i, .THING) && still(i, .THING));
}

// ----------------------------------------------------------------------------: 隧道

// 原版 ps:1750-1776。每条隧道 = 两个端点 + 一串路径点；镜头每 2 个 tick 前进一个路径点。
tunnel_rules :: () {
    l := sim_level;
    t := *sim.travel;

    // ps:1750-1768  抵达 / 前进（都要求没有 wait2）
    if t.active && t.wait != 2 {
        tunnel := *l.tunnels[t.tunnel];
        last := tunnel.path.count - 1;
        at_end := ifx t.forward then t.step == last else t.step == 0;
        cam := tunnel.path[t.step];
        cam_i := cell_index(cam.x, cam.y);

        if at_end {
            end := ifx t.forward then 1 else 0;
            e := tunnel.ends[end];
            dest := cell_index(e.pos.x, e.pos.y);
            del(cam_i, .CAMERA);
            add(dest, .PLAYER);
            add(dest, .CAMERA);
            bit := tunnel_open_bit(t.tunnel, end);
            if !(sim.open & bit) {
                sim.open |= bit;
                if e.message  queue_message(e.message);
            }
            t.* = .{};
            queue(.AGAIN);
        } else {
            t.step += cast(s32) ifx t.forward then 1 else -1;
            next := tunnel.path[t.step];
            del(cam_i, .CAMERA);
            add(cell_index(next.x, next.y), .CAMERA);
            t.wait = 1;
            queue(.AGAIN);
        }
    }

    // ps:1770-1773  [awarpa | < p camera][connector1] -> [awarpa|][wait goingright camera connector1] again
    if !t.active {
        for tunnel, ti: l.tunnels {
            if !tunnel.path.count  continue;
            for e, ei: tunnel.ends {
                if !(sim.open & tunnel_open_bit(ti, ei))  continue;
                end_i := cell_index(e.pos.x, e.pos.y);
                for d: DIRS4 {
                    n, ok := nb_checked(end_i, d);
                    if !ok || !has(n, .PLAYER | .CAMERA) || mv(n, .P) != opposite(d)  continue;
                    del(n, .PLAYER | .CAMERA);
                    t.active  = true;
                    t.tunnel  = cast(s32) ti;
                    t.forward = ei == 0;
                    t.step    = ifx ei == 0 then 0 else cast(s32)(tunnel.path.count - 1);
                    t.wait    = 1;
                    start := tunnel.path[t.step];
                    add(cell_index(start.x, start.y), .CAMERA);
                    queue(.AGAIN);
                    break;
                }
                if t.active  break;
            }
            if t.active  break;
        }
    }

    // ps:1775  [wait2] -> [] again     ps:1776  [wait] -> [wait2] again
    if t.wait == 2 { t.wait = 0; queue(.AGAIN); }
    if t.wait == 1 { t.wait = 2; queue(.AGAIN); }
}
