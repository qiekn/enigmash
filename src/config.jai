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
CAMERA_FOLLOW_SPEED :: 12.0;  // 指数平滑系数，相机移动不是瞬移
CAMERA_CLAMP_MARGIN :: 8.0;   // 允许摄像机看出地图外多少格

VIEW_TILES :: 13.0;           // 游戏默认视野：屏幕高度铺满 13 格（原版 zoomscreen 13x13）

MOVE_REPEAT_DELAY    :: 150;
MOVE_REPEAT_INTERVAL :: 150; // PuzzleScript Style: 150ms

FONT\   _FOLDER :: "assets/fonts";
TEXTUER\_FOLDER :: "assets/textures";
SOUND\  _FOLDER :: "assets/sounds";

DEFAULT_LEVEL_PATH :: "assets/levels/enigmash.lvl";


// ----------------------------------------------------------------------------: colors

Color :: Vector4;
BLACK :: Vector4.{0, 0, 0, 1};
WHITE :: Vector4.{1, 1, 1, 1};
RED   :: Vector4.{1, 0, 0, 1};
GREEN :: Vector4.{0, 1, 0, 1};
BLUE  :: Vector4.{0, 0, 1, 1};
CYAN :: Vector4.{0, 1, 1, 1};

ORANGE :: Vector4.{0.92, 0.54, 0.19, 1};

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
