# Amber Bridge / 琥珀桥

一个小规模、暖色欧式幻想佣兵战棋原型：骑士、弓手、法师守住石桥。
角色使用原创候选像素素材，置于受实时光照的 3D 方格战场。中文菜单、剧情头像、存读档与数据型关卡工坊已接入。**这是持续开发的可玩原型，环境美术仍待统一，规则系统为有明确边界的首版实现。**

![Godot 实机截图：新版场景与艺术 HUD](docs/reference-hud-1920x1080.png)

最新 [新版场景、艺术 HUD 与一次点击自动移动](docs/REFERENCE_SCENE_AND_HUD.md)；此前 [参考图对齐、分辨率与光照检查](docs/REFERENCE_ALIGNMENT.md)；此前 [HUD、路线与接触验证记录](docs/HUD_V3_VALIDATION.md)。

截图由 Godot 4.6.3 + OpenGL/Mesa llvmpipe 实际渲染；不是概念图。

## 架构

- **唯一规则**：`logic/battle.lua` 与固定 `logic/rules/*.lua` 模块。Lua 5.4.7、整数坐标/伤害/生命、显式 Park–Miller 随机状态、固定 BFS/单位遍历顺序。
- **桥接**：`native/extension.cpp` 的 `AmberLogic` 把有界字典/整数/布尔/字符串传入 Lua，返回值数据；规则不接触 Godot 对象、动画完成、时钟、文件或网络。
- **调度**：`logic/authority.gd` 给合法行动确定顺序。离线也走同一调度与规则。客户端不预测；收到权威命令后完整执行同一份 Lua。
- **一致性**：严格连续行动号、完整固定规则模块源码 SHA-256、规范数字快照 SHA-256、每条命令执行后校验。固定 16 条日志生成新检查点，重连取检查点 + 尾部命令并逐条执行。
- **网络**：`AmberTransport` 实际调用外部 **fsnet::Node** 的 RPC、连接与主线程 poll。不是模拟网络。首版只监听 `127.0.0.1`，两个本地客户端合作控制同一支队伍；先到的合法命令生效，过期命令被拒绝。
- **表现**：GDScript `main.gd` 只处理输入、模型/像素纹理、界面与状态显示。没有第二份战斗规则。地形查询用于展示，合法性最终由 Lua 决定。

这是一个独立的纯 Lua reducer 适配器，**没有复制 fsnet 的 entity.lua，也没有绑定其完整实体/预测 API**。目前复用的是 fsnet 传输；共享规则的服务端/客户端由本项目相同 Lua VM 适配器执行。

## 首次打开 / 新游戏无法进入

**这是 Godot 源码项目，不是独立 EXE。** Lua 战斗规则和 fsnet 网络都由原生 GDExtension 提供。仓库现在附带 Windows x86_64 候选运行库，参见 [Windows 使用与校验](docs/WINDOWS_RUNTIME.md)。缺少它时，新游戏现在显示明确说明而不是按钮无响应。

- 已验证环境：Linux x86_64、Godot 4.6.3。先完成下面构建，再重启编辑器。
- 若已构建仍失败，检查 Godot 输出中的 GDExtension 错误和 `ldd bin/libamber.so`，确认外部 `libfsnet.so` 仍在构建路径。
- Windows x86_64：无需编译器；完整 clone 后用官方 Godot 4.6.3 标准版打开项目。DLL 架构及依赖已静态校验，但 Windows 启动尚未实测。macOS 暂无原生运行库。
- 无需为这个问题删除存档；不要用其他规则实现代替 Lua。

## 构建（已验证 Linux x86_64）

需要 Godot **4.6.3**、C++20 编译器、CMake >= 3.22、Ninja、Python 3、Git。
Linux 原生扩展仍需本地构建，再在 Godot 导入 `project.godot`；Windows 的候选 DLL 已单独版本化。

外部源目录：

