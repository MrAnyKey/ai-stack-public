set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

root := justfile_directory()
chezmoi_config := root + "/.config/chezmoi/chezmoi.toml"
chezmoi_state := root + "/.config/chezmoi/chezmoistate.boltdb"

default:
    @just --list

run: bootstrap

bootstrap: install ensure-chezmoi-config ensure-llama-cpp service-start podman-bootstrap

destroy:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" destroy

    systemctl --user stop litellm.service llama-swap.service >/dev/null 2>&1 || true
    systemctl --user reset-failed litellm.service llama-swap.service >/dev/null 2>&1 || true

    service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    rm -f \
        "$service_dir/litellm.service" \
        "$service_dir/llama-swap.service"

    systemctl --user daemon-reload >/dev/null 2>&1 || true

    if command -v launchctl >/dev/null 2>&1; then
        launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.anykey.ai-stack.litellm.plist" >/dev/null 2>&1 || true
        launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.anykey.ai-stack.llama-swap.plist" >/dev/null 2>&1 || true
    fi

    rm -f \
        "$HOME/Library/LaunchAgents/com.anykey.ai-stack.litellm.plist" \
        "$HOME/Library/LaunchAgents/com.anykey.ai-stack.llama-swap.plist"

    rm -f \
        "{{ root }}/litellm/config.yaml" \
        "{{ root }}/llama-swap/config.yaml"

    echo "[ok] destroyed ai-stack generated services and runtime config"

dev-setup: precommit-install

git-sync:
    #!/usr/bin/env bash
    set -euo pipefail

    "{{ root }}/scripts/sync_with_master.sh"

install:
    #!/usr/bin/env bash
    set -euo pipefail

    bash "{{ root }}/scripts/install_packages.sh" chezmoi keepassxc uv llama-swap

ensure-chezmoi-config:
    #!/usr/bin/env bash
    set -euo pipefail

    config="{{ chezmoi_config }}"
    example="{{ root }}/.config/chezmoi/chezmoi.example.toml"

    mkdir -p "$(dirname "$config")"

    if [ ! -f "$config" ]; then
        cp "$example" "$config"
        echo "[ok] created $config"
    fi

    if [ -n "${KEEPASSXC_DATABASE:-}" ]; then
        sed -i "s|^database = .*|database = \"${KEEPASSXC_DATABASE}\"|" "$config"
    fi

    database="$(sed -n 's/^database = "\(.*\)"/\1/p' "$config" | head -n 1)"

    if [ -z "$database" ] || [ "$database" = "/path/to/Passwords.kdbx" ]; then
        echo "[miss] KeePassXC database path in $config"
        echo "[fix] KEEPASSXC_DATABASE=/path/to/Passwords.kdbx just run"
        exit 1
    fi

    if [ ! -f "$database" ]; then
        echo "[miss] KeePassXC database file: $database"
        exit 1
    fi

    echo "[ok] KeePassXC database configured"

ensure-llama-cpp:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -x "{{ root }}/llama-cpp/llama-server" ]; then
        echo "[ok] llama-cpp/llama-server"
        exit 0
    fi

    just -f "{{ root }}/Justfile" build

render-configs: render-quadlets render-litellm-configs render-llama-swap-configs

render-litellm-configs: ensure-chezmoi-config
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -f "{{ root }}/.env" ]; then
        set -a
        source "{{ root }}/.env"
        set +a
    fi

    chezmoi \
        --config "{{ chezmoi_config }}" \
        --source "{{ root }}" \
        --destination "{{ root }}" \
        --persistent-state "{{ chezmoi_state }}" \
        apply \
        "{{ root }}/litellm/.env" \
        "{{ root }}/litellm/config.yaml"

render-llama-swap-configs: ensure-chezmoi-config
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -f "{{ root }}/.env" ]; then
        set -a
        source "{{ root }}/.env"
        set +a
    fi

    chezmoi \
        --config "{{ chezmoi_config }}" \
        --source "{{ root }}" \
        --destination "{{ root }}" \
        --persistent-state "{{ chezmoi_state }}" \
        apply \
        "{{ root }}/llama-swap/config.yaml"

