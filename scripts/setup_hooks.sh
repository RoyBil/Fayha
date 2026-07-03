#!/usr/bin/env bash
# Install the pre-push git hook for the Fayha project.
# Run once from the repo root:  bash scripts/setup_hooks.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
FLUTTER_DIR="$REPO_ROOT/FayhaApp/fayha"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "ERROR: Flutter project not found at $FLUTTER_DIR" >&2
  exit 1
fi

cat > "$HOOKS_DIR/pre-push" << HOOK
#!/usr/bin/env bash
# pre-push hook — mirrors the CI checks.
# Block the push if format, analysis, or tests fail.
set -euo pipefail

REPO_ROOT="\$(git rev-parse --show-toplevel)"
FLUTTER_DIR="\$REPO_ROOT/FayhaApp/fayha"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  pre-push: running quality checks …      ║"
echo "╚══════════════════════════════════════════╝"

cd "\$FLUTTER_DIR"

# 1. Install / refresh dependencies
echo ""
echo "▶ flutter pub get"
flutter pub get

# 2. Formatting
echo ""
echo "▶ dart format --set-exit-if-changed ."
if ! dart format --set-exit-if-changed .; then
  echo ""
  echo "✗ Formatting failures found."
  echo "  Run  dart format .  inside FayhaApp/fayha to fix them, then re-push."
  exit 1
fi

# 3. Static analysis
echo ""
echo "▶ flutter analyze"
if ! flutter analyze; then
  echo ""
  echo "✗ Analysis errors found. Fix them before pushing."
  exit 1
fi

# 4. Tests
echo ""
echo "▶ flutter test"
if ! flutter test; then
  echo ""
  echo "✗ One or more tests failed. Fix them before pushing."
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✓ All checks passed — push allowed.     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
HOOK

chmod +x "$HOOKS_DIR/pre-push"

echo "✓ pre-push hook installed at $HOOKS_DIR/pre-push"
echo ""
echo "To uninstall:  rm $HOOKS_DIR/pre-push"
echo "To skip once:  git push --no-verify   (use sparingly)"
