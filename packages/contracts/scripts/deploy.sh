#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <profile>"
  exit 1
fi

PROFILE=$1

# Navigate to the contracts directory
# This assumes the script is located in packages/contracts/scripts/
cd "$(dirname "$0")/.."

echo "Deploying with profile: $PROFILE"

# Build first
echo "Building..."
sozo build --profile "$PROFILE"

# Migrate
echo "Migrating..."
sozo inspect --profile "$PROFILE"
sozo migrate --profile "$PROFILE"
