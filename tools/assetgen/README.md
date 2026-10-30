# 角色资源流水线（assetgen）

把「一句描述」变成一套可直接进 Godot 的角色素材：**原画 → 头像 → 四方向待机 → 四方向移动**。
四个步骤都在同一个配置文件里留痕，每一步都能重跑、回退到历史版本、手工微调。

## 依赖

```bash
python -m pip install -r requirements.txt
```

分三层，**按需安装**——核心只要 Pillow + numpy，其余是抠像模型或便利库：

| 层 | 包 | 用途 |
|---|---|---|
| 核心 | Pillow、numpy | 所有读写图、精灵几何、拼表 |
| 去底（静态图） | scipy | 连通域标记（缺失时退回纯 Python BFS，慢但能跑） |
| | onnxruntime | MODNet 推理（CPU 版即可） |
| BiRefNet（边缘最好） | transformers、safetensors、einops、kornia、timm | 需权重 `models/birefnet/`（≈170 MB） |
| RVM（动画序列） | torch、torchvision | 需权重 `models/rvm/`（14.5 MB + 仓库代码） |
| 下载模型 | huggingface-hub | `model-fetch` 与 BiRefNet 权重拉取 |
| 运行时 | tkinter | GUI（CPython 自带；Linux 需 `python3-tk`） |
| 运行时 | ffmpeg / ffprobe | 从 mp4 抽帧，需在 PATH |

**降级行为**：缺 scipy / onnxruntime / torch / transformers 时程序不会崩，
对应的抠像入口返回 `None`，自动退回色键——所以只装上核心那两行也能跑完整个流程。

### 模型下载

| 模型 | 获取方式 |
|---|---|
| MODNet（静态图，24.7 MB） | `python -m assetgen.cli model-fetch` |
| BiRefNet_lite（≈170 MB） | HuggingFace `ZhengPeng7/BiRefNet_lite` → `models/birefnet/` |
| RVM（14.5 MB + 代码） | GitHub `PeterL1n/RobustVideoMatting` release → `models/rvm/` |

`models/` 已 gitignore，换机器需重新下载。

### GPU（可选）

默认 CPU。想要 GPU：把 `torch` 换成 CUDA 轮子即可，代码会自动选设备。

```bash
pip install --upgrade torch --index-url https://download.pytorch.org/whl/cu128
```

实测参考（RTX 2070 SUPER）：BiRefNet 18 s → ~0.3 s，RVM 0.35 s/帧 → ~0.02 s。
注意 `onnxruntime-gpu`（MODNet）还需要本机 CUDA/cuDNN，通常没必要。

## 云端模型

走火山方舟，需要 `ARK_API_KEY`（环境变量、项目 `.secrets.json` 或 Windows 用户变量）：

| 步骤 | 默认模型 | 说明 |
|---|---|---|
| 原画 / 头像 / 四方向拼图 | `doubao-seedream-5-0-flash-260915` | 图生图用 `image` 参考 |
| 待机 / 移动视频 | `doubao-seedance-2-5-260628` | 图生视频，2.0/2.5 不传 `ratio` |
| 提示词改写 / 识图 | `doubao-seed-2-1-lite-260915` | 实测可识图（约 26s/张）；没开通会自动退化为像素测量 |

## 快速开始

```bash
cd tools/assetgen
export PYTHONPATH=$PWD            # Windows: set PYTHONPATH=%CD%

# 1. 建配置
python -m assetgen.cli new --id mara --desc "像素风女骑士，短剑与圆盾，红色披风" --out work/mara/config.json

# 2. 全流程（每一步都会等上一步完成）
python -m assetgen.cli run --config work/mara/config.json --all

# 3. 只跑某几步 / 离线练手
python -m assetgen.cli run --config work/mara/config.json --steps concept,portrait
python -m assetgen.cli run --config work/mara/config.json --all --dry-run

# 4. 改了精灵参数后重新导出（不重新生成视频）
python -m assetgen.cli export --config work/mara/config.json --step walk

# 5. 看状态 / 开 GUI
python -m assetgen.cli show --config work/mara/config.json
python -m assetgen.cli gui  --config work/mara/config.json
```

## 项目配置（project.json）

```jsonc
{
  "name": "amber",
  "style_prompt": "全局风格提示词",
  "style_reference": "references/_project/ref.png",
  "api": {
    "base_url": "https://ark.cn-beijing.volces.com/api/v3",
    "key_env": "ARK_API_KEY",            // 用哪个环境变量
    "image_model": "doubao-seedream-5-0-flash-260915",
    "video_model": "doubao-seedance-2-5-260628",
    "vision_model": "doubao-seed-2-1-lite-260915"
  },
  "step_styles": {                        // 每一步追加到提示词末尾的风格
    "concept": {"prompt": "…", "source": "file:style_note.txt"},
    "walk":    {"prompt": "走路时披风滞后半拍", "source": "manual"}
  }
}
```

