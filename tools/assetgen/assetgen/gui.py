"""Tkinter wizard for the four-step character pipeline.

Layout: header / character bar / (sidebar + content) / status / log, gridded so
nothing gets pushed out of the window at the minimum size. Visual helpers
(card, button, step row) keep one spacing rhythm and one palette.
"""
from __future__ import annotations

import json
import queue
import shutil
import threading
import time
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from PIL import Image, ImageDraw, ImageTk

from . import analyze, ark, config, pipeline, project, sprites, templates

analyze.preload_msvc_runtime()

PROMPTS_FOR_STEP = {
    "concept": [("concept", "原画提示词")],
    "portrait": [("portrait", "头像提示词")],
    "idle": [("grid", "四方向拼图"), ("idle_video", "待机视频")],
    "walk": [("walk_video", "移动视频")],
}

BG = "#f2f3f5"
CARD = "#ffffff"
SOFT = "#f7f8fa"
BORDER = "#e2e5e9"
TEXT = "#1f2328"
MUTED = "#6b7280"
ACCENT = "#b45309"
ACCENT_SOFT = "#fdf1e5"
OK = "#2f7d43"
PENDING = "#9aa1aa"

F_UI = ("Microsoft YaHei UI", 10)
F_BOLD = ("Microsoft YaHei UI", 10, "bold")
F_TITLE = ("Microsoft YaHei UI", 11, "bold")
F_H1 = ("Microsoft YaHei UI", 14, "bold")
F_SMALL = ("Microsoft YaHei UI", 9)
F_MONO = ("Consolas", 9)

PREVIEW = 296


def card(parent, title: str | None = None, pad: int = 12):
    outer = tk.Frame(parent, bg=BORDER)
    inner = tk.Frame(outer, bg=CARD, padx=pad, pady=pad)
    inner.pack(fill="both", expand=True, padx=1, pady=1)
    body = inner
    if title:
        tk.Label(inner, text=title, bg=CARD, fg=TEXT, font=F_TITLE, anchor="w").pack(fill="x", pady=(0, 8))
        body = tk.Frame(inner, bg=CARD)
        body.pack(fill="both", expand=True)
    outer.body = body
    return outer


def button(parent, text, command, kind="secondary", **kw):
    bg, fg, active = {
        "primary": (ACCENT, "#ffffff", "#8f4207"),
        "secondary": ("#eceef1", TEXT, "#e0e3e7"),
        "ghost": (CARD, MUTED, "#f0f1f3"),
    }[kind]
    return tk.Button(parent, text=text, command=command, bg=bg, fg=fg, activebackground=active,
                     activeforeground=fg, relief="flat", bd=0, padx=14, pady=6,
                     font=F_BOLD if kind == "primary" else F_UI, cursor="hand2",
                     highlightthickness=0, **kw)


def field(parent, label, var, width=18):
    wrap = tk.Frame(parent, bg=CARD)
    tk.Label(wrap, text=label, bg=CARD, fg=MUTED, font=F_SMALL, anchor="w").pack(fill="x")
    tk.Entry(wrap, textvariable=var, width=width, relief="flat", bg=SOFT, fg=TEXT, font=F_UI,
             insertbackground=ACCENT).pack(fill="x", ipady=3, pady=(1, 0))
    return wrap


