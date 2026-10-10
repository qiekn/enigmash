# ENIGMASH (Jai rewirte)

![jacklance](https://github.com/user-attachments/assets/c5cb81a2-069e-4f31-8db4-6c126de24043)

[orig]: https://www.puzzlescript.net/play.html?p=jacklance/enigmash

# Build

```jai
jai first.jai - release
```

## Source layout

- `src/core/`: rendering and audio APIs, textures, fonts, camera math, asset package.
- `src/game/`: puzzle simulation, sessions, input, menus and game-specific assets.
- `src/game/render/`: world drawing, HUD and visual effects, shared with the editor.
- `src/editor/`: level editing and editor UI.
- `src/tas/`: internal-input recording, editable timeline and snapshot storage.
- `src/terminal/`: in-game command console and TAS panel rendering.
- `src/main.jai`: application setup, event routing and frame loop.

Core APIs take explicit resources and camera instances. Game and editor code own
their state and use these APIs; backend calls stay inside core.

## TAS 录制编辑器

终端和时间线参考 `ootss-cmd`，使用 Meslo Nerd Font、Naysayer 配色和半透明背景。
录制编辑器在底部居中浮动，时间线区分已执行和未来输入，按钮与方向使用 Nerd Font 图标；
鼠标悬停按钮可以查看操作说明。
按 `F1` 或 `:` 打开终端，`;` 打开底部快捷输入，`Esc` 关闭终端。
命令不区分大小写，支持历史记录（上下键）、Tab 命令补全、Ctrl+V 粘贴。
`help` 查看全部命令；滚轮或 PageUp/PageDown 滚动输出。

1. 输入 `editor` 打开 TAS 面板，新录制从当前关卡的游戏开局开始（跳过开场说明）。
2. 按 `F8` 或点 **Rec** 开始录制，用 **WASD** 操作，再按 `F8` 停止。
3. 点 **Start** 回到录制起点，点 **Play** 播放；**Back / Step** 逐步后退/前进。空格不切换播放。
4. 点 **Save** 或按 `Ctrl+S`，首次保存时在快捷输入里填写 `save my_run` 并回车。
5. 以后用 `editor my_run` 打开记录，或在已打开的编辑器中用 `load my_run` 加载。

未录制时，WASD 会插入时间线。点击时间线定位游戏，左右拖动滑动时间线并定位，
在面板上滚轮逐步定位；这些操作会停止录制。左右键移动编辑光标，Shift+拖动或
Shift+左右键选择，Delete/Backspace 删除，Ctrl+A 全选、Ctrl+C 复制、Ctrl+V 粘贴。
`Enter` 定位到编辑光标，Ctrl+点击也可以直接定位。
`Z` 后退一步，未来步骤保留，继续录制会从播放头插入新操作。
已执行回合使用可逆差分缓存，撤销和再次定位无需重跑规则；首次定位未来步骤分帧计算，
期间可以继续拖动改变目标。修改步骤会退回未修改的前缀并清除受影响的未来缓存。

常用命令：

```text
editor                打开/恢复当前录制编辑器
editor new            从当前关卡的游戏开局建立新录制
record                开始录制
insert W3ASD          插入 WWWASD
rewind                回到录制起点
play                  从播放头播放；到末尾后再次播放会从头开始
do                    隐藏终端和编辑器，从头播放当前录制
do my_run             隐藏界面，播放已保存的录制
do W3ASD -delay 75     从当前游戏状态播放 WWWASD，最短步间隔 75ms
seek 10               定位到第 10 步之后
speed 75              每步最短间隔 75ms（仍会等待自动连锁）
save my_run           保存录制
load my_run           加载录制
export                复制完整 WASD 序列
list                  列出保存的录制
editor close          返回原游戏，录制仍保留在内存
```

记录的是游戏实际接受的回合，长按产生的有效重复也会记录。自动连锁期间被忽略的
输入、取消的移动和无效果的按键不生成幽灵步骤。方向键的移动也统一记录为 WASD；
`X` 表示行动/关闭消息，`R` 表示重开到检查点。镜头控制不进入记录。

录制保存在 `bin/save/tas/<name>.tas`，包含起点完整状态、检查点和按键序列，
新录制的起点不受当前战役存档位置影响。加载已有记录时保留文件中的起点；
加载要求关卡内容匹配，文件不会替换关卡。
TAS 使用独立游戏会话，关闭面板后恢复原游戏，录制和回放不会写入战役存档。
关闭面板会保留未保存记录，退出程序前需手动保存。
`editor new` / `load` 会保护未保存的记录；明确要丢弃时使用 `editor new!` / `load! name`。
关卡编辑器里请先按 `F5` 开始试玩，再打开 TAS。

## 无编辑器播放（速通录屏）

在终端输入 `do my_run` 或 `do W3ASD -delay 75`，按 **Enter** 提交后自动隐藏终端和
TAS 编辑器。**Esc 停止播放**，画面保留在停止位置；自然播放完毕也不弹出面板。
重新打开终端或窗口失去焦点同样停止播放。

播放时可用 **Tab** 切换跟随/自由镜头，**Space** 平滑定位到当前玩家（两种镜头模式均可，
不改变跟随开关，也不向 TAS 注入游戏操作）。自由镜头用方向键平移，滚轮缩放。
普通游戏也使用同一套相机控制；消息框和通关画面仍保留空格原有的确认作用。
跟随时，玩家在屏幕中央 70% 的区域内移动不会推动镜头；进入四边各 15% 的范围后，
镜头才平滑移动到足以把玩家留在该区域边界的位置，不会持续拉回正中央。
区域比例随窗口和缩放自动计算，可用 `CAMERA_FOLLOW_DEAD_ZONE` 调整。

`do` 不带参数时从当前录制的起点播放完整序列，`do my_run` 从保存文件中的起点播放；
直接输入 WASD 脚本则从当前显示的游戏状态开始。名称与脚本重名时优先读取保存的录制。
可在脚本或名称前后加 `-delay 1..10000`，单位为毫秒；仍会等待游戏自动连锁完成。
录制文件沿用保存的速度，直接输入脚本默认间隔为 150ms。播放不修改编辑器里的录制，
也不写入战役存档；停止后可以继续手动操作当前画面。

## 局部规则更新

默认启用原版 PuzzleScript 的 `local_radius 17`：每个 tick 开始时根据逻辑 CAMERA
确定范围，普通规则仅匹配 `[camera - 17, camera + 17)` 内的格子，地图边缘会裁剪。
显示镜头的平移、缩放不改变范围；显式 `global` 规则（例如世界传播、翻转波和连接）
仍处理全图，保持原版的局部/全局行为。

## TAS checks

```powershell
jai -quiet tests/tas.jai
.\.build\tas_tests.exe
jai -quiet tests/tas_view.jai
.\.build\tas_view_tests.exe
jai -quiet tests/local_rules.jai
.\.build\local_rules_tests.exe
```

The TAS checks cover recording, ghost-input filtering, cached undo/redo, incremental
seeking, dragging, timeline edits, snapshot round-trips, malformed files, hidden
`do` playback, Esc interruption, console routing and campaign isolation.
The view check renders `.build/tas-*.png` and `.build/do-playback.png` using a temporary
hidden window. The local-rule check covers scope boundaries, pattern edges, logical
camera movement, nearby/distant gravity and global rules. No test writes campaign saves.

## Other checks

```powershell
jai -quiet tests/camera.jai
jai -quiet tests/session_audio.jai
.\.build\camera_tests.exe
.\.build\session_audio_tests.exe
```
