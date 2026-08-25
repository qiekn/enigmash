Position :: struct {
    x, y : int;
}

Player :: struct {
    using pos : Position;

    Id := 1;
}

Wall :: struct {
    using pos: Position;
}

Crate :: struct {
    using pos: Position;
}