1. 官方 [godot-cpp](https://github.com/godotengine/godot-cpp/tree/507ed9d840c01a3c5b2a39af8bb4000bfac30bf5)，标签 `10.0.0-stable`，提交 **507ed9d840c01a3c5b2a39af8bb4000bfac30bf5**。CMake 指定目标 API 4.6，启用 C++ 异常以在 ABI 边界捕获。
2. 官方 [Lua 5.4.7](https://github.com/lua/lua/tree/v5.4.7) 未修改源码。该 GitHub tag tarball SHA-256：`5c39111b3fc4c1c9e56671008955a1730f54a15b95e1f1bd0752b868b929d8e3`。
3. 外部 [fsnet](https://github.com/frodosens/fsnet) checkout 与已构建 `libfsnet.so`。公开基线 **8e4af0c9b73445d999a9e3593c1429c63bbec882**；按该仓库构建说明准备依赖。示例 `cmake -S /path/fsnet -B /path/fsnet/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DFSNET_WITH_LUA=OFF`，随后 `cmake --build /path/fsnet/build --target fsnet`。本项目自己嵌入同版 Lua，无需依赖 fsnet 的 Lua 私有符号。

```sh
export GODOT_CPP_DIR=/absolute/path/godot-cpp
export LUA_SOURCE_DIR=/absolute/path/lua
export FSNET_SOURCE_DIR=/absolute/path/fsnet
export FSNET_LIBRARY=/absolute/path/fsnet/build/libfsnet.so
./tools/setup-linux.sh
./tools/test.sh
```

`setup-linux.sh` 检查现有工具，构建原生桥、导入资源并验证菜单；不安装编译器或 SDK。如不指定 `FSNET_LIBRARY`，它会先构建外部 fsnet（其 CMake 会联网获取固定依赖）。依赖源目录须自行按上面的官方版本准备。没有编译环境的用户目前仍需等待可玩发行包，不能只靠 clone 运行。

构建生成 `bin/libamber.so`，通过构建 RUNPATH 定位外部 libfsnet。移动外部库后请重新构建或设置 `LD_LIBRARY_PATH`。此处不提供未经验证的 Windows/macOS 包；对应平台需要分别编译并配置 `.gdextension`。

若运行环境 HOME 不可写，可将 `XDG_DATA_HOME`、`XDG_CONFIG_HOME`、`XDG_CACHE_HOME` 指向自己可写的临时目录。

## 玩一局

```sh
godot --path .
```

点我方角色选中，`Enter` 打开菱形指令；`M/A/S/I` 分别移动/攻击/技能/道具，`1/2/3` 仍兼容。移动悬停显示共享 Lua BFS 的实际路线；点击确认。
骑士技能点击自己恢复 3 HP；弓手技能增加射程与伤害；法师技能范围攻击。
默认每轮每人一次移动 + 一次行动；装备可增加移动次数。技能按内容定义消耗、次数与冷却。伤害有显式固定 RNG 的 0/1 加成；普攻及定身法术默认每段 10% 暴击、150% 倍率，整型结算。
空格结束我方回合，敌方按确定性规则移动/攻击。击败所有敌人胜利，队伍全灭失败。`R` 重开离线局。

本地联机（同一机器三个终端，使用同一个临时 token）：

```sh
# 在三个终端各设置同一值；不要将实际 token 提交到 Git。
export AMBER_TOKEN='replace-with-a-local-random-secret-at-least-16-chars'
godot --headless --path . --script res://server.gd -- --port=27840
# 另外两个终端分别运行：
godot --path . -- --connect=27840
```

两客户端合作操作同一队伍。界面显示行动号和状态哈希。断线时不会盲目重发可能已执行的命令；重连后从服务器的快照和日志恢复，并以服务器确认的请求号继续。当前不支持服务器重启后续局：服务器内存状态丢失时，已有客户端拒绝向旧行动号倒退，应重新开局。联机 `R` 不会擅自重置全局战斗。

## 验证与边界

执行 `./tools/test.sh`：跨语言类型/错误/预算/生命周期；三 VM 完整胜负流程、非法/重复命令、快照/哈希；场景拾取输入；三个独立进程通过真实 fsnet RPC 同步并断线重连。
详见 [实际验证记录](docs/VALIDATION.md) 和 [架构边界](docs/ARCHITECTURE.md)。

没有公网、身份账户、持久化房间服务、服务端存档持久化、掉线托管、预测回滚或反作弊；token 仅用于受信任本机演示，不是玩家身份。没有移动端、Windows、macOS 或跨 CPU/编译器确定性验收。没有下载导出模板或生成独立可执行发行包。

## 来源与许可

保留仓库原有 MIT LICENSE。本项目新增代码与程序化占位图形使用该许可。
第三方源码/库不随仓库或项目 ZIP 分发：godot-cpp 与 Lua 为 MIT 类许可，详见各自上游；fsnet 在本次检查的公开基线未见顶层 LICENSE，因此仅作外部依赖引用，不复制或再分发其源码/二进制。实际产品分发前需由权利人明确许可。

## 当前功能与边界

主菜单提供新游戏、存档列表、网络房间与退出；局内暂停可保存/返回。存档绑定完整规则和内容哈希，包含 RNG、行动号、技能冷却/次数、装备/掉落结果、消耗品和本地剧情阅读位置。当前数字快照 v5；旧版本明确拒绝，不静默迁移。网络房间仍限本机，在线本地存档禁用并提示。

- 技能：数据定义目标关系、射程/视线、法力、冷却、次数及受限伤害/治疗效果。原有重整/强射/余烬保留；新增凝神光矢（2 法力、2 回合冷却、需要原地施放）。技能列表选择后点击目标；道具可使用共用药房绷带，消耗行动与库存。
- 装备：旅程菜单进入九槽整备。普通/魔法/稀有/独特、底材/词缀、两件套与胜利掉落均由内容表驱动。疾行增加一次移动行动（不增加距离，额外次数上限1）；行咒允许移动后施放凝神光矢。第一次战斗行动后锁定穿脱，战后重新开放；穿脱不恢复生命或次数。只是少量示例内容，不是暗黑级内容量。
- AI：玩家/AI 控制器与阵营分开。进攻、防守范围、治疗支援、跟随护送为有界确定性策略；都调用共同合法行动管线，并按稳定 ID 排序。不是最优战术 AI。
- 目标：有界 all/any 组合、消灭/保护/到达/生存；同时满足时失败优先。
- 工坊：地图地形/出生点绘制，单位/AI、技能/效果、道具、装备/词缀/掉落、剧情及目标表单；复杂结构可用 JSON 编辑。引用/大小/桥接预算验证后保存到用户目录，支持重载试玩；不执行外部脚本。
- 演出：玛拉突刺、芬恩射箭、奈莉施法对奥伦受击支持加速/跳过，只消费结算事件。每位攻击者8个关键帧组成24tick，独立箭/魔法层；不是24独立帧。其他受击者和敌方攻击动作仍缺失。

已接入批准的克制像素 UI v2：无字背景、原生菜单按钮、艺术面板纹理；地图接入环境材质、石桥侧面和斜屋顶。仍是小规模原型，不代表全美术发布验收。用户最新要求角色与斜俯视地图一致：`iso4` 清单目前只有玛拉四向站立和右前四帧行走，其余仍保留旧视角候选，不能算最终完成；缺少行走方向不会混用旧图或伪装成动画。朝向、路径插值、动画时钟不进入共享规则哈希。

网络菜单可选用户目录的有效 Mod；双方内容哈希必须相同。命令行服务器也可通过 `AMBER_MOD=/absolute/path/content.json` 加载经过相同校验的内容。详情与当前验收缺口见 [材质与动画增量](docs/ART_ANIMATION_INCREMENT.md)。

详见 [核心增量验证](docs/CORE_SYSTEMS_INCREMENT.md)、[先前 UI 验证](docs/UI_STORY_INCREMENT.md)、[战斗模块边界](docs/BATTLE_ARCHITECTURE.md)。

## 当前地图移动表现

全部六个角色移动时使用对应方向的静态待机图，沿共享 Lua 返回的完整路径平滑平移，拐弯切朝向，停止保持最后朝向。没有走路逐帧、IK、呼吸、跳跃或身体摆动；历史动画素材和试验保留供追溯，不是当前运行方案。近景战斗动画、受光、阴影和血条保持。相关实测见 [静态朝向移动](docs/DIRECTIONAL_IDLE_SLIDE.md)。

完整玩家流程与终局存读档 UI 实测见 [玩家流程验证](docs/PLAYER_LOOP_VALIDATION.md)。

移动／行动菜单参考对齐、双分辨率对照与选择动画见 [本轮菜单验证](docs/ACTION_MENU_REFERENCE_PASS.md)。
