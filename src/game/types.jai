// 游戏逻辑的核心类型
//
// 坐标约定（逻辑层）：和原版 PuzzleScript 一致，x 向右、y 向下，第 0 行是地图最上面一行；
// 格子索引 i = x*H + y（原版就是按这个顺序遍历、结算移动的，保持一致才能逐格对上）。
// 渲染层是 y 朝上的，换算见 grid_to_world()。

World :: enum u8 {
    NONE  :: 0;
    ONE   :: 1;
    TWO   :: 2;
    THREE :: 3;
    FOUR  :: 4;
    FIVE  :: 5;
    SIX   :: 6;
    SEVEN :: 7;   // 虚空（终局）
}

Dir :: enum u8 {
    NONE   :: 0;
    UP     :: 1;
    DOWN   :: 2;
    LEFT   :: 3;
    RIGHT  :: 4;
    ACTION :: 5;
}

DIRS4  :: Dir.[.UP, .DOWN, .LEFT, .RIGHT];
MOVING :: Dir.[.UP, .DOWN, .LEFT, .RIGHT, .ACTION];   // 原版 moving 的展开顺序

// 格子里的对象（原版的 object，只保留有逻辑作用的；纯装饰的在渲染时现算）
// 注释里的名字是原脚本里的对象名
Obj :: enum_flags u64 {
    WALL;        // Wall
    THING;       // Thing (o)
    PLAYER;      // p
    CAMERA;      // camera（原版的 player 就是它：接收输入、决定局部半径）
    SUNK;        // sunk
    TOGGLE;      // Toggle (t)
    STOP_U;      // stopup
    STOP_D;      // stopdown
    STOP_L;      // stopleft
    STOP_R;      // stopright
    JUST_P;      // justswappedp   与 JUST_O 同层
    JUST_O;      // justswappedo
    SWAPPED;     // swapped
    NOSWAP;      // noswap
    M5U; M5D; M5L; M5R;   // u/d/l/rmark5：蛇身链表，方向指向尾部
    TAIL;        // tailmark
    EXIT;        // exitmark      与 SECRET 同层
    FINISHED;    // finishedeating
    DANG;        // dangthisissohackyblargh
    E5U; E5D; E5L; E5R;   // efiveup/...  分别与 M5U/M5D/M5L/M5R 同层
    M4U; M4D; M4L; M4R;   // u/d/l/rmark4：冰面滑行      M4D 与 HALLOWEEN/GREEDY 同层
    M6U; M6D; M6L; M6R;   // u/d/l/rmark6：世界 6 重力    M6D 与 OOPS 同层
    LEGS;        // legs
    LU; LD; LL; LR;       // ulink/dlink/llink/rlink：世界 6 箱子连接
    LINKED;      // linked
    FIX1;        // fixmypuzzle   与 WINNER 同层
    FIX2;        // fixmypuzzle2  与 WINSPAWN 同层
    WENT_L;      // wentleft      与 WENT_R 同层
    WENT_R;
    CLIMB1;      // climb1        与 CLIMB2 同层
    CLIMB2;
    TMPCHECK;    // tmpcheck
    SEVENWALL;   // sevenwall
    WINNER;      // winner
    WINSPAWN;    // winspawn (a)
    CAMSHIFT;    // camerashift
    OOPS;        // oops (¿)
    HALLOWEEN;   // halloweenbowlpleaseonlytakeone
    GREEDY;      // dontbegreedy (_)
    SECRET;      // messag (")
}

// 只会被规则删除、不会被规则新增的静态标记，单独放一个掩码
Mark :: enum_flags u16 {
    CHECKPOINT;     // checkpoin (*)
    CAMSTICK;       // camerastick (z)
    CAMSHIFTLEFT;   // camerashiftleft (')
    HINT_RESET;     // checkpointmessage (:)   这 5 个同层
    BRANCH_L;       // branchmessageleft (<)
    BRANCH_R;       // branchmessageright (>)
    BRANCH_ONCE;    // branchmessage (\)
    UHH;            // uhhdont (;)
    BAD_IDEA;       // reallybadidea (,)
}

MARK5 :: Obj.M5U | .M5D | .M5L | .M5R | .TAIL;
EFIVE :: Obj.E5U | .E5D | .E5L | .E5R;
MARK4 :: Obj.M4U | .M4D | .M4L | .M4R;
MARK6 :: Obj.M6U | .M6D | .M6L | .M6R;
LINKS :: Obj.LU | .LD | .LL | .LR | .LINKED;
WENT  :: Obj.WENT_L | .WENT_R;
Y_OBJ :: Obj.WALL | .THING;      // 原版的 y
PO    :: Obj.PLAYER | .THING;    // 原版的 po

MESSAGE_MARKS :: Mark.HINT_RESET | .BRANCH_L | .BRANCH_R | .BRANCH_ONCE | .UHH;

