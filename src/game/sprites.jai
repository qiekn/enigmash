// ----------------------------------------------------------------------------: atlas definitions

// 枚举顺序对应 textures/atlas.png 中的精灵排列，修改时保持一致。
ATLAS_PATH :: "textures/atlas.png";   // 资源包内路径
ATLAS_COLS :: 16;
ATLAS_ROWS :: 10;
ATLAS_CELL :: 7;   // 像素；中间 5x5 是本体

Sprite :: enum u16 {
    background;
    p;
    thing;
    wall;
    one;
    two;
    three;
    four;
    five;
    six;
    toggle;
    wallone;
    wallthingone;
    playerone;
    backgroundone;
    thingone;
    checkone;
    toggleone;
    walltwo;
    wallthingtwo;
    walltwoup;
    walltwodown;
    walltwoleft;
    walltworight;
    playertwoleft;
    playerl1;
    playerl1a;
    playerl1b;
    playerl2;
    playertworight;
    playerr1;
    playerr1a;
    playerr1b;
    playerr2;
    backgroundtwo;
    thingtwo;
    toggletwo;
    checktwo;
    wallthree;
    playerthree;
    backgroundthree;
    n3ulb;
    n3dlb;
    n3urb;
    n3drb;
    n3uly;
    n3dly;
    n3ury;
    n3dry;
    togglethree;
    thingthree;
    checkthree;
    llink3;
    rlink3;
    dlink3;
    ulink3;
    sunkthree;
    wallfour;
    wallfour2;
    wallfour2down;
    playerfourleft;
    playerfourright;
    backgroundfour;
    thingfour;
    wallthingfour;
    togglefour;
    checkfour;
    wallfive;
    wallfivealt;
    playerfiveu;
    playerfivel;
    playerfived;
    playerfiver;
    checkfive;
    backgroundfive;
    thingfive;
    thingfive2;
    fiveleft;
    fiveup;
    fivedown;
    fiveright;
    togglefive;
    playersix1;
    playersix2;
    playersix3;
    playersix4;
    legs1;
    legs2;
    legs3;
    legs4;
    thingsix;
    llink;
    ulink;
    dlink;
    rlink;
    backgroundsix;
    triml;
    trimr;
    trimu;
    trimd;
    trimul;
    trimdr;
    trimur;
    trimdl;
    tracel1;
    tracel2;
    traceu1;
    traceu2;
    tracer1;
    tracer2;
    traced1;
    traced2;
    togglesix;
    checksix;
    wallsix;
    stopleft;
    stopright;
    stopdown;
    stopup;
    barrierup2;
    barrierdown2;
    barrierleft2;
    barrierright2;
    barrierup;
    barrierdown;
    barrierleft;
    barrierright;
    sevenwall;
    lettera;
    letterc;
    lettere;
    letterf;
    letterg;
    letterh;
    letter;
    letteri;
    letterk;
    letterl;
    lettern;
    lettero;
    letterp;
    letterr;
    letters;
    lettert;
    littlert;
    letteru;
    letterx;
    lettery;
    awarpa;
    awarpb;
    awarpc;
    awarpd;
    messag;
}

the_sprite : Texture;

// ----------------------------------------------------------------------------: game atlas

init_sprites :: () {
    the_sprite = load_texture(ATLAS_PATH);
    init_sprite_uvs();
}

Sprite_UV :: struct { u0, v0, u1, v1: float; }

// 启动时算一次（缩小看全图时每帧要画几万个精灵，别每次都做除法）
sprite_uv_table : [#run enum_highest_value(Sprite) + 1] Sprite_UV;

init_sprite_uvs :: () {
    for * sprite_uv_table {
        u0, v0, u1, v1 := sprite_uv_compute(cast(Sprite) it_index);
        it.* = .{u0, v0, u1, v1};
    }
}

sprite_uv :: inline (kind: Sprite) -> (u0: float, v0: float, u1: float, v1: float) {
    t := *sprite_uv_table[cast(int) kind];
    return t.u0, t.v0, t.u1, t.v1;
}

sprite_uv_compute :: (kind: Sprite) -> (u0: float, v0: float, u1: float, v1: float) {
    idx := cast(int) kind;
    col := idx % ATLAS_COLS;
    row := idx / ATLAS_COLS;

    tw := cast(float)(ATLAS_COLS * ATLAS_CELL);
    th := cast(float)(ATLAS_ROWS * ATLAS_CELL);

    // 每个格子中间 5x5 是本体，外圈 1px 是复制出来的边缘（防止采样串到隔壁精灵）
    px0 := cast(float)(col * ATLAS_CELL + 1);
    py0 := cast(float)(row * ATLAS_CELL + 1);   // 从图片顶部数

    // Simp 的 shader 里有 1 - v，所以 v = 0 是图片底部
    return px0 / tw, 1.0 - (py0 + 5) / th, (px0 + 5) / tw, 1.0 - py0 / th;
}

draw_sprite :: (camera: *Camera, kind: Sprite, x: int, y: int, tint := WHITE) {
    tile_size := camera_tile_px(camera);
    p  := world_to_screen(camera, cast(float) x, cast(float) y);
    draw_sprite_screen(kind, p.x, p.y, tile_size, tint);
}

// 屏幕像素位置（左下角）和边长
draw_sprite_screen :: (kind: Sprite, x0: float, y0: float, size: float, tint := WHITE) {
    u0, v0, u1, v1 := sprite_uv(kind);

    x1 := x0 + size;
    y1 := y0 + size;

    draw_texture_region(*the_sprite, x0, y0, x1, y1, u0, v0, u1, v1, tint);
}
