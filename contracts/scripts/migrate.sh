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
pwd
sozo build --profile "$PROFILE" --typescript

# Migrate
echo "Migrating..."
sozo inspect --profile "$PROFILE"
sozo migrate --profile "$PROFILE"

# copy manifests to client
export CLIENT_DIR="../client/src/generated"
cp "./manifest_$PROFILE.json" "$CLIENT_DIR/manifest_$PROFILE.json"

# copy typescript bindings (only in dev)
if [[ "$PROFILE" == "dev" ]]; then
  cp ./bindings/typescript/* "$CLIENT_DIR/"
fi
ls -l "$CLIENT_DIR/"
