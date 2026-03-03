#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_OUTPUT_DIRS = {
    "python": "out/python-client",
    "typescript": "out/typescript-client",
    "go": "out/go-client",
}

SPECIAL_KEYS = {"ignoreList", "additionalProperties"}


def _strip_special(values: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in values.items() if key not in SPECIAL_KEYS}


def _ensure_dict(name: str, value: Any) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise TypeError(f"{name} must be an object")
    return value


def _ensure_list(name: str, value: Any) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise TypeError(f"{name} must be a list of strings")
    return value


def split_config(config_path: Path, out_root: Path) -> None:
    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    if not isinstance(cfg, dict):
        raise TypeError("Root config must be an object")

    common = _ensure_dict("common", cfg.get("common"))
    languages = _ensure_dict("languages", cfg.get("languages"))

    common_additional = _ensure_dict(
        "common.additionalProperties", common.get("additionalProperties")
    )
    common_ignore = _ensure_list("common.ignoreList", common.get("ignoreList"))

    for language, default_output_dir in DEFAULT_OUTPUT_DIRS.items():
        if language not in languages:
            raise KeyError(f"Missing languages.{language} in unified config")

        lang_cfg = _ensure_dict(f"languages.{language}", languages.get(language))
        merged = {**_strip_special(common), **_strip_special(lang_cfg)}

        lang_additional = _ensure_dict(
            f"languages.{language}.additionalProperties",
            lang_cfg.get("additionalProperties"),
        )
        additional = {**common_additional, **lang_additional}
        if additional:
            merged["additionalProperties"] = additional

        lang_ignore = _ensure_list(
            f"languages.{language}.ignoreList", lang_cfg.get("ignoreList")
        )
        ignore_list = [*common_ignore, *lang_ignore]

        output_dir = merged.get("outputDir", default_output_dir)
        if not isinstance(output_dir, str):
            raise TypeError(f"languages.{language}.outputDir must be a string")
        if not output_dir.startswith("/"):
            output_dir = f"/src/{output_dir}"

        language_dir = out_root / language
        language_dir.mkdir(parents=True, exist_ok=True)
        (language_dir / "openapi-generator-config.json").write_text(
            f"{json.dumps(merged, indent=2)}\n",
            encoding="utf-8",
        )
        (language_dir / "openapi-generator-ignore-list.txt").write_text(
            ",".join(ignore_list),
            encoding="utf-8",
        )
        (language_dir / "openapi-generator-out-dir.txt").write_text(
            f"{output_dir}\n",
            encoding="utf-8",
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Split unified openapi-generator config")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("/src/openapi-generator.config.json"),
        help="Path to the unified JSON config file",
    )
    parser.add_argument(
        "--out-root",
        type=Path,
        default=Path("/out/config"),
        help="Output directory for per-language files",
    )
    args = parser.parse_args()

    split_config(args.config, args.out_root)


if __name__ == "__main__":
    main()
