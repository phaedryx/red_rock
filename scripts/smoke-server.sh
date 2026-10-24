#!/usr/bin/env bash
# Headless end-to-end smoke test: installs a NeoForge 21.1.264 dedicated server, boots it once
# without mods (baseline) and once with red_rock + hello_gem, and reports the startup cost.
#
# usage: scripts/smoke-server.sh [--keep] [--only-red-rock] [--mod-jar JAR] [--expect-failure TEXT]
#   --keep               keep the smoke directory (and the installed server) afterwards
#   --only-red-rock      skip the baseline run
#   --mod-jar JAR        Ruby mod jar to install (default: examples/hello_gem/pkg/hello_gem-0.1.0.jar)
#   --expect-failure T   pass only if mod loading fails and the log contains T
#
# Needs java 21 on PATH (or JAVA_HOME). Writes to ${RED_ROCK_SMOKE_DIR:-$TMPDIR/red_rock-smoke}.
set -euo pipefail

NEO_VERSION=21.1.264
TIMEOUT=300
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE_DIR="${RED_ROCK_SMOKE_DIR:-${TMPDIR:-/tmp}/red_rock-smoke}"
SERVER="$SMOKE_DIR/server"
RUNTIME_JAR="$ROOT/mod/runtime/build/libs/red_rock-0.1.0.jar"
MOD_JAR="$ROOT/examples/hello_gem/pkg/hello_gem-0.1.0.jar"
KEEP=0
BASELINE=1
EXPECT_FAILURE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --only-red-rock) BASELINE=0 ;;
    --mod-jar) MOD_JAR="$2"; shift ;;
    --expect-failure) EXPECT_FAILURE="$2"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -n "${JAVA_HOME:-}" ]]; then PATH="$JAVA_HOME/bin:$PATH"; fi
for jar in "$RUNTIME_JAR" "$MOD_JAR"; do
  [[ -f "$jar" ]] || { echo "missing $jar (build it first; see README)" >&2; exit 2; }
done

trap '' PIPE  # writing "stop" to a server that already exited must not kill the script

now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
elapsed() { perl -e 'printf "%.1f", $ARGV[0] - $ARGV[1]' "$1" "$2"; }

cleanup() { if [[ $KEEP -eq 0 ]]; then rm -rf "$SMOKE_DIR"; fi; }
trap cleanup EXIT

install_server() {
  [[ -x "$SERVER/run.sh" ]] && return
  mkdir -p "$SMOKE_DIR"
  local installer="$SMOKE_DIR/neoforge-$NEO_VERSION-installer.jar"
  curl -fsSL -o "$installer" \
    "https://maven.neoforged.net/releases/net/neoforged/neoforge/$NEO_VERSION/neoforge-$NEO_VERSION-installer.jar"
  (cd "$SMOKE_DIR" && java -jar "$installer" --installServer "$SERVER" > "$SMOKE_DIR/install.log" 2>&1)
  echo "eula=true" > "$SERVER/eula.txt"
  # A one-layer flat world keeps world generation out of the timing.
  cat > "$SERVER/server.properties" <<'PROPS'
online-mode=false
spawn-protection=0
level-type=minecraft\:flat
generator-settings={"layers"\:[{"block"\:"minecraft\:bedrock","height"\:1}],"biome"\:"minecraft\:plains"}
PROPS
}

