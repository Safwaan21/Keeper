#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
xcodebuild -project "$ROOT/Keeper.xcodeproj" -scheme Keeper -configuration Release -derivedDataPath "$ROOT/build" CODE_SIGNING_ALLOWED=NO build
echo "Built $ROOT/build/Build/Products/Release/Keeper.app"
