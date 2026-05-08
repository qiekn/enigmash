# enigmash: native C++ / EnTT 实现 + ImGui 内置编辑器

## Context

仓库 `C:/msys64/home/user/gamedev/remake/enigmash` 已有 raylib 6 + ImGui (docking) +
SceneManager + LayerStack 的脚手架，但 `GameplayScene` 是占位画面。原版游戏
`refs/enigmash-original/game.txt` 是 JackLance 用 PuzzleScript 写的 ~2500 行脚本：
单张 ~100×100 大地图、camera 跟随、6 个区域各有一套推箱子方言，外加 toggle swap、
checkpoint、单向墙、终点 win。

**目标**：用 C++23 + raylib + EnTT，**不复刻 PuzzleScript runtime**，把游戏机制
直接 hand-code 成 system，数据驱动；同时在 ImGui 里做内置编辑器，能画关卡、查看
object、inspect 任意 cell，热重载。

---

## 拍板的决策

| 主题 | 决策 |
|---|---|
| Runtime | **不**做 PuzzleScript 兼容；hand-code C++ system |
| ECS | **EnTT**（已 vendor 在 `deps/entt/single_include/entt/entt.hpp`） |
| 关卡数据 | **JSON**，按 region 分文件 + 顶层 `world/index.json` 做 stitch |
| Undo | **环形 buffer**，固定 **256 步**，超出丢最旧 |
| 美术 | 高分辨率 sprite，**128 × 128 px source**；POINT filter 缩放保留像素感作为占位 |
| 移动动画 | **Spring**（≈ Balatro T/VT 套路）：logic 立刻进位到 `Cell`，`VisualXY` 弹簧追位（stiffness ≈ 180, damping ≈ 22） |
| 玩家 avatar | **按 region 换 sprite**（保留原版"进新区变身"叙事） |
| Editor v1 | Tile Painter + Object Catalog（只读）+ Inspector + Hot Reload |

### 战术默认（后续可调，不需要再问）

- **Input 节流**：首发 200ms、连发 100ms（PS 的传统配方）
- **Camera follow**：跟玩家 RenderXY 走 spring，参数同玩家 spring
- **Action 按键**：`Space`（"use" 终点），`Z` undo，`R` 回 checkpoint，方向键/`hjkl`/`WASD` 三套 input
- **Z-order**：每个 object 在 `objects.json` 里声明 `layer: int8`，loader emplace 成 `ZOrder`
- **Toggle swap radius**：从 `objects.json` 的 toggle entry 读 `radius`（默认 16，对应原版 `local_radius 17`）
- **存档**：进度（最近 checkpoint）写到 `save.json`，跟 `window.state` 同目录

---

## 架构

### Layer / Scene 分工

- `GameLayer` 不变：拥有 RT，托管 `SceneManager`。
- `GameplayScene` 持有 `entt::registry world_`、`UndoRing undo_`、`SystemDispatcher systems_`，
  同时 host 编辑器 panel（编辑器不是单独 Scene，而是 GameplayScene 的 ImGui 视图——共享同一个 registry）。
- 编辑器开关：菜单栏 toggle，默认 dev 构建打开、release 关闭。

### Component 草表

> **命名**：参考 Balatro 的 T (Transform, 逻辑真值) / VT (Visual Transform, 渲染追位) 模式。
> 这里 `Cell` ≈ T（整数格），`VisualXY` ≈ VT（浮点像素）。
> **Stop / StopDir** 命名参考 Baba is You：表达"阻止移动"，比 `Wall` 更准确。

```cpp
// 空间 / 渲染
struct Cell        { int x, y; };                  // 逻辑位置 (T)
struct VisualXY    { float x, y; float vx, vy; };  // 渲染位置 + 速度 (VT)，spring 物理
struct Move        { Direction dir; };             // 本回合移动意图
struct ZOrder      { int8_t layer; };
struct Sprite      { uint32_t atlas_id; };

// 行为 tag
struct Player {};
struct Pushable {};
struct Stop {};                                    // 不可穿过（原 Wall）
struct StopDir     { Direction blocks; };          // 单向阻挡 n/s/e/w
struct Toggle      { uint8_t radius; };
struct Checkpoint {};
struct Background  { Region region; };
struct Linked      { entt::entity head; };         // region 6 cluster
struct Supported {};                                // region 3 浮力 late tag
```

### Spring 物理（VisualXY 追 Cell）

