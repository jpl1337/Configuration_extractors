#!/bin/sh
# Runs inside cccs/assemblyline-service-configextractor:4.8.x.
# $1 = read-only parser repo mount. PIN_OVERRIDES = space-separated "pkg==ver" applied to requirements.txt.
set -e
SRC=$1
W=$(mktemp -d)
cp -r "$SRC"/. "$W"/
cd "$W"
for pin in $PIN_OVERRIDES; do
  pkg=${pin%%==*}
  sed -i -E "s/^${pkg}==.*/${pin}/I" requirements.txt
done
echo "requirements: $(grep -E '^(pythonnet|capstone)' requirements.txt | tr '\n' ' ')"
uv venv -q .venv
if ! VIRTUAL_ENV=$W/.venv uv pip install -q -r requirements.txt > /tmp/install.log 2>&1; then
  echo "INSTALL FAILED"; tail -5 /tmp/install.log; exit 1
fi
for f in *.py; do
  out=$(timeout 120 .venv/bin/python -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('m', '$f')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
" 2>&1) && echo "OK    $f" || echo "FAIL  $f :: $(printf '%s' "$out" | grep -E 'Error|Exception|symbol' | tail -1 | cut -c1-140)"
done
