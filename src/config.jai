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

// Player / Box / Ground / Wall / Switch
SPRITE_PATH :: "assets/textures/sprites_all.png";
SPRITE_ROWS :: 6;
SPRITE_COLS :: 5;

MOVE_REPEAT_DELAY    :: 150;
MOVE_REPEAT_INTERVAL :: 150; // PuzzleScript Style: 150ms

FONT\   _FOLDER :: "assets/fonts";
TEXTUER\_FOLDER :: "assets/textures";
SOUND\  _FOLDER :: "assets/sounds";

