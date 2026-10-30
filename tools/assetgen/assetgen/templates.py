"""Prompt templates. Every string is data so the GUI can show and edit it.

The grid prompt is the one that actually worked in practice: it names the cell
count, states that the cells do not interact, names the facing of every single
cell, and gives the body-part verbs explicitly. Vague adjectives do not move the
model; concrete per-cell layout does.

Every step - concept, portrait, turnaround grid and both animations - has to sit
on the *same* flat key colour, because that colour is what the matting step keys
out. Cyan is used by default: fantasy palettes rarely contain it, so the key is
unambiguous even for a dark teal cape.
"""
from __future__ import annotations

FACING_TEXT = {
    "front_left": "朝左前方",
    "front_right": "朝右前方",
    "back_left": "朝左后方（背对镜头，身体偏左）",
    "back_right": "朝右后方（背对镜头，身体偏右）",
}

# The key colour. Changed at run time from config["background"].
BG_HEX = "#00ffff"
BG_NAME = "青"


AUTO_BACKGROUND = ("", "auto")


def set_background(hex_value: str | None) -> None:
    """Point every template at the project's key colour.

    An empty value (or "auto") means: don't dictate a colour at all - just demand
    a flat, high-contrast backdrop. The colour is then measured from the result
    and reused by the following steps.
    """
    global BG_HEX, BG_NAME, BACKGROUND_CLAUSE
    value = (hex_value or "").strip()
    if value.lower() in AUTO_BACKGROUND:
        value = ""
    if value == BG_HEX:
        return
    BG_HEX = value
    BG_NAME = _name_of(value) if value else "自动"
    BACKGROUND_CLAUSE = _clause()


def _name_of(hex_value: str) -> str:
    if not hex_value:
        return "自动"
    known = {"#00ffff": "青", "#ff00ff": "品红", "#00ff00": "绿", "#0000ff": "蓝",
             "#ff8800": "橙", "#000000": "黑", "#ffffff": "白", "#2b3a3a": "深灰绿"}
    return known.get(hex_value.lower(), hex_value)


def _clause() -> str:
    if not BG_HEX:
        return (
            "背景必须是单一纯色，铺满整个画面、不留渐变，颜色要与角色配色形成强烈对比"
            "（不要接近角色身上的任何主色）；不要地面、不要投影、不要边框、不要场景道具；"
            "角色轮廓与背景之间要有清晰边界。"
        )
    return (
        f"背景必须是单一纯色 {BG_HEX}（{BG_NAME}），铺满整个画面、不留渐变；"
        "不要地面、不要投影、不要边框、不要场景道具；角色轮廓与背景之间要有清晰边界。"
    )


BACKGROUND_CLAUSE = _clause()

GRID_LAYOUT = "左上格：朝左前方；右上格：朝右前方；左下格：朝左后方；右下格：朝右后方。"


def background_sentence() -> str:
    if not BG_HEX:
        return "背景为单一纯色，四格背景颜色完全一致、不要渐变，且与角色配色形成强烈对比。"
    return f"背景为纯{BG_NAME}色 {BG_HEX}，四格背景颜色完全一致、不要渐变。"


def concept(c: dict) -> str:
    return (
        f"{c['description']}。{c['style']}。全身站立，角色居中，单个人物，"
        "完整包含头到脚，不要裁切，不要文字、不要边框、不要水印。"
        + BACKGROUND_CLAUSE
    )


def portrait(c: dict) -> str:
    return (
        f"{c['description']}。同一角色的头像（半身像），{c['style']}。"
        "正面略侧的四分之三视角，头部占画面主要部分，不要文字、不要边框、不要水印。"
        + BACKGROUND_CLAUSE
    )


def turnaround_grid(c: dict) -> str:
    return (
        f"画面是 2 行 2 列共 4 个互不干扰的格子，每格都是同一个角色：{c['description']}。"
        f"{c['style']}。{background_sentence()}四格等大，每格角色居中站立、姿势相同、只是朝向不同。"
        f"{GRID_LAYOUT}"
        "每格角色都留在自己格子中央，不越界、不重叠、不跨格；四格人物大小一致、比例一致。"
    )


