"""Loads parser sources the way the ConfigExtractor service and updater do.

argv[1]: "install" (updater: build venvs) or "load" (service: skip_install=True)
argv[2:]: parser source directories
"""

import json
import logging
import sys
import time

logging.basicConfig(level=logging.INFO, stream=sys.stderr, format="%(asctime)s %(levelname)s %(message)s")

from configextractor.main import ConfigExtractor  # noqa: E402

mode, dirs = sys.argv[1], sys.argv[2:]
start = time.monotonic()
error = None
cx = None
try:
    if mode == "install":
        # The updater builds each source on its own.
        for d in dirs:
            ConfigExtractor(parsers_dirs=[d], logger=logging.getLogger("cx"), create_venv=True)
    else:
        cx = ConfigExtractor(parsers_dirs=dirs, logger=logging.getLogger("cx"), create_venv=True, skip_install=True)
except Exception as e:  # noqa: BLE001 - reported, not handled
    error = f"{type(e).__name__}: {str(e)[:300]}"

result = {"mode": mode, "seconds": round(time.monotonic() - start, 1), "error": error}
if cx is not None:
    result["parsers"] = len(cx.parsers)
    result["by_source"] = {d: sum(1 for p in cx.parsers.values() if p.module_path.startswith(d)) for d in dirs}
print("CX_RESULT " + json.dumps(result), flush=True)
