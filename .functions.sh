#!/bin/sh

__fetch() {(
  [ $# -gt 0 ] && \
    { T=8; t=0; g=0
      while [ $g -eq 0 ] && [ $t -lt $T ]; do
        if emerge -f -q "$@"; then g=1; else sleep 1; t=$((t + 1)); fi
      done
      [ $g -eq 1 ]; }
)}

__merge() {
  [ $# -gt 0 ] && \
    emerge --autounmask-write -p -q -v "$@" && \
    echo && \
    emerge --autounmask-write -q "$@"
}

__fetch_and_merge() {
  __fetch "$@" && echo && __merge "$@"
}
