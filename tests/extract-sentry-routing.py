"""Generate a build-only include of the actual Qt diagnostic routing functions.

This keeps the runtime test tied to production code without linking main(), the
application's SDK dependencies, or loading its real Sentry configuration.
"""
from pathlib import Path
import sys

source = (Path(__file__).resolve().parents[1] / "src/main.cpp").read_text(encoding="utf-8")
globals_start = source.index("static QtMessageHandler g_previousMessageHandler")
globals_end = source.index("static QString startupLocalRootPath()", globals_start)
routing_start = source.index("static QString logLevelToString(QtMsgType type)")
routing_end = source.index("static void autoSelectRenderMode()", routing_start)
destination = Path(sys.argv[1])
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(
    "// Generated from src/main.cpp by tests/extract-sentry-routing.py.\n"
    + source[globals_start:globals_end]
    + source[routing_start:routing_end],
    encoding="utf-8",
)
