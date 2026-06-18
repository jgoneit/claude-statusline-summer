#!/bin/bash
# Christmas theme — SCAFFOLD ONLY (palette not yet implemented).
#
# Same contract as themes/summer/colors.sh: the engine sets $TRUECOLOR, then
# sources this file, which must define SUNSET (10 gradient SGR stops, low->high)
# and the C_* accents (C_MODEL C_DIR C_GIT C_STAGE C_MOD C_MUTE).
#
# Values are intentionally left empty. While empty, selecting this theme
# (STATUSLINE_THEME=christmas) renders a plain, UNCOLOURED line — never an error,
# never a blank status line. Fill the values to implement the theme.
#
# TODO(theme): define a red -> white -> green christmas gradient for both depths,
# matching the 10-stop / C_* shape of themes/summer/colors.sh.
if [ "$TRUECOLOR" -eq 1 ]; then
  SUNSET=( "" "" "" "" "" "" "" "" "" "" )   # TODO: 10 truecolor stops, e.g. "38;2;R;G;B"
  C_MODEL=""   # TODO
  C_DIR=""     # TODO
  C_GIT=""     # TODO
  C_STAGE=""   # TODO
  C_MOD=""     # TODO
  C_MUTE=""    # TODO
else
  SUNSET=( "" "" "" "" "" "" "" "" "" "" )   # TODO: 10 256-colour stops, e.g. "38;5;N"
  C_MODEL=""   # TODO
  C_DIR=""     # TODO
  C_GIT=""     # TODO
  C_STAGE=""   # TODO
  C_MOD=""     # TODO
  C_MUTE=""    # TODO
fi
