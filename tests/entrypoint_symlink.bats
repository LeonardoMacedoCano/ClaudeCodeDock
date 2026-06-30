#!/usr/bin/env bats

load helpers

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ENTRYPOINT="$PROJECT_ROOT/docker/entrypoint.sh"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
  setup_entrypoint_env
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "creates .claude.json symlink pointing into the volume" {
  run bash "$ENTRYPOINT"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude.json" ]
  TARGET="$(readlink "$HOME/.claude.json")"
  [ "$TARGET" = "$HOME/.claude/.claude.json" ]
}

@test "migrates existing plain .claude.json file into the volume before symlinking" {
  echo '{"token":"existing"}' > "$HOME/.claude.json"

  run bash "$ENTRYPOINT"
  [ "$status" -eq 0 ]

  # File moved into volume
  [ -f "$HOME/.claude/.claude.json" ]
  CONTENT="$(cat "$HOME/.claude/.claude.json")"
  [ "$CONTENT" = '{"token":"existing"}' ]

  # Symlink now points there
  [ -L "$HOME/.claude.json" ]
  TARGET="$(readlink "$HOME/.claude.json")"
  [ "$TARGET" = "$HOME/.claude/.claude.json" ]
}

@test "restores credentials from latest backup when volume file is missing" {
  BACKUP_DIR="$HOME/.claude/backups"
  mkdir -p "$BACKUP_DIR"
  echo '{"token":"from-backup"}' > "$BACKUP_DIR/.claude.json.backup.2024-01-01"

  run bash "$ENTRYPOINT"
  [ "$status" -eq 0 ]

  [ -f "$HOME/.claude/.claude.json" ]
  CONTENT="$(cat "$HOME/.claude/.claude.json")"
  [ "$CONTENT" = '{"token":"from-backup"}' ]
}

@test "does not overwrite volume file with backup when volume file already exists" {
  echo '{"token":"in-volume"}' > "$HOME/.claude/.claude.json"

  BACKUP_DIR="$HOME/.claude/backups"
  mkdir -p "$BACKUP_DIR"
  echo '{"token":"from-backup"}' > "$BACKUP_DIR/.claude.json.backup.2024-01-01"

  run bash "$ENTRYPOINT"
  [ "$status" -eq 0 ]

  CONTENT="$(cat "$HOME/.claude/.claude.json")"
  [ "$CONTENT" = '{"token":"in-volume"}' ]
}

@test "does not recreate symlink when it already points to the right target" {
  ln -sf "$HOME/.claude/.claude.json" "$HOME/.claude.json"

  run bash "$ENTRYPOINT"
  [ "$status" -eq 0 ]

  [ -L "$HOME/.claude.json" ]
  TARGET="$(readlink "$HOME/.claude.json")"
  [ "$TARGET" = "$HOME/.claude/.claude.json" ]
}
