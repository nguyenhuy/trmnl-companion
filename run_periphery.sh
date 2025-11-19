#!/bin/bash

# Periphery script for unused code detection
# Runs on iPhone simulator with iOS 18.6
# Usage: ./run_periphery.sh [--clean]

echo "🔍 Running Periphery..."

# Add clean-build option if requested
if [[ "$1" == "--clean" ]]; then
  echo "Running with clean build..."
  CLEAN_FLAG="--clean-build"
else
  echo "Running incremental build..."
fi

# Build command options
PERIPHERY_CMD="periphery scan \
  --project Companion.xcodeproj \
  --schemes Companion \
  $CLEAN_FLAG \
  -- -destination \"platform=iOS Simulator,name=iPhone 16,OS=18.6\""


# Run Periphery
echo "Analyzing for unused code..."
eval $PERIPHERY_CMD

echo "✅ Periphery analysis complete!"