#!/bin/sh
# Runs inside the container. $1 = tarfile|subprocess. Samples cgroup memory (total and anon) every 0.5s.
X=$(mktemp -d /tmp/cxw/extract.XXXX)
( max_m=0; max_a=0; max_p=0
  while :; do
    m=$(( $(cat /sys/fs/cgroup/memory.current) / 1048576 ))
    a=$(( $(awk '/^anon / {print $2}' /sys/fs/cgroup/memory.stat) / 1048576 ))
    p=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
    [ "$m" -gt "$max_m" ] && max_m=$m
    [ "$a" -gt "$max_a" ] && max_a=$a
    [ "$p" -gt "$max_p" ] && max_p=$p
    echo "$max_m $max_a $max_p" > /tmp/sampler
    sleep 0.5
  done ) &
SAMPLER=$!
python /h/extract_then_load.py "$1" /tmp/cxw/bundles "$X" > /tmp/out.log 2>&1
rc=$?
kill $SAMPLER 2>/dev/null
echo "PY_EXIT=$rc"
echo "MAX_MEM_MIB=$(cut -d' ' -f1 /tmp/sampler) MAX_ANON_MIB=$(cut -d' ' -f2 /tmp/sampler) MAX_PROCS=$(cut -d' ' -f3 /tmp/sampler) CGROUP_PEAK_MIB=$(( $(cat /sys/fs/cgroup/memory.peak) / 1048576 ))"
grep -E "^oom_kill " /sys/fs/cgroup/memory.events | sed "s/^/CGROUP_/"
grep -E "PHASE|CX_RESULT" /tmp/out.log
rm -rf "$X"
