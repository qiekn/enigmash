// 精灵枚举由 tools/gen_atlas.jai 生成（src/generated/atlas.jai），这里只负责加载纹理。

// 从资源包里读纹理（name 是包内路径）
load_texture :: (name : string) -> Simp.Texture {
    texture : Simp.Texture;
    memory, ok := data_file(name);
    assert(ok, "Texture '%' is not in the package.", name);
    success := Simp.texture_load_from_memory(*texture, memory);
    assert(success, "Can't load texture '%'.", name);

    // Pixel art
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    return texture;
}

#scope_file

#import "GL";