def idle_video(c: dict) -> str:
    return (
        "画面是 2 行 2 列共 4 个互不干扰的格子，每格都是同一个角色，"
        f"{background_sentence()}镜头完全固定。"
        f"{GRID_LAYOUT}"
        "四格里同时做原地待机循环——只有轻微呼吸起伏，胸口与肩膀有细微上下，"
        "角色的位置、朝向、大小始终不变，脚不移动。"
        "每格角色都留在自己格子中央，不越界、不重叠、不跨格；像素美术风格与首帧一致。"
    )


def walk_video(c: dict) -> str:
    return (
        "画面是 2 行 2 列共 4 个互不干扰的格子，每格都是同一个角色，"
        f"{background_sentence()}镜头完全固定。"
        f"{GRID_LAYOUT}"
        "四格里同时做原地行走循环——膝盖抬起、小腿前摆、双脚交替落地，步幅清楚可见；"
        "手臂自然前后摆动，幅度适中；身体位置不移动、不转身、不改变面朝角度；"
        "每格角色都留在自己格子中央，不越界、不重叠、不跨格；像素美术风格与首帧一致。"
    )


POSES = {
    "idle": ["站直、双脚并拢，只有轻微呼吸", "站直、肩膀略微下沉", "站直、胸口略微抬起", "站直、回到起始"],
    "walk": ["左腿向前迈出、右腿在后", "双脚收拢过渡、身体略微下沉", "右腿向前迈出、左腿在后", "双脚收拢过渡、回到起始"],
}


def single_frame(character: dict, kind: str) -> str:
    """One image, one character, one pose - no in-image layout to get wrong."""
    return (
        "一张像素风角色立绘：{character}。全身，居中站立，脚完整可见。"
        "朝向：{direction}。动作：{pose}。"
        + (f"背景为纯{BG_NAME}色 {BG_HEX}，" if BG_HEX else "背景为单一纯色，与角色配色形成强烈对比，")
        + "角色占画面高度约七成，居中留白；"
        "不要文字、不要边框、不要水印、不要多个角色、不要分格。"
    )


def frame_grid(character: dict, kind: str) -> str:
    """One 2x2 image per frame: the four facings of a single pose."""
    return (
        f"画面是 2 行 2 列共 4 个互不干扰的格子，每格都是同一个角色，"
        f"{background_sentence()}镜头完全固定。"
        f"角色：{character['description']}。{character['style']}。"
        "左上格：朝左前方；右上格：朝右前方；左下格：朝左后方；右下格：朝右后方。"
        "这是同一个动作循环里的第 {frame} 帧（共 {frames} 帧），四格的动作相位完全相同：{pose}。"
        "四个格子的人物大小一致、脚底踩在同一高度、朝向各自固定，不越界、不重叠、不跨格；"
        "像素美术风格保持一致，不要文字、不要边框、不要水印。"
    )


def strip(character: dict, kind: str) -> str:
    """One image per direction holding N consecutive poses in a grid.

    Placeholders kept literally so the editable prompt stays readable:
    {direction} {frames} {cols} {rows}
    """
    action = "原地待机循环（只有轻微呼吸起伏，脚不移动）" if kind == "idle" else \
        "原地行走循环（膝盖抬起、小腿前摆、双脚交替落地，手臂自然前后摆动）"
    facing_lock = "" if kind == "idle" else (
        "注意：所有格子的朝向必须完全一致，只有四肢位置在变；不要转动角色、不要出现背面或侧面、"
        "不要做成转圈圈或视角旋转；身体位置也不能前后左右移动。")
    return (
        "一张角色动作表：{rows} 行 {cols} 列共 {frames} 个格子，从左到右、从上到下是同一个角色的连续动作帧。"
        f"角色：{character['description']}。{character['style']}。"
        "每格角色朝向完全一致：{direction}；每格角色大小一致、脚底踩在同一高度，"
        "帧与帧之间只有四肢和身体的微小变化，形成平滑的循环。"
        + (f"背景为纯{BG_NAME}色 {BG_HEX}，" if BG_HEX else "背景为单一纯色，")
        + "格子之间留少量空隙，不重叠不跨格，整体构图整齐。"
        f"{facing_lock}"
        "不要文字、不要边框、不要水印。"
    )


BUILDERS = {
    "concept": concept,
    "portrait": portrait,
    "grid": turnaround_grid,
    "idle_video": idle_video,
    "walk_video": walk_video,
}
