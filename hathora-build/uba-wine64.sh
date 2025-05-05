#!/usr/bin/env bash
# Wrapper script for Wine providing a hook point to modify incoming command-line arguments from the Windows application to run
# Right now, this script is mostly called by remote execution tasks, which run UnrealBuildAccelerator (UBA)
export WINEDEBUG=-all
export WINEARCH=win64
export WINEPREFIX=/home/user/.wine

# Overwrite UE_HORDE_SHARED_DIR to point to C:\ which will exist inside Wine.
# This in turn is mounted under WINEPREFIX specified above
export UE_HORDE_SHARED_DIR="C:\\Uba"

if [ -n "$${UE_HORDE_TERMINATION_SIGNAL_FILE}" ]; then
  # Rewrite Linux path to be a Windows path under Z:\ which maps to / in Wine (replacing slashes with backslashes)
  export UE_HORDE_TERMINATION_SIGNAL_FILE="Z:$${UE_HORDE_TERMINATION_SIGNAL_FILE//\//\\}"
fi

/usr/bin/wine64 "$@"