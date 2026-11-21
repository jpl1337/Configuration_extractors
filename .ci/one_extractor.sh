#!/bin/sh
# $1 = parser repo mount, $2 = extractor file. PIN_OVERRIDES as in import_extractors.sh. Prints full import output.
SRC=$1; F=$2
W=$(mktemp -d); cp -r "$SRC"/. "$W"/; cd "$W"
for pin in $PIN_OVERRIDES; do pkg=${pin%%==*}; sed -i -E "s/^${pkg}==.*/${pin}/I" requirements.txt; done
uv venv -q .venv && VIRTUAL_ENV=$W/.venv uv pip install -q -r requirements.txt >/tmp/install.log 2>&1 || { echo INSTALL FAILED; tail -5 /tmp/install.log; exit 1; }
echo "python $(.venv/bin/python --version 2>&1) pythonnet $(.venv/bin/python -c 'import importlib.metadata as m; print(m.version("pythonnet"))') mono $(mono --version | head -1 | cut -d' ' -f5)"
timeout 120 .venv/bin/python -X faulthandler -c "
import importlib.util
spec = importlib.util.spec_from_file_location('m', '$F')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print('IMPORT OK')
" 2>&1 | grep -vE '^\s+at |^\s*$' | head -25
echo "exit=$?"