# run_server NAME MODS... — boots the server with exactly MODS installed. Sets RUN_SECONDS,
# RUN_RSS_MB and RUN_LOG; returns 1 if the server exits before printing "Done (". Once the
# server is up it runs ON_READY_COMMAND (if set) on the console before stopping.
run_server() {
  local name="$1"; shift
  rm -rf "$SERVER/mods" "$SERVER/world" "$SERVER/logs"
  mkdir -p "$SERVER/mods"
  for mod in "$@"; do cp "$mod" "$SERVER/mods/"; done

  local fifo="$SMOKE_DIR/stdin-$name"
  rm -f "$fifo"; mkfifo "$fifo"
  local start; start=$(now)
  local began=$SECONDS peak=0 javapid="" done=0
  (cd "$SERVER" && exec bash ./run.sh nogui < "$fifo" > "$SMOKE_DIR/$name.out" 2>&1) &
  local runpid=$!
  exec 3> "$fifo"

  while (( SECONDS - began < TIMEOUT )); do
    if [[ -z "$javapid" ]]; then javapid=$(pgrep -P "$runpid" java || true); fi
    if [[ -n "$javapid" ]]; then
      local rss; rss=$(ps -o rss= -p "$javapid" 2>/dev/null | tr -d ' ' || true)
      if [[ -n "$rss" ]] && (( rss > peak )); then peak=$rss; fi
    fi
    if grep -q 'Done (' "$SERVER/logs/latest.log" 2>/dev/null; then done=1; break; fi
    if ! kill -0 "$runpid" 2>/dev/null; then break; fi
    sleep 0.2
  done
  RUN_SECONDS=$(elapsed "$(now)" "$start")
  RUN_RSS_MB=$(( peak / 1024 ))
  RUN_LOG="$SMOKE_DIR/$name.log"

  if [[ $done -eq 1 && -n "${ON_READY_COMMAND:-}" ]]; then
    echo "$ON_READY_COMMAND" >&3 || true
    sleep 2
  fi
  if kill -0 "$runpid" 2>/dev/null; then echo stop >&3 || true; fi
  exec 3>&-
  wait "$runpid" || true
  cp "$SERVER/logs/latest.log" "$RUN_LOG" 2>/dev/null || cp "$SMOKE_DIR/$name.out" "$RUN_LOG"
  rm -f "$fifo"
  [[ $done -eq 1 ]]
}

install_server

if [[ -n "$EXPECT_FAILURE" ]]; then
  if run_server red_rock "$RUNTIME_JAR" "$MOD_JAR"; then
    echo "FAIL: server started, but mod loading was expected to fail" >&2; exit 1
  fi
  # A load failure ends in a crash report; the issue text is in the console output.
  if ! grep -qF -- "$EXPECT_FAILURE" "$RUN_LOG" "$SMOKE_DIR/red_rock.out"; then
    echo "FAIL: mod loading failed, but the output does not contain: $EXPECT_FAILURE" >&2; exit 1
  fi
  echo "PASS: mod loading failed with: $EXPECT_FAILURE"
  exit 0
fi

baseline=0 baseline_rss=0
if [[ $BASELINE -eq 1 ]]; then
  run_server baseline || { echo "FAIL: baseline server did not start; see $RUN_LOG" >&2; exit 1; }
  baseline=$RUN_SECONDS baseline_rss=$RUN_RSS_MB
fi

# Summoning the item from the console proves it is in the item registry, not just logged.
ON_READY_COMMAND='summon minecraft:item 0 100 0 {Item:{id:"hello_gem:ruby_shard",count:1}}' \
  run_server red_rock "$RUNTIME_JAR" "$MOD_JAR" || { echo "FAIL: red_rock server did not start; see $RUN_LOG" >&2; exit 1; }
for expected in '[red_rock] JRuby booted in' '[red_rock] hello_gem: registered item hello_gem:ruby_shard' \
    'Summoned new item.hello_gem.ruby_shard'; do
  grep -qF -- "$expected" "$RUN_LOG" || { echo "FAIL: log is missing: $expected" >&2; exit 1; }
done
if grep -q 'ModLoadingException' "$RUN_LOG"; then echo "FAIL: ModLoadingException in log" >&2; exit 1; fi

jruby_boot=$(grep -o 'JRuby booted in [0-9]*' "$RUN_LOG" | grep -o '[0-9]*$')
echo "baseline=${baseline}s red_rock=${RUN_SECONDS}s delta=$(elapsed "$RUN_SECONDS" "$baseline")s jruby_boot=${jruby_boot}ms"
echo "peak_rss baseline=${baseline_rss}MB red_rock=${RUN_RSS_MB}MB delta=$(( RUN_RSS_MB - baseline_rss ))MB"
