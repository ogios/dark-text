#!/usr/bin/env bash
set -eo pipefail

# 工作目录：脚本所在目录（假设你在 repo 根）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 可执行检查
command -v play >/dev/null 2>&1 || {
  echo "需要安装 sox (play)。例如: sudo pacman -S sox"
  exit 1
}
command -v quickshell >/dev/null 2>&1 || echo "警告: quickshell 未找到；如果你想显示 overlay，请安装 quickshell (AUR)。"

QSB_BIN="$(command -v qsb || true)"

# 如果有 qt qsb，并存在 shaders/rays.frag，则生成 TEXT_SHADER（临时输出）
TEXT_SHADER=""
if [[ -n "$QSB_BIN" && -f "./shaders/rays.frag" ]]; then
  TMP_SHADER="$(mktemp -u)/shader.qsb"
  # qsb 接口： qsb --qt6 -o <out> <in>
  "$QSB_BIN" --qt6 -o "$TMP_SHADER" ./shaders/rays.frag 2>/dev/null || true
  if [[ -f "$TMP_SHADER" ]]; then
    TEXT_SHADER="$TMP_SHADER"
    export TEXT_SHADER
  fi
fi

# FONTCONFIG_FILE: 如果你需要单独 fontconfig 可在外部传入，这里我们默认不强制设置
# 如果你确实想使用特定字体配置，可在调用前 export FONTCONFIG_FILE=/path/to/fonts.conf

# build SOUNDS and OVERLAYS arrays from directories
SOUNDS=()
if [[ -d ./sounds ]]; then
  for f in ./sounds/*.mp3; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .mp3)
    SOUNDS+=("$name")
  done
fi

OVERLAYS=()
if [[ -d ./shells ]]; then
  for f in ./shells/*.qml; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .qml)
    OVERLAYS+=("$name")
  done
fi

# defaults (match nix version)
DARK_TEXT="${DARK_TEXT:-Hello, World!}"
DARK_COLOR="${DARK_COLOR:-}"
DARK_DURATION="${DARK_DURATION:-10000}"
SOUND="${SOUND:-victory}"
OVERLAY="${OVERLAY:-victory}"
PLAY_SOUND=true
SHOW_OVERLAY=true

play_sound() {
  # play from sounds dir; silence errors
  local name="$1"
  if [[ -f "./sounds/${name}.mp3" ]]; then
    play "./sounds/${name}.mp3" >/dev/null 2>&1 &
  else
    >&2 echo "音效文件不存在: ./sounds/${name}.mp3"
  fi
}

show_overlay() {
  local name="$1"
  if [[ -f "./shells/${name}.qml" ]]; then
    exec quickshell -p "./shells/${name}.qml" >/dev/null 2>&1
  else
    >&2 echo "Overlay QML 不存在: ./shells/${name}.qml"
  fi
}

contains() {
  local item=$1
  shift
  for x in "$@"; do
    if [[ "$x" == "$item" ]]; then
      return 0
    fi
  done
  return 1
}

show_help() {
  $PLAY_SOUND && play_sound "help" || true
  cat <<EOF
Usage: $0 [OPTIONS]
Options:
  -t, --text <TEXT>       Text to display [default: Hello, World!]
  -c, --color <COLOR>     Text color
  -d, --duration <MS>     Duration in ms [default: 10000]
  -s, --sound <NAME>      Sound to play (available: ${SOUNDS[*]})
  -o, --overlay <NAME>    Overlay to display (available: ${OVERLAYS[*]})
  -n, --no-sound          Don't play sound
  --no-display            Don't show overlay
  --death                 Dark souls death preset
  --new-area              Dark souls new area preset
  -h, --help              Print help
EOF
}

# 参数解析（简化）
while [[ $# -gt 0 ]]; do
  case "$1" in
  -t | --text)
    DARK_TEXT="$2"
    shift 2
    ;;
  -c | --color)
    DARK_COLOR="$2"
    shift 2
    ;;
  -d | --duration)
    DARK_DURATION="$2"
    shift 2
    ;;
  -s | --sound)
    if contains "$2" "${SOUNDS[@]}"; then SOUND="$2"; else
      echo "Unknown sound: $2"
      exit 1
    fi
    shift 2
    ;;
  -o | --overlay)
    if contains "$2" "${OVERLAYS[@]}"; then OVERLAY="$2"; else
      echo "Unknown overlay: $2"
      exit 1
    fi
    shift 2
    ;;
  -n | --no-sound)
    PLAY_SOUND=false
    shift
    ;;
  --no-display)
    SHOW_OVERLAY=false
    shift
    ;;
  --death)
    SOUND="death"
    DARK_DURATION=6500
    DARK_COLOR="#A01212"
    shift
    ;;
  --new-area)
    SOUND="new_area"
    OVERLAY="new_area"
    DARK_DURATION=4500
    shift
    ;;
  -h | --help)
    show_help
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

export DARK_TEXT DARK_COLOR DARK_DURATION

$PLAY_SOUND && play_sound "$SOUND" || true

if $SHOW_OVERLAY; then
  show_overlay "$OVERLAY"
fi
