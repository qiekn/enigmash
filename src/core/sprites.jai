// 精灵枚举由 tools/gen_atlas.jai 生成（src/generated/atlas.jai），这里只负责加载纹理。

load_texture :: (filename : string) -> Simp.Texture {
    texture : Simp.Texture;
    success := Simp.texture_load_from_file(*texture, filename);
    assert(success, "Can't load texture '%'.", filename);

    // Pixel art
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    return texture;
}

#scope_file

#import "GL";
