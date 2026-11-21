"""Mirrors ConfigExtractor 4.8's _download_rules: unpack each source bundle in-process, then reload parsers.

argv[1]: "tarfile" (4.8 service: tarfile r:zst in-process) or "subprocess" (4.7 service: tar --zstd)
argv[2]: directory holding one .tar.zst bundle per source
argv[3]: extraction root
"""

import json
import logging
import os
import subprocess
import sys
import tarfile
import time

logging.basicConfig(level=logging.INFO, stream=sys.stderr, format="%(asctime)s %(levelname)s %(message)s")

# The service process has these loaded before it ever unpacks rules.
import assemblyline_v4_service.common.base  # noqa: E402,F401
from configextractor.main import ConfigExtractor  # noqa: E402


def rss_mib() -> int:
    with open("/proc/self/status") as f:
        for line in f:
            if line.startswith("VmRSS:"):
                return int(line.split()[1]) // 1024
    return -1


method, bundle_dir, extract_root = sys.argv[1:4]
result = {"method": method, "rss_start_mib": rss_mib()}
dirs = []
start = time.monotonic()
for name in sorted(os.listdir(bundle_dir)):
    dst = os.path.join(extract_root, name)
    os.makedirs(dst)
    bundle = os.path.join(bundle_dir, name)
    if method == "tarfile":
        with tarfile.open(bundle, "r:zst") as tar:
            tar.extractall(path=dst, filter="fully_trusted")
    else:
        subprocess.check_output(["tar", "--zstd", "-xf", bundle, "-C", dst])
    dirs.append(dst)
result["extract_seconds"] = round(time.monotonic() - start, 1)
result["rss_after_extract_mib"] = rss_mib()
print("PHASE extracted " + json.dumps(result), flush=True)

start = time.monotonic()
try:
    cx = ConfigExtractor(parsers_dirs=dirs, logger=logging.getLogger("cx"), create_venv=True, skip_install=True)
    result["parsers"] = len(cx.parsers)
except Exception as e:  # noqa: BLE001 - reported, not handled
    result["error"] = f"{type(e).__name__}: {str(e)[:200]}"
result["load_seconds"] = round(time.monotonic() - start, 1)
result["rss_after_load_mib"] = rss_mib()
print("CX_RESULT " + json.dumps(result), flush=True)
