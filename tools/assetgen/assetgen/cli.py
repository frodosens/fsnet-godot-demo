"""Command line entry point - feature parity with the GUI.

    assetgen new      --work work --id mara --desc "像素风女骑士"
    assetgen list     --work work
    assetgen show     --config work/mara/config.json
    assetgen set      --config ... --desc "新的描述"
    assetgen prompt   --config ... --step walk --regenerate
    assetgen prompt   --config ... --step walk --file note.txt
    assetgen ref      --config ... --step concept --file style.png
    assetgen ref      --config ... --step concept --clear
    assetgen model    --config ... --step idle --set doubao-seedance-2-5-260628
    assetgen history  --config ... --step walk
    assetgen use      --config ... --step walk --run 20261030-160618-151
    assetgen sprite   --config ... --step walk --frames 8 --offset front_left=2,-1
    assetgen export   --config ... --step walk
    assetgen run      --config ... [--steps concept,portrait] [--next] [--dry-run]
    assetgen project  --work work --show
    assetgen project  --work work --set style_prompt="统一赛璐璐描边"
    assetgen style    --work work --step walk --file style_note.txt
    assetgen api      --work work --test
    assetgen api      --work work --set image_model=doubao-seedream-5-0-flash-260915
    assetgen gui      --config work/mara/config.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import shutil

from . import analyze, ark, config, pipeline, project, templates

# Claim the correct MSVC runtime before any C++ dependency can load a stray one.
analyze.preload_msvc_runtime()

for _stream in (sys.stdout, sys.stderr):  # Windows consoles default to cp936
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


# --------------------------------------------------------------------- helpers
def _load(path: str) -> tuple[dict, Path]:
    file = Path(path)
    cfg = config.load(file)
    pipeline.ensure_prompts(cfg)
    work = file.parent.parent
    if project.project_file(work).exists():
        project.apply_api(work)
    return cfg, file


def _work_of(path: Path) -> Path:
    return path.parent.parent


def _kv(pairs: list[str]) -> dict:
    out = {}
    for item in pairs or []:
        if "=" not in item:
            raise SystemExit(f"需要 key=value，收到 {item!r}")
        key, value = item.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def _step_key(step: str) -> str:
    return pipeline.STEP_PROMPT_KEY.get(step, step)


# -------------------------------------------------------------------- commands
def cmd_new(args) -> int:
    path = project.new_character(Path(args.work), args.id, args.desc, args.name or args.id)
    print(f"created {path}")
    return 0


def cmd_list(args) -> int:
    rows = project.characters(Path(args.work))
    if not rows:
        print(f"{args.work}: 没有找到角色（<work>/<id>/config.json）")
        return 0
    print(f"{args.work}  ({len(rows)} 个角色)")
    print(f"{'名称':<14}{'原画':<7}{'头像':<7}{'待机':<7}{'移动':<7}描述")
    for row in rows:
        mark = lambda s: "OK" if s == "done" else "--"
        print(f"{row['name'][:12]:<14}{mark(row['status']['concept']):<9}"
              f"{mark(row['status']['portrait']):<9}{mark(row['status']['idle']):<9}"
              f"{mark(row['status']['walk']):<9}{row['description'][:44]}")
    return 0


def cmd_show(args) -> int:
    cfg, path = _load(args.config)
    c = cfg["character"]
    print(f"{c['id']}  ({c['display_name']})\n  {c['description']}")
    print(f"  style: {c['style'][:96]}")
    work = _work_of(path)
    api = project.api_settings(work) if project.project_file(work).exists() else {}
    if api:
        print(f"  api: {api.get('base_url')} · key {ark.key_source()}")
    for step, state in pipeline.status(cfg).items():
        mark = "x" if state["status"] == "done" else " "
        model = cfg["steps"][step].get("model") or pipeline.default_model_for(cfg, step)
        ref = cfg["steps"][step].get("reference") or "-"
        print(f"  [{mark}] {config.STEP_TITLES[step]:<12} runs={state['runs']:<3} "
              f"current={str(state['current']):<24} model={model} ref={ref}")
    return 0


def cmd_set(args) -> int:
    cfg, path = _load(args.config)
    if args.id:
        cfg["character"]["id"] = args.id
    if args.name is not None:
        cfg["character"]["display_name"] = args.name
    if args.desc is not None:
        cfg["character"]["description"] = args.desc
    if args.background:
        cfg["background"] = args.background
    config.save(cfg, path)
    print("updated")
    return 0


def cmd_prompt(args) -> int:
    cfg, path = _load(args.config)
    step = args.step
    key = _step_key(step)
    if args.show:
        print(cfg["prompts"].get(key, ""))
        return 0
    if args.reset:
        cfg["prompts"][key] = templates.BUILDERS[key](cfg["character"])
        cfg.setdefault("prompt_sources", {})[key] = "template"
        config.save(cfg, path)
        print(f"{key}: 已恢复默认模板")
        return 0
    if args.regenerate:
        text, source = pipeline.regenerate_prompt(cfg, path, key, log=print)
        print(f"{key}: 已重新生成（来源 {source}）")
        print(text[:300])
        return 0
    if args.from_history:
        entry = next((e for e in cfg["steps"][step]["history"] if e["run"] == args.from_history), None)
        if not entry:
            raise SystemExit(f"找不到运行 {args.from_history}")
        text = (entry.get("prompts") or {}).get(key)
        if not text:
            raise SystemExit(f"该运行没有记录 {key} 的提示词")
        cfg["prompts"][key] = text
        cfg.setdefault("prompt_sources", {})[key] = f"history:{step}"
        config.save(cfg, path)
        print(f"{key}: 已回到 {args.from_history} 的版本")
        return 0
    if args.file or args.text:
        text = Path(args.file).read_text(encoding="utf-8").strip() if args.file else args.text
        cfg["prompts"][key] = text
        cfg.setdefault("prompt_sources", {})[key] = (
            f"file:{Path(args.file).name}" if args.file else "manual")
        config.save(cfg, path)
        print(f"{key}: 已更新（{len(text)} 字）")
        return 0
    raise SystemExit("prompt 需要 --show / --set / --file / --reset / --regenerate / --from-history")


def cmd_ref(args) -> int:
    cfg, path = _load(args.config)
    step = args.step
    if args.clear:
        cfg["steps"][step]["reference"] = None
        config.save(cfg, path)
        print(f"{step}: 参考图已清除")
        return 0
    if args.file:
        source = Path(args.file)
        target_dir = path.parent / "references" / step
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / source.name
        target.write_bytes(source.read_bytes())
        cfg["steps"][step]["reference"] = str(target.relative_to(path.parent))
        config.save(cfg, path)
        print(f"{step}: 参考图 -> {target}")
    rel = cfg["steps"][step].get("reference")
    image = config.resolve_reference(path, rel)
    if image is None:
        raise SystemExit(f"{step} 还没有可分析的参考图")
    result = pipeline.calibrate_from_reference(cfg, path, step, image, log=print)
    print(f"{step}: 占高 {result['ratio']}，提示词已更新")
    if "char_height" in result:
        print(f"{step}: 角色高 -> {result['char_height']}px")
    return 0


def cmd_model(args) -> int:
    cfg, path = _load(args.config)
    step = args.step
    if args.clear:
        cfg["steps"][step]["model"] = ""
        config.save(cfg, path)
        print(f"{step}: 模型已回到默认 {pipeline.default_model_for(cfg, step)}")
        return 0
    if not args.set:
        print(f"{step}: " + (cfg["steps"][step].get("model")
                            or "默认 " + pipeline.default_model_for(cfg, step)))
        return 0
    cfg["steps"][step]["model"] = args.set
    config.save(cfg, path)
    print(f"{step}: 模型 -> {args.set}")
    return 0


def cmd_history(args) -> int:
    cfg, _path = _load(args.config)
    state = cfg["steps"][args.step]
    if not state["history"]:
        print("(还没有历史)")
        return 0
    for entry in state["history"]:
        mark = "*" if entry["run"] == state["current"] else " "
        prompts = ",".join((entry.get("prompts") or {}).keys())
        print(f" {mark} {entry['created']}  {entry['run']}  prompts={prompts} {entry.get('note','')}")
    return 0


def cmd_use(args) -> int:
    cfg, path = _load(args.config)
    entry = config.select(cfg, path, args.step, args.run)
    if not entry:
        raise SystemExit(f"{args.step} 没有运行 {args.run}")
    print(f"{args.step}: 当前版本 -> {args.run}")
    return 0


def cmd_sprite(args) -> int:
    cfg, path = _load(args.config)
    step = args.step
    sprite = cfg["sprites"][step]
    for name in ("char_height", "foot_y", "frames", "period", "scale"):
        value = getattr(args, name, None)
        if value is not None:
            sprite[name] = value
    if args.picks:
        sprite["picks"] = [int(v) for v in args.picks.split(",")]
    for item in args.offset or []:
        direction, _, pair = item.partition("=")
        dx, _, dy = pair.partition(",")
        entry = sprite["directions"].setdefault(direction, {})
        entry["dx"] = float(dx or 0)
        entry["dy"] = float(dy or 0)
    for direction in args.disable or []:
        sprite["directions"].setdefault(direction, {})["enabled"] = False
    for direction in args.enable or []:
        sprite["directions"].setdefault(direction, {})["enabled"] = True
    config.save(cfg, path)
    print(f"{step}: " + json.dumps(
        {k: sprite.get(k) for k in ("char_height", "foot_y", "frames", "period")}, ensure_ascii=False))
    if args.export:
        pipeline.export_only(cfg, path, step, log=print)
    return 0


def cmd_clean(args) -> int:
    cfg, path = _load(args.config)
    matte = cfg.setdefault("matte", {})
    if args.method:
        matte["method"] = args.method
    if args.shadow is not None:
        matte["shadow"] = args.shadow
    if args.trim is not None:
        matte["trim"] = args.trim
    for flag, key in (("matte_side", "matte_side"), ("matte_threshold", "matte_threshold"),
                      ("matte_gamma", "matte_gamma")):
        value = getattr(args, flag, None)
        if value is not None:
            matte[key] = value
    if args.method or args.shadow is not None:
        config.save(cfg, path)
    report = pipeline.clean_step(cfg, path, args.step, log=print, tolerance=args.tolerance,
                                 method=matte.get("method") or "auto")
    print(f"{args.step}: 去底完成，保留 {report['kept_ratio'] * 100:.0f}% 像素")
    return 0


def cmd_export(args) -> int:
    cfg, path = _load(args.config)
    pipeline.export_only(cfg, path, args.step, log=print)
    return 0


def cmd_run(args) -> int:
    cfg, path = _load(args.config)
    steps = ([s.strip() for s in args.steps.split(",") if s.strip()] if args.steps
             else list(config.STEPS))
    if args.next:
        pending = next((s for s in config.STEPS if cfg["steps"][s]["status"] != "done"), None)
        if pending is None:
            print("所有步骤都已完成")
            return 0
        steps = [pending]
    if args.only_pending:
        steps = [s for s in steps if cfg["steps"][s]["status"] != "done"]
    if not steps:
        print("nothing to do")
        return 0
    provider = pipeline.make_provider(cfg, dry=args.dry_run)
    log = (lambda m: None) if args.quiet else print
    work = _work_of(path)
    refine = args.refine
    if refine is None:                      # fall back to the project switch
        refine = bool(project.load_settings(work).get("refine", True)) if project.project_file(work).exists() else True
    for step in steps:
        log(f"== {step} ==")
        style = project.step_style(work, step)
        pipeline.run(cfg, path, step, provider, log=log, refine=refine, style=style)
    print("done:", ", ".join(steps))
    return 0


def cmd_project(args) -> int:
    work = Path(args.work)
    if args.set:
        values = _kv(args.set)
        settings = project.load_settings(work)
        api = settings.setdefault("api", {})
        for key, value in values.items():
            if key in ("base_url", "key_env", "image_model", "video_model", "vision_model"):
                api[key] = value
            else:
                settings[key] = value
        project.save_settings(work, settings)
        print("project updated")
        return 0
    print(json.dumps(project.load_settings(work), ensure_ascii=False, indent=2))
    return 0


def cmd_style(args) -> int:
    work = Path(args.work)
    if args.file:
        print(project.generate_step_style(work, args.step, Path(args.file), log=print))
        return 0
    if args.set is not None:
        project.set_step_style(work, args.step, args.set, "manual")
        print(f"{args.step}: 风格提示词已更新")
        return 0
    print(project.step_style(work, args.step))
    return 0


def cmd_api(args) -> int:
    work = Path(args.work)
    if args.set:
        values = _kv(args.set)
        settings = project.load_settings(work)
        api = settings.setdefault("api", {})
        secret = values.pop("api_key", None)
        for key, value in values.items():
            api[key] = value
        project.save_settings(work, settings)
        if secret is not None:
            project.save_secrets(work, {"api_key": secret})
        print("api updated")
    api = project.apply_api(work)
    if args.test:
        try:
            ids = ark.list_models()
            print(f"连接成功：可见 {len(ids)} 个模型；密钥来源 {ark.key_source()}")
            return 0
        except Exception as exc:
            print(f"连接失败：{type(exc).__name__}: {exc}")
            return 2
    shown = {k: v for k, v in api.items() if k != "api_key"}
    shown["api_key"] = "***" if api.get("api_key") else "(未设置，使用环境变量)"
    shown["key_source"] = ark.key_source()
    print(json.dumps(shown, ensure_ascii=False, indent=2))
    return 0


def cmd_model_fetch(args) -> int:
    import urllib.request

    target = analyze.MODEL_DIR / "modnet.onnx"
    target.parent.mkdir(parents=True, exist_ok=True)
    url = ("https://huggingface.co/Xenova/modnet/resolve/main/onnx/model.onnx")
    print(f"downloading {url}")
    with urllib.request.urlopen(url, timeout=600) as resp, open(target, "wb") as fh:
        shutil.copyfileobj(resp, fh)
    print(f"saved {target} ({target.stat().st_size / 1048576:.1f} MB)")
    return 0


def cmd_gui(args) -> int:
    from .gui import run_gui

    run_gui(args.config)
    return 0


# ------------------------------------------------------------------------ main
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="assetgen", description="Character asset pipeline")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("new", help="create <work>/<id>/config.json")
    p.add_argument("--work", required=True)
    p.add_argument("--id", required=True)
    p.add_argument("--desc", required=True)
    p.add_argument("--name", default="")
    p.set_defaults(func=cmd_new)

    p = sub.add_parser("list", help="list characters in a work folder")
    p.add_argument("--work", required=True)
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("show", help="show one character")
    p.add_argument("--config", required=True)
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("set", help="edit character fields")
    p.add_argument("--config", required=True)
    p.add_argument("--id", default="")
    p.add_argument("--name", default=None)
    p.add_argument("--desc", default=None)
    p.add_argument("--background", default="", metavar="HEX",
                   help="key colour for new generations, e.g. #00ffff")
    p.set_defaults(func=cmd_set)

    p = sub.add_parser("prompt", help="inspect / replace / regenerate a step prompt")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=config.STEPS)
    p.add_argument("--show", action="store_true")
    p.add_argument("--set", dest="text", default="")
    p.add_argument("--file", default="")
    p.add_argument("--reset", action="store_true")
    p.add_argument("--regenerate", action="store_true")
    p.add_argument("--from-history", default="")
    p.set_defaults(func=cmd_prompt)

    p = sub.add_parser("ref", help="set / analyse / clear the step reference image")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=config.STEPS)
    p.add_argument("--file", default="")
    p.add_argument("--clear", action="store_true")
    p.set_defaults(func=cmd_ref)

    p = sub.add_parser("model", help="per-step model override")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=config.STEPS)
    p.add_argument("--set", default="")
    p.add_argument("--clear", action="store_true")
    p.set_defaults(func=cmd_model)

    p = sub.add_parser("history", help="list runs of a step")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=config.STEPS)
    p.set_defaults(func=cmd_history)

    p = sub.add_parser("use", help="select a historical run as current")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=config.STEPS)
    p.add_argument("--run", required=True)
    p.set_defaults(func=cmd_use)

    p = sub.add_parser("sprite", help="tune sprite parameters (and optionally re-export)")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=["idle", "walk"])
    p.add_argument("--char-height", type=float, default=None)
    p.add_argument("--foot-y", type=int, default=None)
    p.add_argument("--frames", type=int, default=None)
    p.add_argument("--period", type=int, default=None)
    p.add_argument("--scale", type=float, default=None)
    p.add_argument("--picks", default="")
    p.add_argument("--offset", action="append", metavar="DIR=dx,dy")
    p.add_argument("--disable", action="append", metavar="DIR")
    p.add_argument("--enable", action="append", metavar="DIR")
    p.add_argument("--export", action="store_true")
    p.set_defaults(func=cmd_sprite)

    p = sub.add_parser("clean", help="re-run background removal on concept/portrait")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=["concept", "portrait"])
    p.add_argument("--tolerance", type=int, default=30, help="颜色容差，越大去掉越多")
    p.add_argument("--method", default="", choices=["", "auto", "net", "learned", "hybrid",
                                                    "edge", "key"],
                   help="auto=有模型就用学习式抠像")
    p.add_argument("--shadow", dest="shadow", action="store_true", default=None,
                   help="去掉脚下的接地投影")
    p.add_argument("--no-shadow", dest="shadow", action="store_false")
    p.add_argument("--matte-side", type=int, default=None,
                   help="学习式抠像推理分辨率：512 更快 / 1024 边缘更细")
    p.add_argument("--matte-threshold", type=float, default=None,
                   help="低于该置信度判为背景（默认 0.5）")
    p.add_argument("--matte-gamma", type=float, default=None,
                   help=">1 收紧轮廓，<1 保留更多软边（默认 1.0）")
    p.add_argument("--trim", type=int, default=None,
                   help="边缘修剪像素数，去掉模型画的镶边（默认 0，可试 1）")
    p.set_defaults(func=cmd_clean)

    p = sub.add_parser("export", help="re-export sprites with current settings")
    p.add_argument("--config", required=True)
    p.add_argument("--step", required=True, choices=["idle", "walk"])
    p.set_defaults(func=cmd_export)

    p = sub.add_parser("run", help="generate steps")
    p.add_argument("--config", required=True)
    p.add_argument("--steps", default="")
    p.add_argument("--next", action="store_true", help="only the first pending step")
    p.add_argument("--only-pending", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--refine", dest="refine", action="store_true", default=None,
                   help="rewrite the next prompt from this run's output (default: project setting)")
    p.add_argument("--no-refine", dest="refine", action="store_false")
    p.add_argument("--quiet", action="store_true")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("project", help="project settings")
    p.add_argument("--work", required=True)
    p.add_argument("--show", action="store_true")
    p.add_argument("--set", action="append", metavar="key=value")
    p.set_defaults(func=cmd_project)

    p = sub.add_parser("style", help="per-step style prompt")
    p.add_argument("--work", required=True)
    p.add_argument("--step", required=True, choices=project.STYLE_STEPS)
    p.add_argument("--set", default=None)
    p.add_argument("--file", default="")
    p.set_defaults(func=cmd_style)

    p = sub.add_parser("api", help="project API settings")
    p.add_argument("--work", required=True)
    p.add_argument("--set", action="append", metavar="key=value")
    p.add_argument("--test", action="store_true")
    p.set_defaults(func=cmd_api)

    p = sub.add_parser("model-fetch", help="download the learned matting model")
    p.set_defaults(func=cmd_model_fetch)

    p = sub.add_parser("gui", help="open the wizard")
    p.add_argument("--config", required=True)
    p.set_defaults(func=cmd_gui)

    args = ap.parse_args(argv)
    try:
        return args.func(args)
    except config.ConfigError as exc:
        print(f"配置错误：\n{exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