render-quadlets:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" render-configs

podman-bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" bootstrap

podman-destroy:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" destroy

service-start:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/llama-swap/Justfile" service-restart
    just -f "{{ root }}/litellm/Justfile" service-restart

service-stop:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/litellm/Justfile" service-stop
    just -f "{{ root }}/llama-swap/Justfile" service-stop

service-status:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/llama-swap/Justfile" service-status
    just -f "{{ root }}/litellm/Justfile" service-status

launchd-install:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/llama-swap/Justfile" launchd-install
    just -f "{{ root }}/litellm/Justfile" launchd-install

launchd-start:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/llama-swap/Justfile" launchd-start
    just -f "{{ root }}/litellm/Justfile" launchd-start

launchd-stop:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/litellm/Justfile" launchd-stop
    just -f "{{ root }}/llama-swap/Justfile" launchd-stop

launchd-status:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/llama-swap/Justfile" launchd-status
    just -f "{{ root }}/litellm/Justfile" launchd-status

quadlet-install:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" quadlet-install

quadlet-start:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" quadlet-start

quadlet-stop:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" quadlet-stop

quadlet-status:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" quadlet-status

quadlet-logs:
    #!/usr/bin/env bash
    set -euo pipefail

    just -f "{{ root }}/podman/Justfile" quadlet-logs

models-check:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "{{ root }}/scripts/update_models.sh" --check-only

models-download:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "{{ root }}/scripts/update_models.sh" --all

models-prune:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "{{ root }}/scripts/update_models.sh" --prune

models-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "{{ root }}/scripts/update_models.sh" --all --prune

precommit-install:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v pre-commit >/dev/null 2>&1; then
        uv tool install pre-commit
    fi

    pre-commit install
    pre-commit install --hook-type pre-push

precommit-run:
    #!/usr/bin/env bash
    set -euo pipefail

    pre-commit run --all-files

build:
    #!/usr/bin/env bash
    set -euo pipefail

    src="vendor/llama.cpp"
    out="llama-cpp"
    os="$(uname -s)"

    if ! git -C "$src" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git submodule update --init --recursive "$src"
    fi
    git -C "$src" fetch origin master --quiet
    latest="$(git -C "$src" rev-parse origin/master)"
    current="$(git -C "$src" rev-parse HEAD)"

    if [[ "$current" != "$latest" ]]; then
        echo "Updating vendor/llama.cpp: $current -> $latest"
        git -C "$src" checkout --detach "$latest"
        current="$latest"
    fi

    installed="$(cat "$out/.sha" 2>/dev/null || true)"

    if [[ "$current" == "$installed" && -x "$out/llama-server" ]]; then
        echo "llama-cpp already built for latest commit ($current)"
        just update-readme
        exit 0
    fi

    tmp="$(mktemp -d /tmp/llama.cpp-build.XXXXXX)"
    stage="$(mktemp -d /tmp/llama.cpp-stage.XXXXXX)"
    trap 'rm -rf "$tmp" "$stage"' EXIT

    args=(
        -S "$src"
        -B "$tmp"
        -DCMAKE_BUILD_TYPE=Release
        -DGGML_NATIVE=ON
    )

    if [[ "$os" == "Darwin" ]]; then
        echo "macOS detected — building with Metal"
        args+=(
            -DGGML_METAL=ON
            -DGGML_OPENMP=OFF
        )
        nproc_cmd="$(sysctl -n hw.logicalcpu)"
        cmake_cmd="cmake"
    else
        cuda="/opt/cuda"
        nvcc="/opt/cuda/bin/nvcc"
        test -d "$cuda" || { echo "CUDA toolkit not found at $cuda"; exit 1; }
        test -x "$nvcc" || { echo "nvcc not found at $nvcc"; exit 1; }
        echo "Linux detected — building with CUDA (arch 89)"
        args+=(
            -DGGML_CUDA=ON
            -DGGML_OPENMP=ON
            -DCMAKE_CUDA_ARCHITECTURES=89
            -DCUDAToolkit_ROOT="$cuda"
            -DCMAKE_CUDA_COMPILER="$nvcc"
        )
        nproc_cmd="$(nproc)"
        cmake_cmd="CUDACXX=$nvcc cmake"
    fi

    if command -v ccache >/dev/null 2>&1; then
        echo "Using ccache"
        args+=(
            -DCMAKE_C_COMPILER_LAUNCHER=ccache
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
        )
        [[ "$os" != "Darwin" ]] && args+=(-DCMAKE_CUDA_COMPILER_LAUNCHER=ccache)
    else
        echo "ccache not found, building without it"
    fi

    echo "Building llama.cpp into $tmp"

    if [[ "$os" == "Darwin" ]]; then
        cmake "${args[@]}"
    else
        CUDACXX="$nvcc" cmake "${args[@]}"
    fi
    cmake --build "$tmp" -j "$nproc_cmd"

    cp -a "$tmp/bin/." "$stage/"
    [[ -d "$tmp/lib" ]] && cp -a "$tmp/lib/." "$stage/"

    echo "$current" > "$stage/.sha"

    rm -rf "$out"
    mkdir -p "$out"
    cp -a "$stage/." "$out/"

    echo "Updated llama-cpp to $current"

    just update-readme

