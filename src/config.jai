// ----------------------------------------------------------------------------: constants

MAJOR_VERSION :: 0;
MINOR_VERSION :: 1;
BABY_VERSION  :: 0;

FIXED_TILE_SIZE :: 5; // pixels

MAP_WIDTH  :: 100;
MAP_HEIGHT :: 100;
MAX_CRATES :: 64;

// ----------------------------------------------------------------------------: camera

CAMERA_DEFAULT_ZOOM :: 16.0;  // 1 tile = FIXED_TILE_SIZE * zoom 像素
CAMERA_MIN_ZOOM     :: 0.4;   // tile = 2px，刚好够看下整张 100x100
CAMERA_MAX_ZOOM     :: 24.0;
CAMERA_ZOOM_STEP    :: 1.15;  // 每一格滚轮的缩放倍率

CAMERA_PAN_SPEED    :: 20.0;  // grids / 秒，在 CAMERA_DEFAULT_ZOOM 下的速度
CAMERA_FOLLOW_SPEED :: 12.0;  // 指数平滑系数，越大吸得越快
CAMERA_CLAMP_MARGIN :: 8.0;   // 允许摄像机看出地图外多少格

SPRITE_PATH :: "assets/textures/sprites.png";

MOVE_REPEAT_DELAY    :: 150;
MOVE_REPEAT_INTERVAL :: 150; // PuzzleScript Style: 150ms

FONT\   _FOLDER :: "assets/fonts";
TEXTUER\_FOLDER :: "assets/textures";
SOUND\  _FOLDER :: "assets/sounds";