def checker(size: int) -> Image.Image:
    tile = 12
    img = Image.new("RGB", (size, size), "#ffffff")
    px = img.load()
    for y in range(size):
        for x in range(size):
            if ((x // tile) + (y // tile)) % 2:
                px[x, y] = (238, 240, 243)
    return img


class App(tk.Tk):
    def __init__(self, config_path: str):
        super().__init__()
        self.title("角色资源流水线")
        self.configure(bg=BG)
        self.geometry(self._centered(1360, 900))
        self.minsize(1140, 780)

        self.path = Path(config_path).resolve()
        self.cfg = config.load(self.path)
        pipeline.ensure_prompts(self.cfg)
        config.save(self.cfg, self.path)
        self.current_step = config.STEPS[0]
        self.q: queue.Queue = queue.Queue()
        self.busy = False
        self.job_started = 0.0
        self.job_label = ""
        self._photo = None
        self.prompt_widgets: dict[str, tk.Text] = {}
        self.source_labels: dict[str, tk.Label] = {}
        self.thumbs: dict[str, object] = {}
        self.models = {"image": [], "video": []}
        self.models_loaded = False
        self.step_rows: dict[str, dict] = {}
        self.detail = None

        self._style()
        self._layout()
        self.select_step(self.current_step)
        self.bind("<Control-o>", lambda _e: self.on_open())
        self.log("就绪 · 选中左侧步骤，点「下一步」开始生成")
        try:
            api = project.apply_api(self.work_dir())
            self.log(f"API：{ark.base_url()} · 密钥来源：{api.get('key_source', '?')}")
            runtime = analyze._RUNTIME_STATE.get("path") or "未加载"
            self.log(f"抠像运行库：{runtime}")
            self.log(f"抠像设备：{analyze.device_name()}")
        except Exception as exc:
            self.log(f"项目 API 设置未应用：{type(exc).__name__}")
        self.ensure_models()
        self._poll_id = self.after(150, self._poll)

    # ------------------------------------------------------------- chrome
    def _centered(self, w, h):
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        return f"{w}x{h}+{max(0, (sw - w) // 2)}+{max(0, (sh - h) // 3)}"

    def _style(self):
        s = ttk.Style(self)
        s.theme_use("clam")
        s.configure("TNotebook", background=CARD, borderwidth=0)
        s.configure("TNotebook.Tab", padding=(16, 6), font=F_UI, background="#eceef1",
                    foreground=MUTED, borderwidth=0)
        s.map("TNotebook.Tab", background=[("selected", CARD)], foreground=[("selected", ACCENT)])
        s.configure("Treeview", background=CARD, fieldbackground=CARD, rowheight=26,
                    font=F_UI, borderwidth=0)
        s.configure("Treeview.Heading", font=F_SMALL, foreground=MUTED, background=CARD, borderwidth=0)
        s.map("Treeview", background=[("selected", ACCENT_SOFT)], foreground=[("selected", TEXT)])
        s.configure("Project.Treeview", background=CARD, fieldbackground=CARD, rowheight=56,
                    font=F_UI, borderwidth=0)
        s.configure("Project.Treeview.Heading", font=F_SMALL, foreground=MUTED, background=CARD,
                    borderwidth=0)
        s.map("Project.Treeview", background=[("selected", ACCENT_SOFT)],
              foreground=[("selected", TEXT)])
        s.configure("Accent.Horizontal.TProgressbar", troughcolor="#eceef1", background=ACCENT,
                    borderwidth=0, thickness=8)
        s.configure("TSpinbox", padding=2)

    def _layout(self):
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)
        self._header().grid(row=0, column=0, sticky="ew")
        self._charbar().grid(row=1, column=0, sticky="ew", padx=14, pady=(12, 0))
        self._body().grid(row=2, column=0, sticky="nsew", padx=14, pady=12)
        self._status().grid(row=3, column=0, sticky="ew", padx=14)
        self._logpanel().grid(row=4, column=0, sticky="ew", padx=14, pady=(6, 14))

    def _header(self):
        head = tk.Frame(self, bg=ACCENT, height=62)
        head.pack_propagate(False)
        tk.Label(head, text="角色资源流水线", bg=ACCENT, fg="#ffffff", font=F_H1).pack(
            side="left", padx=(18, 12), pady=14)
        tk.Label(head, text="原画 → 头像 → 待机 → 移动", bg=ACCENT, fg="#fbe3cc",
                 font=F_SMALL).pack(side="left", pady=14)
        right = tk.Frame(head, bg=ACCENT)
        right.pack(side="right", padx=14)
        self.path_var = tk.StringVar(value=str(self.path))
        tk.Label(right, textvariable=self.path_var, bg=ACCENT, fg="#fbe3cc",
                 font=F_SMALL).pack(side="left", padx=(0, 10))
        for text, cmd in (("项目", self.open_project), ("新建", self.on_new_character),
                          ("设置", self.open_settings), ("保存", self.save_fields)):
            tk.Button(right, text=text, command=cmd, bg="#ffffff", fg=ACCENT, relief="flat", bd=0,
                      padx=14, pady=4, font=F_BOLD, cursor="hand2", activebackground="#fbe3cc",
                      activeforeground=ACCENT).pack(side="left", padx=3)
        return head

    def _charbar(self):
        strip = card(self, pad=10)
        row = tk.Frame(strip.body, bg=CARD)
        row.pack(fill="x")
        self.id_var = tk.StringVar(value=self.cfg["character"]["id"])
        self.name_var = tk.StringVar(value=self.cfg["character"]["display_name"])
        self.desc_var = tk.StringVar(value=self.cfg["character"]["description"])
        field(row, "ID", self.id_var, 12).pack(side="left", padx=(0, 10))
        field(row, "名称", self.name_var, 14).pack(side="left", padx=(0, 10))
        field(row, "角色描述（改完点「保存」再生成）", self.desc_var, 74).pack(side="left", fill="x", expand=True)
        return strip

    def _body(self):
        body = tk.Frame(self, bg=BG)
        body.grid_columnconfigure(0, minsize=252)
        body.grid_columnconfigure(1, weight=1)
        body.grid_rowconfigure(0, weight=1)
        self._sidebar(body).grid(row=0, column=0, sticky="nsew")
        self.pane = tk.Frame(body, bg=BG)
        self.pane.grid(row=0, column=1, sticky="nsew", padx=(12, 0))
        self.pane.grid_columnconfigure(0, weight=1)
        self.pane.grid_rowconfigure(0, weight=1)
        return body

    def _sidebar(self, parent):
        side = tk.Frame(parent, bg=BG)
        box = card(side, "流程")
        box.pack(fill="x")
        for step in config.STEPS:
            self.step_rows[step] = self._step_row(box.body, step)

        actions = tk.Frame(side, bg=BG)
        actions.pack(fill="x", pady=(10, 0))
        self.btn_next = button(actions, "下一步 ▶", self.on_next, "primary")
        self.btn_next.pack(fill="x")
        self.btn_gen = button(actions, "重新生成本步", self.on_generate, "secondary")
        self.btn_gen.pack(fill="x", pady=(6, 0))
        self.btn_reproc = button(actions, "重新处理（不重新生成）", self.on_reprocess, "ghost")
        self.btn_reproc.pack(fill="x", pady=(4, 0))

        opts = card(side, "选项")
        opts.pack(fill="x", pady=(10, 0))
        self.dry = tk.BooleanVar(value=False)
        refined = project.load_settings(self.work_dir()).get("refine", True)
        self.refine = tk.BooleanVar(value=bool(refined))
        self.shadow = tk.BooleanVar(value=bool((self.cfg.get("matte") or {}).get("shadow")))
        for text, var, command in (
                ("离线占位（不花钱）", self.dry, None),
                ("用上一步产物改写提示词", self.refine, self.on_refine_toggle),
                ("去掉脚下投影", self.shadow, self.on_shadow_toggle)):
            tk.Checkbutton(opts.body, text=text, variable=var, bg=CARD, fg=MUTED, font=F_SMALL,
                           activebackground=CARD, selectcolor=CARD, highlightthickness=0,
                           anchor="w", command=command).pack(fill="x")

        method_row = tk.Frame(opts.body, bg=CARD)
        method_row.pack(fill="x", pady=(6, 0))
        tk.Label(method_row, text="去底方法", bg=CARD, fg=MUTED, font=F_SMALL).pack(side="left")
        methods = [("auto", "自动"), ("key", "色键"), ("net", "MODNet"), ("birefnet", "BiRefNet")]
        current_method = (self.cfg.get("matte") or {}).get("method") or "auto"
        self.method_var = tk.StringVar(
            value=dict((k, v) for k, v in methods).get(current_method, "自动"))
        combo = ttk.Combobox(method_row, textvariable=self.method_var, state="readonly", width=9,
                             values=[label for _k, label in methods])
        combo.pack(side="right")
        combo.bind("<<ComboboxSelected>>",
                   lambda _e: self.on_method_change(methods))

        sprite_row = tk.Frame(opts.body, bg=CARD)
        sprite_row.pack(fill="x", pady=(4, 0))
        tk.Label(sprite_row, text="动画去底", bg=CARD, fg=MUTED, font=F_SMALL).pack(side="left")
        sprite_modes = [("key", "色键"), ("rvm", "RVM 序列"), ("birefnet", "BiRefNet 逐帧"),
                        ("learned", "MODNet 逐帧")]
        current_sprite = (self.cfg.get("sprites", {}).get("walk", {}) or {}).get("matte") or "rvm"
        self.sprite_matte_var = tk.StringVar(
            value=dict((k, v) for k, v in sprite_modes).get(current_sprite, "RVM 序列"))
        combo2 = ttk.Combobox(sprite_row, textvariable=self.sprite_matte_var, state="readonly",
                              width=9, values=[label for _k, label in sprite_modes])
        combo2.pack(side="right")
        combo2.bind("<<ComboboxSelected>>",
                    lambda _e: self.on_sprite_matte_change(sprite_modes))

        trim_row = tk.Frame(opts.body, bg=CARD)
        trim_row.pack(fill="x", pady=(6, 0))
        tk.Label(trim_row, text="边缘修剪", bg=CARD, fg=MUTED, font=F_SMALL).pack(side="left")
        self.trim_var = tk.IntVar(value=int((self.cfg.get("matte") or {}).get("trim") or 0))
        tk.Spinbox(trim_row, from_=0, to=3, width=3, textvariable=self.trim_var,
                   relief="flat", bg=SOFT, fg=TEXT, font=F_SMALL, justify="center",
                   command=self.on_trim_change, highlightthickness=0,
                   buttonbackground=SOFT).pack(side="left", padx=(6, 4))
        tk.Label(trim_row, text="px", bg=CARD, fg=MUTED, font=F_SMALL).pack(side="left")
        tk.Label(opts.body, text="切掉模型画在轮廓上的那圈色边", bg=CARD, fg=MUTED,
                 font=F_SMALL, anchor="w", wraplength=190, justify="left").pack(fill="x")
        return side

    def on_method_change(self, methods):
        label = self.method_var.get()
        value = next((k for k, v in methods if v == label), "auto")
        self.cfg.setdefault("matte", {})["method"] = value
        config.save(self.cfg, self.path)
        self.log(f"去底方法 -> {label}（{value}）；对已生成图点「重新处理」生效")

    def on_sprite_matte_change(self, modes):
        label = self.sprite_matte_var.get()
        value = next((k for k, v in modes if v == label), "rvm")
        for step in ("idle", "walk"):
            self.cfg.setdefault("sprites", {}).setdefault(step, {})["matte"] = value
        config.save(self.cfg, self.path)
        self.log(f"动画去底 -> {label}（{value}）；点「重新处理」从视频重切")

    def on_trim_change(self):
        value = max(0, min(3, int(self.trim_var.get())))
        self.cfg.setdefault("matte", {})["trim"] = value
        config.save(self.cfg, self.path)
        self.log(f"边缘修剪 -> {value}px")

    def on_refine_toggle(self):
        settings = project.load_settings(self.work_dir())
        settings["refine"] = bool(self.refine.get())
        project.save_settings(self.work_dir(), settings)
        self.log(f"改写提示词 -> {'开' if self.refine.get() else '关'}（已存入项目设置）")

    def on_shadow_toggle(self):
        self.cfg.setdefault("matte", {})["shadow"] = bool(self.shadow.get())
        config.save(self.cfg, self.path)
        self.log(f"去投影 -> {'开' if self.shadow.get() else '关'}")

    def _step_row(self, parent, step):
        row = tk.Frame(parent, bg=CARD, cursor="hand2")
        row.pack(fill="x", pady=1)
        bar = tk.Frame(row, bg=CARD, width=3)
        bar.pack(side="left", fill="y")
        dot = tk.Label(row, text="●", bg=CARD, fg=PENDING, font=("Segoe UI", 12))
        dot.pack(side="left", padx=(9, 8), pady=5)
        text = tk.Frame(row, bg=CARD)
        text.pack(side="left", fill="x", expand=True)
        title = tk.Label(text, text=config.STEP_TITLES[step], bg=CARD, fg=TEXT, font=F_UI, anchor="w")
        title.pack(fill="x")
        sub = tk.Label(text, text="未生成", bg=CARD, fg=MUTED, font=F_SMALL, anchor="w")
        sub.pack(fill="x")
        for w in (row, dot, text, title, sub):
            w.bind("<Button-1>", lambda _e, s=step: self.select_step(s))
            w.bind("<Enter>", lambda _e, s=step: self._hover(s, True))
            w.bind("<Leave>", lambda _e, s=step: self._hover(s, False))
        return {"row": row, "bar": bar, "dot": dot, "title": title, "sub": sub}

    def _hover(self, step, on):
        if step == self.current_step:
            return
        bg = SOFT if on else CARD
        row = self.step_rows[step]
        for w in (row["row"], row["dot"], row["title"], row["sub"]):
            w.configure(bg=bg)

    def _paint_steps(self):
        for step, row in self.step_rows.items():
            state = self.cfg["steps"][step]
            done = state["status"] == "done"
            row["dot"].configure(fg=OK if done else PENDING)
            row["sub"].configure(text=f"已生成 {len(state['history'])} 版" if done else "未生成")
            current = step == self.current_step
            bg = ACCENT_SOFT if current else CARD
            for w in (row["row"], row["dot"], row["title"], row["sub"]):
                w.configure(bg=bg)
            row["title"].configure(fg=ACCENT if current else TEXT)
            row["bar"].configure(bg=ACCENT if current else CARD)

    def _status(self):
        bar = tk.Frame(self, bg=BG)
        self.status_var = tk.StringVar(value="就绪")
        tk.Label(bar, textvariable=self.status_var, bg=BG, fg=MUTED, font=F_SMALL,
                 anchor="w").pack(side="left")
        self.progress = ttk.Progressbar(bar, mode="indeterminate", length=220,
                                        style="Accent.Horizontal.TProgressbar")
        self.progress.pack(side="left", padx=10, pady=2)
        return bar

    def _logpanel(self):
        box = card(self, pad=8)
        self.log_text = tk.Text(box.body, height=4, bg="#1f2328", fg="#c9d1d9", relief="flat",
                                bd=0, font=F_MONO, wrap="word", padx=10, pady=6,
                                insertbackground="#c9d1d9")
        self.log_text.pack(fill="both", expand=True)
        self.log_text.configure(state="disabled")
        return box

    # ------------------------------------------------------------- details
    def select_step(self, step: str):
        self.current_step = step
        self._paint_steps()
        if self.detail is not None:
            self.detail.destroy()
        self.prompt_widgets = {}
        self.detail = tk.Frame(self.pane, bg=BG)
        self.detail.grid(row=0, column=0, sticky="nsew")
        self.detail.grid_columnconfigure(0, weight=1)
        self.detail.grid_columnconfigure(1, minsize=404)
        self.detail.grid_rowconfigure(0, weight=1)

        left = tk.Frame(self.detail, bg=BG)
        left.grid(row=0, column=0, sticky="nsew")
        right = tk.Frame(self.detail, bg=BG)
        right.grid(row=0, column=1, sticky="nsew", padx=(12, 0))
        right.grid_columnconfigure(0, weight=1)
        right.grid_rowconfigure(1, weight=1)

        if step in ("idle", "walk"):
            self._build_sprite_tuning(left)   # packs to the bottom first
        self._build_prompts(left)
        self._build_preview(right)
        self._build_history(right)

    def _build_prompts(self, parent):
        box = card(parent)
        box.pack(fill="both", expand=True)
        self._build_reference_row(box.body)
        keys = list(PROMPTS_FOR_STEP[self.current_step])
        nb = ttk.Notebook(box.body)
        nb.pack(fill="both", expand=True)
        for key, label in keys:
            frame = tk.Frame(nb, bg=CARD)
            nb.add(frame, text=label)
            foot = tk.Frame(frame, bg=CARD)
            foot.pack(side="bottom", fill="x", padx=8, pady=(0, 8))
            text = tk.Text(frame, wrap="word", relief="flat", bd=0, bg=SOFT, fg=TEXT, font=F_UI,
                           insertbackground=ACCENT, padx=10, pady=8, spacing1=2, spacing3=4,
                           height=10)
            text.insert("1.0", self.cfg.get("prompts", {}).get(key, ""))
            text.pack(side="top", fill="both", expand=True, padx=8, pady=(8, 4))
            self.prompt_widgets[key] = text
            button(foot, "重新生成", lambda k=key, t=text: self.on_regen_prompt(k, t), "secondary").pack(side="left")
            button(foot, "更换提示词", lambda k=key, t=text: self.on_choose_prompt(k, t), "secondary").pack(side="left", padx=4)
            button(foot, "恢复默认", lambda k=key, t=text: self._reset_prompt(k, t), "ghost").pack(side="left", padx=4)
            button(foot, "复制", lambda t=text: self._copy(t), "ghost").pack(side="left")
            source = self.cfg.get("prompt_sources", {}).get(key, "template")
            label = tk.Label(foot, text=f"来源 {source}", bg=CARD, fg=MUTED, font=F_SMALL)
            label.pack(side="right")
            self.source_labels[key] = label

    FALLBACK_MODELS = {
        "image": ["doubao-seedream-5-0-flash-260915", "doubao-seedream-5-0-pro-260628"],
        "video": ["doubao-seedance-2-5-260628", "doubao-seedance-2-0-260128"],
    }

    def ensure_models(self):
        if self.models_loaded or self.busy:
            return

        def work():
            try:
                image = ark.probe_image_models(ark.list_models(("doubao-seedream",)))
                video = ark.list_models(("doubao-seedance",))
                self.q.put(("log", f"可用出图模型 {len(image)} 个，视频模型 {len(video)} 个"))
                self.q.put(("models", {"image": image or self.FALLBACK_MODELS["image"],
                                       "video": video or self.FALLBACK_MODELS["video"]}))
            except Exception as exc:
                self.q.put(("log", f"取模型列表失败（{type(exc).__name__}），用内置候选"))
                self.q.put(("models", dict(self.FALLBACK_MODELS)))

        threading.Thread(target=work, daemon=True).start()

    def models_for(self, step):
        kind = "image" if step in pipeline.IMAGE_STEPS else "video"
        return self.models.get(kind) or self.FALLBACK_MODELS[kind]

    def on_model_change(self, step, value, default_label):
        chosen = "" if value == default_label else value
        self.cfg["steps"][step]["model"] = chosen
        config.save(self.cfg, self.path)
        self.log(f"{step} 模型 -> {chosen or '默认 ' + pipeline.default_model_for(self.cfg, step)}")

    def _build_reference_row(self, parent):
        step = self.current_step
        row = tk.Frame(parent, bg=CARD)
        row.pack(fill="x", pady=(0, 6))
        tk.Label(row, text="参考图", bg=CARD, fg=MUTED, font=F_SMALL).pack(side="left", padx=(0, 8))
        rel = self.cfg["steps"][step].get("reference")
        image = config.resolve_reference(self.path, rel)
        if image and image.exists():
            thumb = Image.open(image).convert("RGB")
            thumb.thumbnail((40, 40), Image.LANCZOS)
            self.thumbs[step] = ImageTk.PhotoImage(thumb)
            tk.Label(row, image=self.thumbs[step], bg=CARD).pack(side="left", padx=(0, 8))
            tk.Label(row, text=image.name, bg=CARD, fg=TEXT, font=F_SMALL).pack(side="left", padx=(0, 8))
        else:
            tk.Label(row, text="未设置（可作为风格/尺寸标定）", bg=CARD, fg=MUTED,
                     font=F_SMALL).pack(side="left", padx=(0, 8))
        step_cfg = self.cfg["steps"][step]
        default_label = "默认：" + pipeline.default_model_for(self.cfg, step)
        choices = [default_label] + self.models_for(step)
        current = step_cfg.get("model") or ""
        var = tk.StringVar(value=current or default_label)
        combo = ttk.Combobox(row, textvariable=var, values=choices, width=36, state="readonly")
        combo.pack(side="right")
        combo.bind("<<ComboboxSelected>>",
                   lambda _e, v=var, d=default_label, st=step: self.on_model_change(st, v.get(), d))
        tk.Label(row, text="模型", bg=CARD, fg=MUTED, font=F_SMALL).pack(side="right", padx=(8, 4))
        button(row, "上传…", self.on_upload_reference, "ghost").pack(side="left")
        if image and image.exists():
            button(row, "重新分析", self.on_analyze_reference, "ghost").pack(side="left", padx=4)
            button(row, "清除", self.on_clear_reference, "ghost").pack(side="left")

    def on_upload_reference(self):
        chosen = filedialog.askopenfilename(
            title="选择风格参考图",
            filetypes=[("image", "*.png;*.jpg;*.jpeg;*.webp"), ("all", "*.*")])
        if not chosen:
            return
        source = Path(chosen)
        target_dir = self.path.parent / "references" / self.current_step
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / source.name
        shutil.copy2(source, target)
        self.cfg["steps"][self.current_step]["reference"] = str(target.relative_to(self.path.parent))
        config.save(self.cfg, self.path)
        self.select_step(self.current_step)
        self.start_calibration()

    def on_analyze_reference(self):
        self.start_calibration()

    def on_clear_reference(self):
        self.cfg["steps"][self.current_step]["reference"] = None
        config.save(self.cfg, self.path)
        self.select_step(self.current_step)
        self.log("已清除参考图")

    def start_calibration(self):
        if self.busy:
            return
        step = self.current_step
        rel = self.cfg["steps"][step].get("reference")
        image = config.resolve_reference(self.path, rel)
        if image is None:
            return
        self.save_fields()
        self.busy = True
        self.job_started = time.time()
        self.job_label = step
        self.btn_next.configure(state="disabled")
        self.btn_gen.configure(state="disabled")
        self.progress.start(14)
        self.status_var.set(f"正在用参考图标定「{step}」…")
        self.log(f"=== 参考图标定 {step} ===")

        def work():
            try:
                cfg = config.load(self.path)
                pipeline.ensure_prompts(cfg)
                result = pipeline.calibrate_from_reference(
                    cfg, self.path, step, image, log=lambda m: self.q.put(("log", m)))
                self.q.put(("calibrated", (step, result)))
            except Exception as exc:
                self.q.put(("error", f"{type(exc).__name__}: {exc}"))

        threading.Thread(target=work, daemon=True).start()
        self._tick()

    def _reset_prompt(self, key, widget):
        widget.delete("1.0", "end")
        widget.insert("1.0", templates.BUILDERS[key](self.cfg["character"]))
        self._set_source(key, "template")

    def _set_source(self, key, source):
        self.cfg.setdefault("prompt_sources", {})[key] = source
        label = self.source_labels.get(key)
        if label is not None and label.winfo_exists():
            label.configure(text=f"来源 {source}")

    def prompt_candidates(self, key):
        """Everything we can swap the current prompt for, newest history first."""
        out = []
        text = templates.BUILDERS[key](self.cfg["character"])
        out.append(("默认模板（按当前描述生成）", text, "template"))
        seen = {text}
        for step in config.STEPS:
            for entry in reversed(self.cfg["steps"][step].get("history", [])):
                value = (entry.get("prompts") or {}).get(key)
                if value and value not in seen:
                    seen.add(value)
                    out.append((f"历史 · {config.STEP_TITLES[step]} · {entry['created'][:16]}", value,
                                f"history:{step}"))
        for other, _label in PROMPTS_FOR_STEP[self.current_step]:
            if other == key:
                continue
            value = self.prompt_widgets.get(other).get("1.0", "end").strip() if self.prompt_widgets.get(other) else ""
            if value and value not in seen:
                seen.add(value)
                out.append((f"本步另一张标签 · {other}", value, f"sibling:{other}"))
        return out

    def on_reprocess(self):
        """Rebuild the current step from files already on disk, no API calls."""
        if self.busy:
            return
        step = self.current_step
        entry = config.current_entry(self.cfg, step)
        if not entry:
            self.log(f"{step} 还没有产物，先正常生成一次")
            return
        self.save_fields()
        self.busy = True
        self.job_started = time.time()
        self.job_label = step
        self.btn_next.configure(state="disabled")
        self.btn_gen.configure(state="disabled")
        self.btn_reproc.configure(state="disabled")
        self.progress.start(14)
        self.status_var.set(f"正在重新处理「{step}」…")

        def work():
            try:
                cfg = config.load(self.path)
                pipeline.ensure_prompts(cfg)
                pipeline.reprocess(cfg, self.path, step,
                                   log=lambda m: self.q.put(("log", m)))
                self.q.put(("reprocessed", step))
            except Exception as exc:
                self.q.put(("error", f"{type(exc).__name__}: {exc}"))

        threading.Thread(target=work, daemon=True).start()
        self._tick()

    def on_regen_prompt(self, key, widget):
        if self.busy:
            return
        self.save_fields()
        self.busy = True
        self.job_started = time.time()
        self.job_label = key
        self.progress.start(14)
        self.status_var.set(f"正在重新生成「{key}」提示词…")
        self.log(f"=== 重新生成提示词 {key} ===")

        def work():
            try:
                cfg = config.load(self.path)
                pipeline.ensure_prompts(cfg)
                log = lambda m: self.q.put(("log", m))
                text, source = pipeline.regenerate_prompt(cfg, self.path, key, log=log)
                self.q.put(("prompt", (key, text, source)))
            except Exception as exc:
                self.q.put(("error", f"{type(exc).__name__}: {exc}"))

        threading.Thread(target=work, daemon=True).start()
        self._tick()

    def on_choose_prompt(self, key, widget):
        candidates = self.prompt_candidates(key)
        dialog = tk.Toplevel(self)
        dialog.title("更换提示词")
        dialog.configure(bg=BG)
        dialog.geometry(self._centered(940, 560))
        dialog.transient(self)
        dialog.grab_set()

        label_for = {k: v for k, v in PROMPTS_FOR_STEP[self.current_step]}.get(key, key)
        tk.Label(dialog, text=f"更换提示词 · {label_for}", bg=BG, fg=TEXT,
                 font=F_TITLE).pack(anchor="w", padx=14, pady=(12, 6))

        body = tk.Frame(dialog, bg=BG)
        body.pack(fill="both", expand=True, padx=14)
        left = tk.Frame(body, bg=BG)
        left.pack(side="left", fill="y")
        right = tk.Frame(body, bg=BG)
        right.pack(side="left", fill="both", expand=True, padx=(12, 0))

        listing = tk.Listbox(left, width=44, height=16, activestyle="none", relief="flat",
                             bd=0, bg=CARD, fg=TEXT, font=F_SMALL, highlightthickness=1,
                             highlightbackground=BORDER, selectbackground=ACCENT_SOFT,
                             selectforeground=ACCENT)
        listing.pack(side="left", fill="y")
        for label, _text, _source in candidates:
            listing.insert("end", " " + label)

        preview = tk.Text(right, wrap="word", relief="flat", bd=0, bg=CARD, fg=TEXT, font=F_UI,
                          padx=10, pady=8, highlightthickness=1, highlightbackground=BORDER)
        preview.pack(fill="both", expand=True)

        current = {"index": 0}

        def show(event=None):
            picked = listing.curselection()
            current["index"] = picked[0] if picked else 0
            preview.configure(state="normal")
            preview.delete("1.0", "end")
            preview.insert("1.0", candidates[current["index"]][1])
            preview.configure(state="disabled")

        listing.bind("<<ListboxSelect>>", show)
        listing.bind("<Double-1>", lambda _e: accept())
        if candidates:
            listing.selection_set(0)
            show()

        def accept():
            if not candidates:
                dialog.destroy()
                return
            label, text, source = candidates[current["index"]]
            widget.delete("1.0", "end")
            widget.insert("1.0", text)
            self._set_source(key, source)
            self.log(f"更换提示词：{key} <- {label}")
            dialog.destroy()

        def import_file():
            chosen = filedialog.askopenfilename(parent=dialog, title="选择提示词文本",
                                                filetypes=[("text", "*.txt"), ("all", "*.*")])
            if not chosen:
                return
            try:
                text = Path(chosen).read_text(encoding="utf-8").strip()
            except Exception as exc:
                messagebox.showerror("读取失败", str(exc), parent=dialog)
                return
            candidates.append((f"文件 · {Path(chosen).name}", text, f"file:{Path(chosen).name}"))
            listing.insert("end", " 文件 · " + Path(chosen).name)
            listing.selection_clear(0, "end")
            listing.selection_set("end")
            show()

        foot = tk.Frame(dialog, bg=BG)
        foot.pack(fill="x", padx=14, pady=12)
        button(foot, "使用这条", accept, "primary").pack(side="right")
        button(foot, "取消", dialog.destroy, "secondary").pack(side="right", padx=8)
        button(foot, "从文件导入…", import_file, "ghost").pack(side="left")
        tk.Label(foot, text="双击条目也可直接使用", bg=BG, fg=MUTED, font=F_SMALL).pack(side="left", padx=10)

    def _copy(self, widget):
        self.clipboard_clear()
        self.clipboard_append(widget.get("1.0", "end").strip())

    def _build_preview(self, parent):
        box = card(parent, "预览")
        box.grid(row=0, column=0, sticky="ew")
        head = tk.Frame(box.body, bg=CARD)
        head.pack(fill="x", pady=(0, 6))
        self.animate = tk.BooleanVar(value=True)
        tk.Checkbutton(head, text="序列帧预览", variable=self.animate, bg=CARD, fg=MUTED,
                       font=F_SMALL, activebackground=CARD, selectcolor=CARD,
                       highlightthickness=0, anchor="w",
                       command=self._refresh_preview).pack(side="left")
        self.anim_info = tk.Label(head, text="", bg=CARD, fg=MUTED, font=F_SMALL)
        self.anim_info.pack(side="right")
        holder = tk.Frame(box.body, bg=SOFT, height=PREVIEW)
        holder.pack(fill="x")
        holder.pack_propagate(False)
        self.preview = tk.Label(holder, text="还没有产物", bg=SOFT, fg=MUTED, font=F_SMALL)
        self.preview.pack(fill="both", expand=True)
        self._refresh_preview()

    def _preview_source(self):
        step = self.current_step
        key = "contact_sheet" if step in ("idle", "walk") else "image"
        return config.artifact_path(self.path, self.cfg, step, key)

    DIRECTIONS = ("front_left", "front_right", "back_left", "back_right")

    def _anim_frames(self):
        """Exported sprite frames of the current run, keyed by direction."""
        step = self.current_step
        if step not in ("idle", "walk"):
            return {}
        entry = config.current_entry(self.cfg, step)
        if not entry:
            return {}
        root = self.path.parent / step / entry["run"]
        manifest = root / "sprites.json"
        if not manifest.exists():
            return {}
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception:
            return {}
        frames = data.get("frames") or {}
        found = {}
        for direction in self.DIRECTIONS:
            paths = [root / rel for rel in (frames.get(direction) or [])]
            if paths and all(p.exists() for p in paths):
                found[direction] = paths
        return found

    def _stop_animation(self):
        if getattr(self, "_anim_job", None):
            try:
                self.after_cancel(self._anim_job)
            except Exception:
                pass
            self._anim_job = None

    def _play_frames(self, mapping):
        cell = PREVIEW // 2
        self._anim_scaled = {}
        for direction, paths in mapping.items():
            scaled = []
            for path in paths:
                img = Image.open(path).convert("RGBA")
                img.thumbnail((cell - 10, cell - 10), Image.LANCZOS)
                scaled.append(img)
            self._anim_scaled[direction] = scaled
        self._anim_index = 0
        counts = {len(v) for v in self._anim_scaled.values()}
        count = min(counts) if counts else 0
        self.anim_info.configure(text=f"{len(self._anim_scaled)} 方向 · {count} 帧 · 循环")
        self._anim_tick()

    def _anim_tick(self):
        if not getattr(self, "_anim_scaled", None) or not getattr(self, "_alive", True):
            return
        cell = PREVIEW // 2
        board = checker(PREVIEW)
        draw = ImageDraw.Draw(board)
        for index, direction in enumerate(self.DIRECTIONS):
            frames = self._anim_scaled.get(direction)
            if not frames:
                continue
            img = frames[self._anim_index % len(frames)]
            column, row = index % 2, index // 2
            board.paste(img, (column * cell + (cell - img.width) // 2,
                              row * cell + (cell - img.height) // 2), img)
        draw.line([(cell, 0), (cell, PREVIEW)], fill=(196, 201, 207), width=1)
        draw.line([(0, cell), (PREVIEW, cell)], fill=(196, 201, 207), width=1)
        self._anim_index += 1
        self._photo = ImageTk.PhotoImage(board)
        self.preview.configure(image=self._photo, text="")
        self._anim_job = self.after(90, self._anim_tick)

    def _refresh_preview(self):
        self._stop_animation()
        self._anim_paths = []
        if hasattr(self, "anim_info"):
            self.anim_info.configure(text="")
        if getattr(self, "animate", None) is not None and self.animate.get():
            frames = self._anim_frames()
            if frames:
                self._play_frames(frames)
                return
        path = self._preview_source()
        if not path or not Path(path).exists():
            self.preview.configure(image="", text="还没有产物")
            self.preview.image = None
            return
        img = Image.open(path).convert("RGBA")
        img.thumbnail((PREVIEW, PREVIEW), Image.LANCZOS)
        board = checker(PREVIEW)
        board.paste(img, ((PREVIEW - img.width) // 2, (PREVIEW - img.height) // 2), img)
        self._photo = ImageTk.PhotoImage(board)
        self.preview.configure(image=self._photo, text="")

    def _build_history(self, parent):
        box = card(parent, "历史版本")
        box.grid(row=1, column=0, sticky="nsew", pady=(12, 0))
        self.history = ttk.Treeview(box.body, columns=("time", "run"), show="headings", height=4)
        self.history.heading("time", text="时间")
        self.history.heading("run", text="运行 ID")
        self.history.column("time", width=140, anchor="w")
        self.history.column("run", width=210, anchor="w")
        self.history.tag_configure("current", background=ACCENT_SOFT, foreground=ACCENT)
        self.history.pack(fill="both", expand=True)
        self.history.bind("<Double-1>", lambda _e: self.on_use_history())
        button(box.body, "设为当前版本", self.on_use_history, "secondary").pack(fill="x", pady=(8, 0))
        self._refresh_history(self.current_step)

    def _refresh_history(self, step):
        for item in self.history.get_children():
            self.history.delete(item)
        state = self.cfg["steps"][step]
        for entry in state["history"]:
            tags = ("current",) if entry["run"] == state["current"] else ()
            self.history.insert("", "end", values=(entry["created"].replace("T", " "), entry["run"]),
                                tags=tags)

    def _build_sprite_tuning(self, parent):
        cfg = self.cfg["sprites"][self.current_step]
        box = card(parent, "精灵微调 · 只重算图片")
        box.pack(side="bottom", fill="x", pady=(12, 0))
        row = tk.Frame(box.body, bg=CARD)
        row.pack(fill="x")
        self.vars = {}
        for label, key, lo, hi in (("角色高", "char_height", 20, 200), ("脚底 y", "foot_y", 0, 127),
                                   ("帧数", "frames", 1, 24), ("周期 0=auto", "period", 0, 120)):
            tk.Label(row, text=label, bg=CARD, fg=MUTED, font=F_SMALL).pack(side="left")
            var = tk.StringVar(value=str(cfg.get(key) if cfg.get(key) is not None else 0))
            ttk.Spinbox(row, from_=lo, to=hi, textvariable=var, width=5).pack(side="left", padx=(3, 12))
            self.vars[key] = var

        grid = tk.Frame(box.body, bg=CARD)
        grid.pack(fill="x", pady=(8, 0))
        for i, head in enumerate(["方向", "dx", "dy", "启用"]):
            tk.Label(grid, text=head, bg=CARD, fg=MUTED, font=F_SMALL).grid(row=0, column=i, sticky="w", padx=3)
        self.dir_vars = {}
        for i, d in enumerate(sprites.DIRECTIONS, start=1):
            tk.Label(grid, text=d, bg=CARD, fg=TEXT, font=F_SMALL).grid(row=i, column=0, sticky="w")
            dx = tk.StringVar(value=str(cfg["directions"][d].get("dx", 0)))
            dy = tk.StringVar(value=str(cfg["directions"][d].get("dy", 0)))
            on = tk.BooleanVar(value=cfg["directions"][d].get("enabled", True))
            ttk.Spinbox(grid, from_=-64, to=64, textvariable=dx, width=5).grid(row=i, column=1, padx=2, pady=1)
            ttk.Spinbox(grid, from_=-64, to=64, textvariable=dy, width=5).grid(row=i, column=2, padx=2, pady=1)
            tk.Checkbutton(grid, variable=on, bg=CARD, activebackground=CARD, selectcolor=CARD,
                           highlightthickness=0).grid(row=i, column=3, padx=6)
            self.dir_vars[d] = (dx, dy, on)

        foot = tk.Frame(box.body, bg=CARD)
        foot.pack(fill="x", pady=(8, 0))
        button(foot, "应用并重新导出", self.on_export, "primary").pack(side="left")

    # ------------------------------------------------------------- actions
    def log(self, message):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", str(message) + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def save_fields(self):
        self.cfg["character"]["id"] = self.id_var.get().strip() or self.cfg["character"]["id"]
        self.cfg["character"]["display_name"] = self.name_var.get().strip()
        self.cfg["character"]["description"] = self.desc_var.get().strip()
        for key, widget in self.prompt_widgets.items():
            if widget.winfo_exists():
                self.cfg.setdefault("prompts", {})[key] = widget.get("1.0", "end").strip()
        config.save(self.cfg, self.path)
        self.status_var.set(f"已保存 · {self.path.name}")

    def reload(self):
        self.cfg = config.load(self.path)
        pipeline.ensure_prompts(self.cfg)
        self.select_step(self.current_step)

    def on_open(self):
        path = filedialog.askopenfilename(filetypes=[("config", "*.json")], initialdir=str(self.path.parent))
        if path:
            self.open_config(path)

    def open_config(self, path):
        self.path = Path(path).resolve()
        self.path_var.set(str(self.path))
        self.cfg = config.load(self.path)
        pipeline.ensure_prompts(self.cfg)
        self.current_step = config.STEPS[0]
        self.title(f"角色资源流水线 · {self.cfg['character']['id']}")
        try:
            api = project.apply_api(self.work_dir())
            self.log(f"API：{ark.base_url()} · 密钥来源：{api.get('key_source', '?')}")
            runtime = analyze._RUNTIME_STATE.get("path") or "未加载"
            self.log(f"抠像运行库：{runtime}")
            self.log(f"抠像设备：{analyze.device_name()}")
        except Exception as exc:
            self.log(f"项目 API 设置未应用：{type(exc).__name__}")
        self.select_step(self.current_step)
        self.log(f"打开 {self.path}")

    def work_dir(self) -> Path:
        return self.path.parent.parent if self.path.parent.name else self.path.parent

    def on_new_character(self):
        """One field: type a name, the folder is created and opened."""
        work = self.work_dir()
        dialog = tk.Toplevel(self)
        dialog.title("新建角色")
        dialog.configure(bg=BG)
        dialog.geometry("560x280")
        dialog.transient(self)
        dialog.grab_set()

        tk.Label(dialog, text="角色名称（同时作为文件夹名）", bg=BG, fg=MUTED,
                 font=F_SMALL).pack(anchor="w", padx=16, pady=(16, 4))
        name_var = tk.StringVar()
        entry = tk.Entry(dialog, textvariable=name_var, relief="flat", bg=SOFT, font=F_UI)
        entry.pack(fill="x", padx=16, ipady=4)
        entry.focus_set()

        tk.Label(dialog, text="描述（可先留空，进去再改）", bg=BG, fg=MUTED,
                 font=F_SMALL).pack(anchor="w", padx=16, pady=(12, 4))
        desc_var = tk.StringVar()
        tk.Entry(dialog, textvariable=desc_var, relief="flat", bg=SOFT, font=F_UI).pack(
            fill="x", padx=16, ipady=4)

        hint = tk.Label(dialog, text=f"将在工作目录下创建 <名称>/config.json\n{work}",
                        bg=BG, fg=MUTED, font=F_SMALL, justify="left", wraplength=520)
        hint.pack(anchor="w", padx=16, pady=(10, 0))

        def create(_event=None):
            raw = name_var.get().strip()
            if not raw:
                messagebox.showwarning("缺少名称", "先给角色起个名字。", parent=dialog)
                return
            safe = "".join(ch for ch in raw if ch not in '\\/:*?"<>|').strip() or "character"
            target = work / safe
            suffix = 2
            while (target / "config.json").exists() and suffix < 100:
                target = work / f"{safe}_{suffix}"
                suffix += 1
            description = desc_var.get().strip() or raw
            path = project.new_character(work, target.name, description, display_name=raw)
            dialog.destroy()
            self.open_config(path)
            self.log(f"已创建 {path}")

        entry.bind("<Return>", create)
        foot = tk.Frame(dialog, bg=BG)
        foot.pack(fill="x", padx=16, pady=14)
        button(foot, "创建", create, "primary").pack(side="right")
        button(foot, "取消", dialog.destroy, "secondary").pack(side="right", padx=8)

    def open_settings(self):
        """Project settings straight from the header (the project list stays closed)."""
        window = ProjectWindow(self, self.work_dir())
        window.withdraw()
        dialog = window.settings(parent=self)
        dialog.bind("<Destroy>", lambda _e: window.destroy(), add="+")

    def open_project(self):
        window = ProjectWindow(self, self.work_dir())
        window.grab_set()

    def on_use_history(self):
        picked = self.history.selection()
        if not picked:
            return
        run = self.history.item(picked[0], "values")[1]
        config.select(self.cfg, self.path, self.current_step, run)
        self.reload()

    def on_generate(self):
        self.start_job(self.current_step, advance=False)

    def on_next(self):
        step = self.current_step
        if self.cfg["steps"][step]["status"] != "done":
            self.start_job(step, advance=True)
            return
        index = config.STEPS.index(step)
        if index + 1 < len(config.STEPS):
            self.select_step(config.STEPS[index + 1])

    def on_export(self):
        if self.current_step not in ("idle", "walk"):
            return
        cfg = self.cfg["sprites"][self.current_step]
        cfg["char_height"] = float(self.vars["char_height"].get() or 98)
        cfg["foot_y"] = int(float(self.vars["foot_y"].get() or 119))
        cfg["frames"] = int(float(self.vars["frames"].get() or 8))
        period = int(float(self.vars["period"].get() or 0))
        cfg["period"] = period or None
        for d, (dx, dy, on) in self.dir_vars.items():
            cfg["directions"][d] = {"dx": float(dx.get() or 0), "dy": float(dy.get() or 0),
                                    "enabled": bool(on.get())}
        config.save(self.cfg, self.path)
        self.start_job(self.current_step, advance=False, export_only=True)

    def start_job(self, step, advance=False, export_only=False):
        if self.busy:
            return
        self.save_fields()
        self.busy = True
        self.job_started = time.time()
        self.job_label = step
        self.btn_next.configure(state="disabled")
        self.btn_gen.configure(state="disabled")
        self.progress.start(14)
        self.status_var.set(f"{config.STEP_TITLES[step]} {'导出' if export_only else '生成'}中… 0s")
        self.log(f"=== {step} {'导出' if export_only else '生成'} ===")

        def work():
            try:
                cfg = config.load(self.path)
                pipeline.ensure_prompts(cfg)
                provider = pipeline.make_provider(cfg, dry=self.dry.get())
                log = lambda m: self.q.put(("log", m))
                if export_only:
                    pipeline.export_only(cfg, self.path, step, log=log)
                else:
                    style = project.step_style(self.work_dir(), step)
                    if style:
                        log(f"  追加项目风格：{style[:40]}…")
                    pipeline.run(cfg, self.path, step, provider, log=log,
                                 refine=bool(self.refine.get()), style=style)
                self.q.put(("done", (step, advance)))
            except Exception as exc:
                self.q.put(("error", f"{type(exc).__name__}: {exc}"))

        threading.Thread(target=work, daemon=True).start()
        self._tick()

    def _stop_progress(self, label):
        self.progress.stop()
        self.progress.configure(value=0)
        self.btn_next.configure(state="normal")
        self.btn_gen.configure(state="normal")
        self.status_var.set(f"{label} · {config.STEP_TITLES.get(self.job_label, '')} 用时 "
                            f"{time.time() - self.job_started:.0f}s")

    def destroy(self):
        self._alive = False
        self._stop_animation()
        for attr in ("_poll_id", "_tick_id"):
            timer = getattr(self, attr, None)
            if timer:
                try:
                    self.after_cancel(timer)
                except Exception:
                    pass
        try:
            super().destroy()
        except Exception:
            pass

    def _tick(self):
        if not getattr(self, "_alive", True):
            return
        if self.busy:
            self.status_var.set(f"{config.STEP_TITLES.get(self.job_label, '')} 生成中… "
                                f"{time.time() - self.job_started:.0f}s（视频通常 2–4 分钟）")
            self._tick_id = self.after(500, self._tick)

    def _poll(self):
        if not getattr(self, "_alive", True):
            return
        try:
            while True:
                kind, payload = self.q.get_nowait()
                if kind == "log":
                    self.log(payload)
                elif kind == "error":
                    self.busy = False
                    self._stop_progress("出错")
                    self.log("错误：" + payload)
                    messagebox.showerror("出错", payload)
                elif kind == "models":
                    self.models = payload
                    self.models_loaded = True
                    self.select_step(self.current_step)
                elif kind == "reprocessed":
                    self.busy = False
                    self._stop_progress("重新处理完成")
                    self.reload()
                    self.log(f"{payload} 已重新处理")
                elif kind == "calibrated":
                    self.busy = False
                    self._stop_progress("标定完成")
                    step, result = payload
                    self.reload()
                    extra = f"，角色高标定为 {result['char_height']}px" if "char_height" in result else ""
                    self.log(f"参考图标定完成：角色占高 {result['ratio']:.2f}{extra}，提示词已更新")
                elif kind == "prompt":
                    self.log("提示词已更新")
                    self.busy = False
                    self._stop_progress("提示词已更新")
                    key, text, source = payload
                    widget = self.prompt_widgets.get(key)
                    if widget is not None and widget.winfo_exists():
                        widget.delete("1.0", "end")
                        widget.insert("1.0", text)
                        self._set_source(key, source)
                    config.save(self.cfg, self.path)
                    self.log(f"提示词 {key} 已重新生成（来源 {source}）")
                elif kind == "done":
                    self.busy = False
                    self._stop_progress("完成")
                    step, advance = payload
                    self.reload()
                    if advance:
                        index = config.STEPS.index(step)
                        if index + 1 < len(config.STEPS):
                            self.select_step(config.STEPS[index + 1])
        except queue.Empty:
            pass
        self._poll_id = self.after(150, self._poll)


def run_gui(config_path: str):
    App(config_path).mainloop()


class ProjectWindow(tk.Toplevel):
    """List every character under a work folder and jump into one."""

    def __init__(self, app: "App", work: Path):
        super().__init__(app)
        self.app = app
        self.work = Path(work)
        self.title("项目管理")
        self.configure(bg=BG)
        self.geometry("980x580")
        self.minsize(860, 460)

        head = tk.Frame(self, bg=BG)
        head.pack(fill="x", padx=14, pady=(12, 6))
        tk.Label(head, text="工作目录", bg=BG, fg=MUTED, font=F_SMALL).pack(side="left")
        self.work_var = tk.StringVar(value=str(self.work))
        tk.Entry(head, textvariable=self.work_var, relief="flat", bg=SOFT, fg=TEXT, font=F_UI,
                 insertbackground=ACCENT).pack(side="left", fill="x", expand=True, padx=8, ipady=3)
        for text, cmd in (("打开文件夹…", self.pick_folder), ("刷新", self.refresh)):
            button(head, text, cmd, "secondary").pack(side="left", padx=(0, 6))

        box = card(self, "角色")
        box.pack(fill="both", expand=True, padx=14, pady=6)
        cols = ("name", "desc", "concept", "portrait", "idle", "walk", "updated")
        self.tree = ttk.Treeview(box.body, columns=cols, show="tree headings",
                                 style="Project.Treeview")
        self.tree.heading("#0", text="头像")
        self.tree.column("#0", width=68, anchor="center", stretch=False)
        for key, title, width in (("name", "名称", 110), ("desc", "描述", 330),
                                  ("concept", "原画", 56), ("portrait", "头像", 56),
                                  ("idle", "待机", 56), ("walk", "移动", 56), ("updated", "最近更新", 150)):
            self.tree.heading(key, text=title)
            self.tree.column(key, width=width, anchor="w" if key in ("name", "desc", "updated") else "center")
        self.tree.pack(fill="both", expand=True)
        self.tree.bind("<Double-1>", lambda _e: self.open_selected())
        self.tree.tag_configure("done", foreground=TEXT)
        self.tree.tag_configure("empty", foreground=MUTED)

        foot = tk.Frame(self, bg=BG)
        foot.pack(fill="x", padx=14, pady=(0, 12))
        button(foot, "打开所选角色", self.open_selected, "primary").pack(side="left")
        button(foot, "新建角色", self.new_character, "secondary").pack(side="left", padx=8)
        button(foot, "项目设置", self.settings, "secondary").pack(side="left")
        button(foot, "关闭", self.destroy, "ghost").pack(side="right")
        tk.Label(foot, text="双击一行也可以打开", bg=BG, fg=MUTED, font=F_SMALL).pack(side="right", padx=10)

        self.refresh()

    # ---------------------------------------------------------------- data
    def pick_folder(self):
        chosen = filedialog.askdirectory(initialdir=str(self.work))
        if chosen:
            self.work = Path(chosen)
            self.work_var.set(str(self.work))
            self.refresh()

    def refresh(self):
        self.work = Path(self.work_var.get())
        for item in self.tree.get_children():
            self.tree.delete(item)
        rows = project.characters(self.work)
        mark = {"done": "✓", "pending": "·"}
        self.thumbs = []
        for row in rows:
            status = row["status"]
            tags = ("done",) if any(v == "done" for v in status.values()) else ("empty",)
            thumb = self._thumbnail(row.get("portrait"), row["name"])
            self.thumbs.append(thumb)
            self.tree.insert("", "end", iid=str(row["path"]), tags=tags, image=thumb, values=(
                row["name"], row["description"][:70],
                mark.get(status["concept"], "?"), mark.get(status["portrait"], "?"),
                mark.get(status["idle"], "?"), mark.get(status["walk"], "?"),
                row["updated"].replace("T", " ")))
        self.app.log(f"项目 {self.work}：{len(rows)} 个角色")

    def _thumbnail(self, path, name: str):
        """48px portrait on a light card; initials when nothing was generated yet."""
        from PIL import ImageDraw

        size = 48
        board = Image.new("RGB", (size, size), "#eef0f3")
        if path:
            try:
                img = Image.open(path).convert("RGBA")
                img.thumbnail((size - 4, size - 4), Image.LANCZOS)
                board.paste(img, ((size - img.width) // 2, (size - img.height) // 2), img)
                return ImageTk.PhotoImage(board)
            except Exception:
                pass
        draw = ImageDraw.Draw(board)
        draw.rectangle([0, 0, size - 1, size - 1], outline="#dfe2e6")
        draw.ellipse([10, 10, size - 11, size - 11], fill="#dfe2e6")
        letter = (name or "?").strip()[:1].upper() or "?"
        try:
            from PIL import ImageFont

            font = ImageFont.truetype("segoeui.ttf", 20)
        except Exception:
            font = None
        box = draw.textbbox((0, 0), letter, font=font)
        draw.text(((size - (box[2] - box[0])) / 2 - box[0],
                   (size - (box[3] - box[1])) / 2 - box[1]), letter,
                  fill="#8b939c", font=font)
        return ImageTk.PhotoImage(board)

    def open_selected(self):
        picked = self.tree.selection()
        if not picked:
            return
        self.app.open_config(picked[0])
        self.destroy()

    # ------------------------------------------------------------- actions
    def new_character(self):
        dialog = tk.Toplevel(self)
        dialog.title("新建角色")
        dialog.configure(bg=BG)
        dialog.geometry("520x300")
        dialog.transient(self)
        dialog.grab_set()

        tk.Label(dialog, text="角色 ID（英文，用作文件夹名）", bg=BG, fg=MUTED, font=F_SMALL).pack(
            anchor="w", padx=14, pady=(14, 2))
        id_var = tk.StringVar()
        tk.Entry(dialog, textvariable=id_var, relief="flat", bg=SOFT, font=F_UI).pack(
            fill="x", padx=14, ipady=3)
        tk.Label(dialog, text="角色描述", bg=BG, fg=MUTED, font=F_SMALL).pack(
            anchor="w", padx=14, pady=(10, 2))
        desc_text = tk.Text(dialog, height=4, relief="flat", bg=SOFT, font=F_UI, wrap="word")
        desc_text.pack(fill="both", expand=True, padx=14)

        def create():
            character_id = id_var.get().strip()
            description = desc_text.get("1.0", "end").strip()
            if not character_id or not description:
                messagebox.showwarning("缺少信息", "ID 和描述都要填。", parent=dialog)
                return
            path = project.new_character(self.work, character_id, description)
            dialog.destroy()
            self.refresh()
            self.app.open_config(path)
            self.destroy()

        foot = tk.Frame(dialog, bg=BG)
        foot.pack(fill="x", padx=14, pady=10)
        button(foot, "创建", create, "primary").pack(side="right")
        button(foot, "取消", dialog.destroy, "secondary").pack(side="right", padx=8)

    def settings(self, parent=None):
        parent = parent or self
        work = self.work
        current = project.load_settings(work)
        secrets = project.load_secrets(work)
        api = current.get("api") or {}
        styles = current.get("step_styles") or {}

        dialog = tk.Toplevel(parent)
        dialog.title("项目设置")
        dialog.configure(bg=BG)
        dialog.geometry("780x600")
        dialog.minsize(680, 520)
        dialog.transient(parent)
        dialog.grab_set()

        nb = ttk.Notebook(dialog)
        nb.pack(fill="both", expand=True, padx=14, pady=(14, 8))

        # ---------------------------------------------------------- general
        tab = tk.Frame(nb, bg=BG)
        nb.add(tab, text="通用")
        tk.Label(tab, text="项目名称", bg=BG, fg=MUTED, font=F_SMALL).pack(anchor="w", pady=(10, 2))
        name_var = tk.StringVar(value=current.get("name", ""))
        tk.Entry(tab, textvariable=name_var, relief="flat", bg=SOFT, font=F_UI).pack(fill="x", ipady=3)

        tk.Label(tab, text="统一风格提示词（追加到每个新角色的 style）", bg=BG, fg=MUTED,
                 font=F_SMALL).pack(anchor="w", pady=(10, 2))
        style_text = tk.Text(tab, height=4, relief="flat", bg=SOFT, font=F_UI, wrap="word")
        style_text.insert("1.0", current.get("style_prompt", ""))
        style_text.pack(fill="x")

        tk.Label(tab, text="统一参考图（新建角色时作为各步默认参考图）", bg=BG, fg=MUTED,
                 font=F_SMALL).pack(anchor="w", pady=(10, 2))
        ref_var = tk.StringVar(value=current.get("style_reference", ""))
        row = tk.Frame(tab, bg=BG)
        row.pack(fill="x")
        tk.Entry(row, textvariable=ref_var, relief="flat", bg=SOFT, font=F_SMALL).pack(
            side="left", fill="x", expand=True, ipady=3)

        def choose_ref():
            chosen = filedialog.askopenfilename(
                parent=dialog, filetypes=[("image", "*.png;*.jpg;*.jpeg;*.webp")])
            if not chosen:
                return
            source = Path(chosen)
            target = work / "references" / "_project" / source.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            ref_var.set(str(target.relative_to(work)))

        button(row, "选择…", choose_ref, "secondary").pack(side="left", padx=6)

        tk.Label(tab, text="背景键色（新生成的原画/头像/视频都用它）", bg=BG, fg=MUTED,
                 font=F_SMALL).pack(anchor="w", pady=(10, 2))
        bg_var = tk.StringVar(value=current.get("background", "auto"))
        bg_row = tk.Frame(tab, bg=BG)
        bg_row.pack(fill="x")
        tk.Entry(bg_row, textvariable=bg_var, relief="flat", bg=SOFT, font=F_UI, width=12).pack(
            side="left", ipady=3)
        tk.Button(bg_row, text="自动", relief="flat", bg=SOFT, fg=TEXT, font=F_SMALL,
                  activebackground="#e6e9ee", cursor="hand2",
                  command=lambda: bg_var.set("auto")).pack(side="left", padx=(0, 8))
        presets = [("#00ffff", "青"), ("#ff00ff", "品红"), ("#00ff00", "绿"),
                   ("#0000ff", "蓝"), ("#ff8800", "橙"), ("#000000", "黑"),
                   ("#ffffff", "白")]
        for value, label in presets:
            swatch = tk.Frame(bg_row, bg=value, width=18, height=18,
                              highlightthickness=1,
                              highlightbackground="#c9ced4" if value != "#000000" else "#8c949c")
            swatch.pack(side="left", padx=(8, 2))
            swatch.bind("<Button-1>", lambda _e, v=value: bg_var.set(v))
            tk.Label(bg_row, text=label, bg=BG, fg=MUTED, font=F_SMALL).pack(side="left")

        # -------------------------------------------------------------- api
        tab = tk.Frame(nb, bg=BG)
        nb.add(tab, text="API")
        api_vars = {}
        fields = [
            ("Base URL", "base_url", "https://ark.cn-beijing.volces.com/api/v3", False),
            ("API Key（存 .secrets.json，不写进 project.json）", "api_key", "", True),
            ("Key 环境变量名（留空则用 ARK_API_KEY）", "key_env", "ARK_API_KEY", False),
            ("出图模型", "image_model", "", False),
            ("视频模型", "video_model", "", False),
            ("识图 / 改写模型", "vision_model", "", False),
        ]
        for label, key, fallback, secret in fields:
            tk.Label(tab, text=label, bg=BG, fg=MUTED, font=F_SMALL).pack(anchor="w", pady=(7, 2))
            value = secrets.get("api_key", "") if key == "api_key" else api.get(key, fallback)
            var = tk.StringVar(value=value)
            entry = tk.Entry(tab, textvariable=var, relief="flat", bg=SOFT, font=F_UI)
            if secret:
                entry.configure(show="•")
            entry.pack(fill="x", ipady=3)
            api_vars[key] = var

        status = tk.Label(tab, text="", bg=BG, fg=MUTED, font=F_SMALL)
        status.pack(anchor="w", pady=(8, 0))

        def persist():
            project.save_settings(work, {
                "name": name_var.get().strip(),
                "style_prompt": style_text.get("1.0", "end").strip(),
                "style_reference": ref_var.get().strip(),
                "background": bg_var.get().strip() or "auto",
                "apply_style_to_new": True,
                "api": {k: api_vars[k].get().strip() for k in
                        ("base_url", "key_env", "image_model", "video_model", "vision_model")},
                "step_styles": {step: {"prompt": widget.get("1.0", "end").strip(),
                                       "source": (styles.get(step) or {}).get("source", "")}
                                for step, widget in style_widgets.items()},
            })
            project.save_secrets(work, {"api_key": api_vars["api_key"].get().strip()})
            project.apply_api(work)
            # the open character follows the project default
            self.app.cfg["background"] = bg_var.get().strip() or "auto"
            config.save(self.app.cfg, self.app.path)

        def test_api():
            persist()
            try:
                ids = ark.list_models()
                status.configure(text=f"连接成功，账号可见 {len(ids)} 个模型", fg=OK)
            except Exception as exc:
                status.configure(text=f"连接失败：{type(exc).__name__}: {exc}", fg="#b91c1c")

        button(tab, "测试连接", test_api, "secondary").pack(anchor="w", pady=(4, 0))

        # ------------------------------------------------------- step styles
        tab = tk.Frame(nb, bg=BG)
        nb.add(tab, text="分步风格")
        tk.Label(tab, text="每一步生成时追加到提示词末尾；可以从图片或文本文件自动生成",
                 bg=BG, fg=MUTED, font=F_SMALL).pack(anchor="w", pady=(10, 4))
        style_widgets = {}
        for step in project.STYLE_STEPS:
            block = tk.Frame(tab, bg=BG)
            block.pack(fill="x", pady=(4, 6))
            head_row = tk.Frame(block, bg=BG)
            head_row.pack(fill="x")
            tk.Label(head_row, text=config.STEP_TITLES.get(step, step), bg=BG, fg=TEXT,
                     font=F_BOLD).pack(side="left")
            widget = tk.Text(block, height=3, relief="flat", bg=SOFT, font=F_UI, wrap="word")
            widget.insert("1.0", (styles.get(step) or {}).get("prompt", ""))
            widget.pack(fill="x")

            def make_generate(name=step, box=widget):
                def run():
                    chosen = filedialog.askopenfilename(
                        parent=dialog, title=f"为 {name} 选择风格参考文件",
                        filetypes=[("image or text", "*.png;*.jpg;*.jpeg;*.webp;*.txt;*.md"),
                                   ("all", "*.*")])
                    if not chosen:
                        return
                    try:
                        text = project.generate_step_style(work, name, chosen,
                                                           log=lambda m: self.app.log(m))
                    except Exception as exc:
                        messagebox.showerror("生成失败", f"{type(exc).__name__}: {exc}", parent=dialog)
                        return
                    box.delete("1.0", "end")
                    box.insert("1.0", text)

                return run

            button(head_row, "从文件生成…", make_generate(), "ghost").pack(side="right")
            style_widgets[step] = widget

        def save():
            persist()
            self.app.log(f"项目设置已保存：{project.project_file(work)}")
            dialog.destroy()

        foot = tk.Frame(dialog, bg=BG)
        foot.pack(fill="x", padx=14, pady=12)
        button(foot, "保存", save, "primary").pack(side="right")
        button(foot, "取消", dialog.destroy, "secondary").pack(side="right", padx=8)
        return dialog
