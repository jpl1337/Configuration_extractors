#!/bin/sh
# Runs inside the container. Samples process count and cgroup memory every 0.5s while the service-style load runs.
D=/tmp/cxw/src
( max_p=0; max_m=0
  while :; do
    p=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
    m=$(( $(cat /sys/fs/cgroup/memory.current) / 1048576 ))
    [ "$p" -gt "$max_p" ] && max_p=$p
    [ "$m" -gt "$max_m" ] && max_m=$m
    echo "$max_p $max_m" > /tmp/sampler
    sleep 0.5
  done ) &
SAMPLER=$!
start=$(date +%s)
python /h/cx_load.py load $D/CAPE_PARSERS $D/RussianPanda95 $D/RatKingParser $D/SEKOIA > /tmp/out.log 2>&1
rc=$?
kill $SAMPLER 2>/dev/null
echo "PY_EXIT=$rc WALL_S=$(( $(date +%s) - start ))"
echo "MAX_PROCS=$(cut -d' ' -f1 /tmp/sampler) MAX_SAMPLED_MIB=$(cut -d' ' -f2 /tmp/sampler) MEM_PEAK_MIB=$(( $(cat /sys/fs/cgroup/memory.peak) / 1048576 ))"
echo "CPU_THROTTLED_S=$(awk '/^throttled_usec/ {print int($2/1000000)}' /sys/fs/cgroup/cpu.stat)"
grep -E "^oom_kill " /sys/fs/cgroup/memory.events | sed "s/^/CGROUP_/"
echo "TIMEOUT_LINES=$(grep -c exceeded /tmp/out.log)"
grep -E "CX_RESULT" /tmp/out.log | tail -1
