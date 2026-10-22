#!/usr/bin/env python3

"""
Path containment checks for the dashboard file browser.

The browser may only list and download files that live inside a configured
drive root. Paths are resolved with symlinks followed before the check, so
traversal (..) and symlinks that leave a drive are rejected.
"""

import os
from pathlib import Path


def resolve_within_roots(requested_path, roots):
    """Resolve requested_path and return it when it is inside one of roots.

    Args:
        requested_path: Path supplied by a client. Absolute or relative.
        roots: Iterable of allowed directory paths (drive roots).

    Returns:
        pathlib.Path resolved absolute path when allowed, otherwise None.
    """
    if not requested_path or not isinstance(requested_path, str):
        return None

    try:
        candidate = Path(requested_path).expanduser().resolve(strict=False)
    except (OSError, RuntimeError, ValueError):
        return None

    for root in roots or ():
        if not root:
            continue
        try:
            resolved_root = Path(root).expanduser().resolve(strict=False)
            if os.path.commonpath([str(resolved_root), str(candidate)]) == str(resolved_root):
                return candidate
        except (OSError, RuntimeError, ValueError):
            # ValueError: different drives, or one path is not absolute.
            continue

    return None