Cell :: struct {
    obj   : Obj;
    mark  : Mark;
    num   : World;   // 可见世界（原版 num 层）
    hide  : World;   // 隐藏世界（原版 hide 层）
    swap  : u8;      // 翻转波计数：0 = 无，1..16 = 原版 swap1..swap16
    touch : u8;      // 原版 touching/supported 层：0 无，1..3 = touchingone..three，4 = supported
}

TOUCH_SUPPORTED :: 4;

// 可移动的层（原版每层独立带移动方向）。顺序 = 原版碰撞层顺序，移动结算按这个顺序逐层尝试。
Channel :: enum u8 {
    P; THING; LEGS; M6D; M6U; M6L; M6R; LU; LD; LR; LL; LINKED; WENT; CAMERA; CAMSHIFT;
}
CHANNEL_COUNT :: #run enum_highest_value(Channel) + 1;

// 每个通道所在层里的全部对象（移动时整层一起走，也用于碰撞判断）
CHANNEL_MASK :: Obj.[
    .PLAYER, .THING, .LEGS, .M6D | .OOPS, .M6U, .M6L, .M6R, .LU, .LD, .LR, .LL, .LINKED, .WENT_L | .WENT_R, .CAMERA, .CAMSHIFT,
];

// ----------------------------------------------------------------------------: 方向

opposite :: (d: Dir) -> Dir {
    if d == {
        case .UP;    return .DOWN;
        case .DOWN;  return .UP;
        case .LEFT;  return .RIGHT;
        case .RIGHT; return .LEFT;
    }
    return d;
}

is_vertical :: (d: Dir) -> bool { return d == .UP || d == .DOWN; }

dir_delta :: (d: Dir) -> (dx: s32, dy: s32) {
    if d == {
        case .UP;    return  0, -1;
        case .DOWN;  return  0,  1;
        case .LEFT;  return -1,  0;
        case .RIGHT; return  1,  0;
    }
    return 0, 0;
}

// 按方向取对应的标记位
m5_of :: (d: Dir) -> Obj { if d == { case .UP; return .M5U; case .DOWN; return .M5D; case .LEFT; return .M5L; } return .M5R; }
e5_of :: (d: Dir) -> Obj { if d == { case .UP; return .E5U; case .DOWN; return .E5D; case .LEFT; return .E5L; } return .E5R; }
m4_of :: (d: Dir) -> Obj { if d == { case .UP; return .M4U; case .DOWN; return .M4D; case .LEFT; return .M4L; } return .M4R; }
m6_of :: (d: Dir) -> Obj { if d == { case .UP; return .M6U; case .DOWN; return .M6D; case .LEFT; return .M6L; } return .M6R; }
link_of :: (d: Dir) -> Obj { if d == { case .UP; return .LU; case .DOWN; return .LD; case .LEFT; return .LL; } return .LR; }
stop_of :: (d: Dir) -> Obj { if d == { case .UP; return .STOP_U; case .DOWN; return .STOP_D; case .LEFT; return .STOP_L; } return .STOP_R; }

m6_channel :: (o: Obj) -> Channel {
    if o == {
        case .M6U; return .M6U;
        case .M6D; return .M6D;
        case .M6L; return .M6L;
    }
    return .M6R;
}

link_channel :: (o: Obj) -> Channel {
    if o == {
        case .LU; return .LU;
        case .LD; return .LD;
        case .LL; return .LL;
        case .LR; return .LR;
    }
    return .LINKED;
}

// ----------------------------------------------------------------------------: 同层对象
//
// 原版里往格子加对象会先清掉同层的其他对象；规则 LHS 用到、RHS 没用到的层会整层清空。
// 这里只登记确实有多个逻辑对象共享的层。

layer_of :: (o: Obj) -> Obj {
    if o == {
        case .JUST_P; #through;
        case .JUST_O;    return .JUST_P | .JUST_O;
        case .M5U; #through;
        case .E5U;       return .M5U | .E5U;
        case .M5D; #through;
        case .E5D;       return .M5D | .E5D;
        case .M5L; #through;
        case .E5L;       return .M5L | .E5L;
        case .M5R; #through;
        case .E5R;       return .M5R | .E5R;
        case .M4D; #through;
        case .HALLOWEEN; #through;
        case .GREEDY;    return .M4D | .HALLOWEEN | .GREEDY;
        case .M6D; #through;
        case .OOPS;      return .M6D | .OOPS;
        case .FIX1; #through;
        case .WINNER;    return .FIX1 | .WINNER;
        case .FIX2; #through;
        case .WINSPAWN;  return .FIX2 | .WINSPAWN;
        case .EXIT; #through;
        case .SECRET;    return .EXIT | .SECRET;
        case .WENT_L; #through;
        case .WENT_R;    return .WENT_L | .WENT_R;
        case .CLIMB1; #through;
        case .CLIMB2;    return .CLIMB1 | .CLIMB2;
    }
    return o;
}

channel_of :: (o: Obj) -> Channel, bool {
    for CHANNEL_MASK  if it & o  return cast(Channel) it_index, true;
    return .P, false;
}