**API key 的优先级**：项目设置里填的 key > `key_env` 指定的环境变量 > `ARK_API_KEY` > Windows 用户环境（注册表）。
所以**没配置 API 也能直接跑**，只要环境里有 `ARK_API_KEY`；项目里填了 key 就优先用项目的。
Key 存在 `<work>/.secrets.json`（不写进 `project.json`，记得别提交）。

**分步风格**：`分步风格` 页里每一步都能写一段，也可以点「从文件生成…」——
选图片会用识图模型总结画风，选 `.txt/.md` 会把文档压缩成风格描述，结果存进 `step_styles`。
生成时追加为「风格要求：…」，并随该次运行一起记进历史与 `sprites.json`。

## 项目（work 目录）

一个 work 目录就是一个项目，一个子目录一个角色：

```
work/
  project.json               # 项目级设置：统一风格提示词 + 统一参考图
  references/_project/…      # 项目参考图
  mara/config.json           # 角色：配置 + 历史 + 产物
  neri/config.json
```

- 角色窗口右上角 **项目** 按钮打开项目页：自动列出 work 下所有角色，每行左侧是 **48px 头像缩略图**
  （优先生成好的头像，其次原画，都没有就显示首字母圆形占位），并显示四步状态（✓/·）与最近更新时间。
- **双击一行**（或选中后点「打开所选角色」）进入该角色的四步向导。
- **新建角色**：填 ID + 描述，自动套用项目的统一风格提示词，并把项目参考图写进四个步骤的 `reference`。
- **项目设置**：编辑统一风格提示词、选择统一参考图（复制到 `references/_project/`）。
- 参考图解析是两级的：先找 `<角色目录>/<rel>`，找不到再找 `<work>/<rel>`，所以共享图和专属图可以共存。

CLI 对等：

```bash
python -m assetgen.cli new  --work work --id mara --desc "像素风女骑士"
python -m assetgen.cli list --work work
```

## GUI

左边是四个步骤，右边是当前步骤的**可编辑提示词**、预览、历史版本。

- **下一步 ▶**：当前步没生成就先跑当前步，完成后自动跳到下一步（每步都要手动点）。
- **重新生成本步**：再跑一次，新结果作为新版本进历史，不覆盖旧的。
- **历史版本**：选中任意一条 →「设为当前版本」即可回退。
- **视频生成时有等待动画**：进度条滚动 + 状态栏显示已用秒数（视频通常 2–4 分钟）。
- **模型选择**（每一步）：步骤条右侧的下拉框可选该步使用的模型；默认项跟随
  `provider.image_model` / `provider.video_model`。出图模型启动时会用一次零成本探活
  （非法 size 请求）筛掉未开通的，只列真正可用的；视频模型只列全部候选。
  选择结果写进 `steps.<step>.model`，CLI / GUI 共用。
- **参考图标定**（每一步、生成前可选）：上传一张风格参考图，程序会
  ① 用视觉模型反推画风（像素密度/描边/明暗/配色/背景色）并改写该步提示词，
  ② 用像素测量算出「角色占画面高度」的比例，自动把精灵的 `char_height` 标定到同一比例，
  ③ 改写结果同样受结构守卫保护，丢了 `2 行 2 列` 或占位符就退回测量版。
  参考图存放在 `<工程目录>/references/<step>/`，可随时「重新分析」或「清除」。
- **重新生成**：让模型重写这条提示词（`prompt_model`，没开通时降级为本地变体，来源标 `local-variant`）。
- **更换提示词**：每条提示词上方有「更换提示词」按钮，弹窗里列出
  ① 默认模板（按当前描述实时生成）、② 该提示词的所有历史版本（去重）、
  ③ 同一步骤另一张标签的内容、④ 从 `.txt` 文件导入。
  选中的那条会写进编辑器，来源标签同步更新为 `template` / `history:<step>` / `file:<name>`。
- **精灵微调**（待机/移动步）：
  - 角色高、脚底 y、帧数、周期（0 = 自动探测）
  - 每个方向的 dx / dy 与启用开关
  - 「应用并重新导出」只做图像处理，不会重新调用模型，**不花钱**

## 配置文件

一个角色一个 JSON，是唯一的事实来源：

```jsonc
{
  "character": { "id": "mara", "description": "...", "style": "..." },
  "provider":  { "image_model": "...", "video_model": "...", "vision_model": "...",
                 "resolution": "480p", "duration": 5, "ratio": "auto" },
  "prompts": {                      // ← 当前生效的提示词，全部可编辑
    "concept": "...", "portrait": "...", "grid": "...",
    "idle_video": "...", "walk_video": "..."
  },
  "prompt_sources": {               // template / manual / auto:<step> / measured:<step>
    "portrait": "measured:concept"
  },
  "steps": {
    "concept": {
      "status": "done",
      "current": "20261030-143359-670",
      "history": [
        { "run": "...", "created": "...",
          "prompt": "本次实际使用的提示词",
          "prompts": { "concept": "..." },   // ← 本次真正发出去的每一条
          "params": { "provider": {...} },
          "files": { "image": "concept/2026.../concept.png" },
          "note": "" }
      ]
    }
  },
  "sprites": {
    "idle": { "canvas": [128,128], "char_height": 98, "foot_y": 119, "frames": 4,
              "scale": null, "period": null, "picks": null,
              "directions": { "front_left": {"dx":0,"dy":0,"enabled":true}, ... } }
  }
}
```

