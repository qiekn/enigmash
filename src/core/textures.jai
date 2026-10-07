// 从资源包里读纹理（name 是包内路径）
load_texture :: (name : string) -> Texture {
    texture : Texture;
    memory, ok := data_file(name);
    assert(ok, "Texture '%' is not in the package.", name);
    success := Simp.texture_load_from_memory(*texture, memory);
    assert(success, "Can't load texture '%'.", name);

    // Pixel art
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    return texture;
}