```cpp
// RenderInterpSystem，每渲染帧跑一次
auto view = reg.view<Cell, VisualXY>();
for (auto [e, c, v] : view.each()) {
  const float tx = c.x * kTilePx;
  const float ty = c.y * kTilePx;
  const float dx = tx - v.x;
  const float dy = ty - v.y;
  const float fx = kStiffness * dx - kDamping * v.vx;
  const float fy = kStiffness * dy - kDamping * v.vy;
  v.vx += fx * dt;  v.vy += fy * dt;
  v.x  += v.vx * dt; v.y += v.vy * dt;
}
```

新建 entity 时 `VisualXY{cell.x*kTilePx, cell.y*kTilePx, 0, 0}`，避免首帧从 (0,0) 飞过来。
Camera 用同一套公式追玩家 VisualXY。

### System 调度

```cpp
// 逻辑帧：被 input 节流触发，不是每渲染帧都跑
void Tick(entt::registry& reg, Input in) {
  ApplyInput(reg, in);              // Player → Move
  Region r = RegionUnderPlayer(reg);
  region_systems_[r](reg);          // 6 套之一
  ResolveCollisions(reg);           // 共享：墙 / 单向墙 / 边界
  ToggleSwap(reg);                  // 共享：t 触发的 BFS swap
  PatchPlayerSprite(reg);           // 按 Background.region 换 player Sprite
  CheckpointSave(reg);
  undo_.PushSnapshot(reg);
}

// 渲染帧：每帧
void RenderFrame(entt::registry& reg, float dt) {
  RenderInterpSystem(reg, dt);      // VisualXY spring 追 Cell × 128
  CameraFollow(reg, dt);            // camera 跟玩家 RenderXY
  DrawTiles(reg);                   // 按 ZOrder 排序后逐个 DrawTexturePro
}
```

每个 region system 50–150 行，封装该区 push 的特殊语义。可以放到 `src/game/regions/r<N>.cpp`，
共享辅助函数（`PushChain`, `IsBlocked` 等）放 `src/game/systems/`.

---

## 资源 / 代码布局

```
assets/
  data/
    objects.json           # 名字 → sprite 路径 + layer + 行为 tag (+toggle radius 等)
    legend.json            # object id → 默认 component bundle（编辑器 dropdown 用）
    world/
      index.json           # { regions: [{ id, origin: [x,y], file }] }
      r1.json              # { width, height, cells: [[[ids…], …], …] }
      r2.json …
  sprites/
    objects/<name>.png     # 每个 object 一张 128×128
    player/<region>/idle.png, walk_l.png, walk_r.png, climb1.png, climb2.png, …

src/
  game/
    components.h           # 上面那张表
    direction.h
    world.h/cpp            # registry + load/save JSON
    undo_ring.h/cpp        # entt::snapshot 环形 buffer
    systems/
      input.cpp
      collisions.cpp
      toggle_swap.cpp
      render_interp.cpp
      camera_follow.cpp
      patch_player_sprite.cpp
    regions/
      r1_sokoban.cpp
      r2_gravity.cpp
      r3_chain.cpp
      r4_shoot.cpp
      r5_snake.cpp
      r6_cluster.cpp
    editor/
      tile_painter.cpp
      object_catalog.cpp
      inspector.cpp
      hot_reload.cpp
  scenes/
    gameplay_scene.{h,cpp}  # 已存在，重写：拥有 registry，托管 systems + editor
```

---

## 里程碑

| M | 目标 | 验收 |
|---|---|---|
| M1 | `objects.json` + sprite 加载到 atlas + 静态 tile render + camera 居中 | 跑出一张写死的 5×5 测试图 |
| M2 | `world/index.json` + region JSON loader → registry | 能加载手写的小 region 并渲染 |
| M3 | 玩家输入 + Spring + region 1 sokoban push + 撞墙 / OneWay | 在测试 region 玩 push box 不崩 |
| M4 | region 2/3（gravity / chain）+ late pass 框架 | 各对应一张测试 region 通过 |
| M5 | region 4/5/6 + Toggle swap (BFS) + Linked cluster | 同上 |
| M6 | Checkpoint / Undo (Z 256 步) / Restart (R) / 终点 win + 简单 SFX | 主菜单 → gameplay → 终点 → 回主菜单 |
| M7 | Editor v1：Tile Painter + Object Catalog + Inspector + Hot Reload | 在编辑器画 5×5 房间，热重载能玩 |
| M8 | 把原版整张大图迁移成 region JSON 集合 | 通关 enigmash |

---

## Verification（每个 M 结束跑）

- 启动 → 主菜单 → Gameplay → ESC 回主菜单 → Quit 干净退出（不 leak GL/audio）
- 当前 milestone 的 region 跑 hand-crafted 测试关
- M3+：按 Z 撤销不爆，连按到底回到关卡开头（256 步内）
- M6+：终点触发 win，回主菜单状态正确
- M7+：编辑器画完一格，hot reload 不重启游戏即生效
