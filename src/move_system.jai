// Move_Intent :: struct {
//     entity: Entity_Id;
//     dir: Direction;
// }

player_try_move ::(dx: int, dy: int) {
    the_player.x += dx;
    the_player.y += dy;
}
