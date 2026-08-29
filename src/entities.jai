Entity_Type :: enum {
    PLAYER;
    BOX;
}

Position :: struct {
    x, y : int;
}

Player :: struct {
    type: Entity_Type;
    using pos : Position;

    Id := 1;
}

Wall :: struct {
    using pos: Position;
}

Crate :: struct {
    using pos: Position;
}
