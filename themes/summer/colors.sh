#!/bin/bash
# Summer theme — the original sunset palette.
#
# A theme is COLOUR ONLY: it defines SUNSET (10 gradient SGR stops, low->high)
# and the C_* accents. The engine (statusline.sh) detects colour depth and sets
# $TRUECOLOR *before* sourcing this file, then does all the rendering. Keep this
# file free of logic so themes never duplicate the engine.
#
# SUNSET holds the bare SGR params (bar() wraps them in ESC [ ... m); empty cells
# reuse the same per-index colour, dimmed, so the ramp is always present. The 256
# ramp is hand-picked for 10 distinct steps: teal -> seafoam -> sand -> gold ->
# amber -> coral -> red. No auto-conversion, so no banding.
if [ "$TRUECOLOR" -eq 1 ]; then
  SUNSET=(
    "38;2;46;196;182"  "38;2;91;202;191"  "38;2;154;217;201" "38;2;232;224;168" "38;2;255;212;91"
    "38;2;255;192;58"  "38;2;255;165;58"  "38;2;255;133;82"  "38;2;255;107;74"  "38;2;255;77;77"
  )
  C_MODEL=$'\033[38;2;255;212;91m'   # sun gold
  C_DIR=$'\033[38;2;234;217;176m'    # warm sand
  C_GIT=$'\033[38;2;46;196;182m'     # turquoise water
  C_STAGE=$'\033[38;2;255;212;91m'   # gold
  C_MOD=$'\033[38;2;255;133;82m'     # coral
  C_MUTE=$'\033[38;2;138;151;161m'   # faded
else
  SUNSET=( "38;5;43" "38;5;79" "38;5;115" "38;5;187" "38;5;223"
           "38;5;221" "38;5;215" "38;5;209" "38;5;203" "38;5;196" )
  C_MODEL=$'\033[38;5;221m'
  C_DIR=$'\033[38;5;187m'
  C_GIT=$'\033[38;5;43m'
  C_STAGE=$'\033[38;5;221m'
  C_MOD=$'\033[38;5;209m'
  C_MUTE=$'\033[38;5;102m'
fi
