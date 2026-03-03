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


def apply_version_overrides(
    config: dict[str, Any],
    package_version: str | None,
    python_package_version: str | None,
    typescript_npm_version: str | None,
    go_package_version: str | None,
) -> dict[str, Any]:
    cfg = dict(config)
    languages = _ensure_dict("languages", cfg.get("languages"))
    cfg["languages"] = languages

    def ensure_language(name: str) -> dict[str, Any]:
        if name not in languages:
            return {}
        language_config = _ensure_dict(f"languages.{name}", languages.get(name))
        languages[name] = language_config
        additional = _ensure_dict(
            f"languages.{name}.additionalProperties",
            language_config.get("additionalProperties"),
        )
        language_config["additionalProperties"] = additional
        return additional

    effective_python_version = python_package_version or package_version
    effective_typescript_version = typescript_npm_version or package_version
    effective_go_version = go_package_version or package_version

    if effective_python_version:
        ensure_language("python")["packageVersion"] = effective_python_version

    if effective_typescript_version:
        ensure_language("typescript")["npmVersion"] = effective_typescript_version

    if effective_go_version:
        ensure_language("go")["packageVersion"] = effective_go_version

    return cfg


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
    parser.add_argument(
        "--package-version",
        default=None,
        help="Default version for all languages unless overridden per language",
    )
    parser.add_argument(
        "--python-package-version",
        default=None,
        help="Override languages.python.additionalProperties.packageVersion",
    )
    parser.add_argument(
        "--typescript-npm-version",
        default=None,
        help="Override languages.typescript.additionalProperties.npmVersion",
    )
    parser.add_argument(
        "--go-package-version",
        default=None,
        help="Override languages.go.additionalProperties.packageVersion",
    )
    args = parser.parse_args()

    raw_config = json.loads(args.config.read_text(encoding="utf-8"))
    if not isinstance(raw_config, dict):
        raise TypeError("Root config must be an object")
    overridden = apply_version_overrides(
        config=raw_config,
        package_version=args.package_version,
        python_package_version=args.python_package_version,
        typescript_npm_version=args.typescript_npm_version,
        go_package_version=args.go_package_version,
    )
    temp_config = args.out_root / "_effective_config.json"
    temp_config.parent.mkdir(parents=True, exist_ok=True)
    temp_config.write_text(f"{json.dumps(overridden, indent=2)}\n", encoding="utf-8")
    split_config(temp_config, args.out_root)
    temp_config.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