rebuild:
    #!/usr/bin/env bash
    set -euo pipefail

    rm -rf llama-cpp
    just build

status:
    #!/usr/bin/env bash
    set -euo pipefail

    src="vendor/llama.cpp"
    out="llama-cpp"

    git -C "$src" fetch origin master --quiet || true

    repo_commit="$(git -C "$src" rev-parse HEAD)"
    remote_commit="$(git -C "$src" rev-parse origin/master 2>/dev/null || true)"
    installed_commit="$(cat "$out/.sha" 2>/dev/null || true)"

    echo "repo:      $repo_commit"
    echo "remote:    $remote_commit"
    echo "installed: $installed_commit"

    if [[ -n "$remote_commit" && "$repo_commit" != "$remote_commit" ]]; then
        echo "note: repo submodule is behind origin/master"
    fi

bump-llama:
    #!/usr/bin/env bash
    set -euo pipefail

    src="vendor/llama.cpp"

    git submodule update --init --recursive
    git -C "$src" fetch origin master --quiet
    latest="$(git -C "$src" rev-parse origin/master)"
    git -C "$src" checkout --detach "$latest"

    echo "vendor/llama.cpp moved to $latest"
    echo "next: run 'just build'"

update-readme:
    #!/usr/bin/env bash
    set -euo pipefail

    src="vendor/llama.cpp"
    readme="README.md"

    test -f "$readme" || { echo "README.md not found, skipping"; exit 0; }

    version="$(git -C "$src" describe --tags --always 2>/dev/null || git -C "$src" rev-parse --short HEAD)"
    commit="$(git -C "$src" rev-parse --short HEAD)"
    date="$(git -C "$src" log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M:%S')"

    perl -0pi -e 's|<!-- LLAMA_CPP_VERSION_START -->.*?<!-- LLAMA_CPP_VERSION_END -->|<!-- LLAMA_CPP_VERSION_START -->\n- version: `'"$version"'`\n- commit: `'"$commit"'`\n- date: `'"$date"'`\n<!-- LLAMA_CPP_VERSION_END -->|s' "$readme"

    echo "README updated: $version / $commit / $date"

ccache-init:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v ccache >/dev/null 2>&1 || { echo "ccache not installed"; exit 1; }

    ccache --set-config=max_size=20G
    ccache -s

ccache-stats:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v ccache >/dev/null 2>&1 || { echo "ccache not installed"; exit 1; }

    ccache -s