**每一次运行用到的提示词都写进该次历史条目**（`entry.prompts`），所以之后就算把
`prompts` 改回来，也能查到当时到底发了什么。

## 提示词自动改写（由上一步产物驱动）

每一步生成完，会自动改写**下一步**的提示词，让它和刚生成的图保持一致：

| 上一步产物 | 改写的提示词 |
|---|---|
| 原画 | `portrait`、`grid` |
| 待机精灵表 | `walk_video` |

两条路径，自动降级：

1. **视觉模型**（开通了就用）：把产物图发给模型，要求"改写成与这张图完全一致的版本"，
   保留格子布局与动作描述，只修正外观细节。
2. **像素测量**（没开通时）：不需要任何调用，直接量出背景色、主色盘、角色包围盒与高宽比，
   追加一句「外观参照上一步产物：背景 #2b3a3a；主色 …；高宽比约 1.03」。
   改写痕迹在 `prompt_sources` 里标成 `measured:<step>`，重新改写会替换旧的那句，不会叠加。

CLI 用 `--no-refine` 关掉，GUI 用顶部的「自动改写下一步提示词」勾选框。

## sprites.json

每次导出都会在该次运行目录里写一份 `sprites.json`，除几何参数外还保留**生成时实际使用的提示词**：

```jsonc
{
  "run": "20261030-160618-151",     // 对应 config.history 里的条目
  "period": 31, "scale": 0.3161, "canvas": [128,128],
  "char_height": 98, "foot_y": 119,
  "prompts": { "walk_video": "画面是 2 行 2 列共 4 个互不干扰的格子…" },
  "provider": { "video_model": "doubao-seedance-2-5-260628", … },
  "frames": { "front_left": ["sprites/front_left/frame_00.png", …] }
}
```

重新导出（`export` 命令或 GUI 的「应用并重新导出」）会沿用该次运行记录的提示词，不会因为后来改了 `prompts` 而丢失出处。

## 去底（含学习式抠像）

先下载模型（24.7 MB，只需一次；int8 量化版会把人像抠成高光，别用）：

```bash
python -m assetgen.cli model-fetch
```

`--method` 可选，默认 `auto`（有模型 → `net`，没模型 → `key`）：

| method | 做法 | 适用 |
|---|---|---|
| `net` | MODNet 出 alpha，只把**与边框连通**的背景强制清零 | ✅ 默认，细节最完整 |
| `key` | 纯色键 + 软 alpha + despill | 无模型时的兜底 |
| `hybrid` | 网络 alpha 与色键取交集 | 想去掉地面投影时 |
| `edge` | 只在色键边界附近用网络 | 半透明边缘 |
| `learned` | 纯网络结果 | 参考 |

实测（像素风女骑士原画）：纯色键会**吃掉**与背景同色的盾牌内嵌纹路、剑刃暗边；
`net` 全保留，且背景无残留。网络会把脚下投影当主体保留——需要干净投影时用 `hybrid`。

原画与头像生成后会自动去底：以四角中位色为背景色，**只删除与边框连通的背景区域**
（深色衣服恰好接近背景色也不会被误删），裁到内容包围盒 + 4px 内边距，输出 RGBA PNG。

- 产物：`concept.png` / `portrait.png`（透明，供预览、缩略图、交付）
- 原始：`concept_raw.png` / `portrait_raw.png`（保留完整画面，作为下一步的参考图）
- 后续步骤引用上一步时**优先用 raw**，避免把透明信息带进参考图
- 想重做去底：`assetgen clean --config ... --step concept`（不会重新调用模型）
- 去底比例异常（<2% 或 >98% 保留）会在日志里警告，说明背景不是纯色

## 精灵导出规则

这些规则是踩坑得出的，写死在 `sprites.py` 里，GUI 与 CLI 行为一致：

- **缩放整条片子只测一次**（参考帧的身体高度），逐帧归一化只会把头发轮廓的噪声当成缩放抖动；
- **每个采样姿势把着地脚钉到地面线**——模型会让整个人上下平移，留着就"飘"；
- **水平锚点固定用参考帧的脚心**，不做逐帧跟踪。

## 边界

- 生成端不做质量判定，"能不能用"要人看；
- 视频模型对"整体上下位移"没有可靠约束，提示词层面解决不了，只能靠导出时的钉地；
- 参考视频输入要求公网 URL（未接入）；纯图片模式试过，模型无法稳定排出多帧动作表，已移除，只保留视频分割；
- 单个角色一次全流程约 ¥10（2.5 视频，4 条 + 3 张图）；`--dry-run` 完全离线、零成本。
