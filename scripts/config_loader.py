"""
Shared config loader for MX Support Daily Report.

Reads config.json from the project root directory.
Falls back to MX_CONFIG env var for custom path.

Usage:
    from config_loader import load_config, PROJECT_ROOT
    config = load_config()
"""
import json
import os
from pathlib import Path

# Project root = parent of scripts/ directory
SCRIPTS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPTS_DIR.parent


def load_config() -> dict:
    """
    Load configuration from config.json.

    Search order:
      1. Path in MX_CONFIG environment variable
      2. <project_root>/config.json

    Returns:
        dict with all configuration values

    Raises:
        SystemExit if config.json not found
    """
    config_path = os.environ.get("MX_CONFIG", "")
    if config_path:
        path = Path(config_path)
    else:
        path = PROJECT_ROOT / "config.json"

    if not path.exists():
        print(
            f"ERROR: Config file not found: {path}\n"
            f"Please copy config.example.json to config.json and fill in your values:\n"
            f"  copy config.example.json config.json",
            file=__import__("sys").stderr,
        )
        __import__("sys").exit(1)

    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)
