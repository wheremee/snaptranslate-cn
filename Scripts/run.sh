#!/bin/bash
# 构建并启动
set -e
cd "$(dirname "$0")/.."
bash Scripts/build_app.sh
open "build/SnapTranslate CN.app"
