#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BIN="$(mktemp -d)/generate-icons"

swiftc -O -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
  Shared/Core/*.swift Shared/Figures/*.swift Shared/Hosts/*.swift \
  Scripts/GenerateIcons/main.swift -o "$BIN"

"$BIN" "$PWD"
