#!/usr/bin/env bash
# Generates any missing Android/iOS platform files from the Flutter template
# without touching files already in the repo (our customised Gradle config,
# AndroidManifest.xml and Info.plist win). Safe to run repeatedly.
#
# Committing the generated android/ and ios/ folders is fine too; this script
# then becomes a no-op.
set -euo pipefail

ORG="com.shristov92"
PROJECT="sshmagic"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

flutter create \
  --org "$ORG" \
  --project-name "$PROJECT" \
  --platforms android,ios \
  --no-pub \
  "$tmp/$PROJECT" >/dev/null

for platform in android ios; do
  rsync -a --ignore-existing "$tmp/$PROJECT/$platform/" "$root/$platform/"
done

echo "Platform folders ready (android/, ios/)."
