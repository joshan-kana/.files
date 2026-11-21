#!/usr/bin/env bash
id="${1:-}"

if ! [[ $id =~ ^[0-9]+$ ]]; then
  exit 2
fi

cliphist decode "$id" | wl-copy
