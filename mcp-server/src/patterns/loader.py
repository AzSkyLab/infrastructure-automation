"""Load pattern definitions from config/patterns/*.yaml"""

from pathlib import Path
from typing import Any

import yaml

# Default: look for config relative to repo root
REPO_ROOT = Path(__file__).parent.parent.parent.parent
PATTERNS_DIR = REPO_ROOT / "config" / "patterns"


def load_patterns(patterns_dir: Path | None = None) -> dict[str, dict[str, Any]]:
    """Load all pattern definitions from YAML files.

    Returns:
        Dict mapping pattern name to full pattern definition.
    """
    directory = patterns_dir or PATTERNS_DIR
    patterns: dict[str, dict[str, Any]] = {}

    if not directory.exists():
        return patterns

    for pattern_file in directory.glob("*.yaml"):
        with open(pattern_file) as f:
            pattern = yaml.safe_load(f)
            if pattern and "name" in pattern:
                patterns[pattern["name"]] = pattern

    return patterns
