#!/usr/bin/env bash
# Replace complete theme sources so removed modules cannot survive an upgrade.
# Called only after a reviewed release is unpacked; this does not import themes.
set -euo pipefail
release_dir="${1:?Pass unpacked release directory}"
shared="${2:?Pass shared release directory}"
for name in sidebar interface; do
  stage=$(mktemp -d "$release_dir/$name.XXXXXX")
  tar -xzf "$release_dir/svdex-$name.tar.gz" -C "$stage"
  test -f "$stage/about.json"
  previous="$release_dir/previous-$name-sources"
  test ! -e "$previous"
  if test -e "$shared/$name"; then mv "$shared/$name" "$previous"; fi
  if ! mv "$stage" "$shared/$name"; then
    if test -e "$previous"; then mv "$previous" "$shared/$name"; fi
    exit 1
  fi
done
