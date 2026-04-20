#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "usage: $0 <package>..." >&2
    exit 2
fi

os="$(uname -s)"

if [[ "$os" == "Darwin" ]]; then
    missing=()

    for package in "$@"; do
        if brew list --formula "$package" >/dev/null 2>&1 || brew list --cask "$package" >/dev/null 2>&1; then
            echo "[ok] $package"
        else
            missing+=("$package")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "Done: all packages installed."
        exit 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "[miss] brew" >&2
        echo "[fix] install Homebrew from https://brew.sh, then rerun: $0 ${missing[*]}" >&2
        exit 1
    fi

    brew install "${missing[@]}"
else
    missing=()

    for package in "$@"; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            echo "[ok] $package"
        else
            missing+=("$package")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "Done: all packages installed."
        exit 0
    fi

    if ! command -v paru >/dev/null 2>&1; then
        echo "[miss] paru" >&2
        echo "[fix] install paru, then rerun: $0 ${missing[*]}" >&2
        exit 1
    fi

    paru -S --noconfirm "${missing[@]}"
fi
