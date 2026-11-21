"""Bundles each parser source the way the 4.8 updater does (tarfile w:zst, arcname='.')."""

import os
import sys
import tarfile

src_root, out_dir = sys.argv[1:3]
os.makedirs(out_dir, exist_ok=True)
for name in sorted(os.listdir(src_root)):
    with tarfile.open(os.path.join(out_dir, name), "w:zst") as tar:
        tar.add(os.path.join(src_root, name), arcname=".")
    print(f"{name}: {os.path.getsize(os.path.join(out_dir, name)) // 1048576} MiB compressed")
