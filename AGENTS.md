# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Code Formatting

- If you modify files under `src/`, run `clang-format -i` on the changed files before finishing.
- If you modify files under `qml/`, run `qmlformat -i` on the changed `.qml` files before finishing.

Qt is installed at `D:\Qt`. These formatters are not on `PATH`; invoke them by full path from the Qt bin directory, e.g. `D:\Qt\6.7.3\msvc2022_64\bin\qmlformat.exe`.

## 6. Building

Initialize the MSVC environment first (`"D:\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"`), then run from the configured build dir `build\Desktop_Qt_6_7_3_MSVC2022_64bit-Release`.

Run qmake (regenerates the makefiles):

```
D:/Qt/6.7.3/msvc2022_64/bin/qmake.exe D:\code\DataSafeboxClientQT\datasafebox-qt-client.pro -spec win32-msvc "CONFIG+=qtquickcompiler" SENTRY_ROOT_DIR=D:/code/vcpkg/installed/x64-windows DSCC_DIR=D:/code/data-safebox-core/installed && D:/Qt/Tools/QtCreator/bin/jom/jom.exe qmake_all
```

Then compile (the command above only regenerates makefiles; this step does the actual build):

```
D:/Qt/Tools/QtCreator/bin/jom/jom.exe
```

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.