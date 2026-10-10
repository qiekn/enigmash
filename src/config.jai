// ----------------------------------------------------------------------------: constants

JAILOR :: "Qiekn";

MAJOR_VERSION :: 0;
MINOR_VERSION :: 1;
BABY_VERSION  :: 0;

FIXED_TILE_SIZE :: 5; // pixels

// 世界的格子范围。摄像机的 clamp / fit 和棋盘格背景都按它来。
MAP_WIDTH  :: 100;
MAP_HEIGHT :: 100;

// ----------------------------------------------------------------------------: camera

CAMERA_DEFAULT_ZOOM :: 16.0;  // 1 tile = FIXED_TILE_SIZE * zoom 像素
CAMERA_MIN_ZOOM     :: 0.4;   // tile = 2px，缩到底够看下整张地图
CAMERA_MAX_ZOOM     :: 24.0;
CAMERA_ZOOM_STEP    :: 1.15;  // 鼠标滑轮每一格滚轮的缩放倍率

CAMERA_PAN_SPEED    :: 20.0;  // 在默认缩放下的平移速度 (Girds/seconds)
// 跟随用临界阻尼弹簧（带速度）：大约多少秒追上目标。
// 长按方向键时玩家 MOVE_REPEAT_INTERVAL 走一格，镜头保留速度、匀速跟上，不会每格停一下
CAMERA_FOLLOW_SMOOTH_TIME :: 0.15;
CAMERA_FOLLOW_DEAD_ZONE :: 0.70; // 中央 70% 区域内镜头不动，进入边缘 15% 后平滑跟随。
CAMERA_CLAMP_MARGIN :: 8.0;   // 允许摄像机看出地图外多少格

VIEW_TILES :: 13.0;           // 游戏默认视野：屏幕高度铺满 13 格（原版 zoomscreen 13x13）

MOVE_REPEAT_DELAY    :: 150;
MOVE_REPEAT_INTERVAL :: 150; // PuzzleScript Style: 150ms

// 翻转波的显示速度：原版第 16 个 tick 瞬间铺满的那部分，画面上按每圈这么多毫秒继续往外扩（只影响画面）
SWAP_WAVE_RING_MS :: 20.0;

// 资源包内的路径（相对仓库 data/，见 core/package.jai）
FONT\   _FOLDER :: "fonts";
TEXTUER\_FOLDER :: "textures";
SOUND\  _FOLDER :: "sounds";

DEFAULT_LEVEL_NAME :: "enigmash.level";          // 包内在 levels/ 下

SAVE_DIR :: "save";                              // 相对 exe 所在目录

// ----------------------------------------------------------------------------: colors

MENU_VISIBLE_CAMPAIGNS :: 6;       // 战役列表一屏最多显示几项

BACKGROUND_COLOR :: Vector4.{0, 0.27, 0.41, 1};
DEBUG_TEXT_COLOR :: Vector4.{0.6, 1, 0.6, 0.9};

GAME_CLEAR_COLOR    :: Vector4.{0.16, 0.17, 0.2, 1};
MESSAGE_BOX_COLOR   :: Vector4.{0, 0, 0, 0.85};
MESSAGE_TEXT_COLOR  :: Vector4.{1, 1, 1, 1};
HINT_TEXT_COLOR     :: Vector4.{1, 1, 1, 0.45};

// 编辑器示意视图里每个世界的颜色（下标 = World）
WORLD_COLORS :: Vector4.[
    .{0.25, 0.25, 0.25, 1},   // NONE
    .{0.64, 0.81, 0.15, 1},   // 1 草地
    .{0.96, 0.78, 0.94, 1},   // 2 粉色
    .{0.87, 0.80, 0.31, 1},   // 3 黄
    .{0.33, 0.33, 0.40, 1},   // 4 深灰
    .{0.81, 0.70, 0.48, 1},   // 5 沙色
    .{0.63, 0.96, 0.96, 1},   // 6 青
    .{0.02, 0.02, 0.02, 1},   // 7 虚空
];
