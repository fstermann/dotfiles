#!/usr/bin/env python3
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from statusline import hook, launcher

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "hook":
        hook.record()
    elif len(sys.argv) > 1 and sys.argv[1] == "_child":
        raise SystemExit(launcher.child(sys.argv[2]))
    else:
        raise SystemExit(launcher.launch(sys.argv[1:]))
