// @Hack Dont change the order, it syncs with sprites.png
Sprite:: enum u8 {
    Player;
    Crate;
    Ground;
    Wall;
    Button;
}

load_texture :: (filename : string) -> Simp.Texture {
    texture : Simp.Texture;
    success := Simp.texture_load_from_file(*texture, filename);
    assert(success);

    // Pixel art
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    return texture;
}

#scope_file

#import "GL";
