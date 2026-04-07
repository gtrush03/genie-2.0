#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release 2>&1
echo "Built at: .build/release/Genie"
echo "To run: .build/release/Genie"
