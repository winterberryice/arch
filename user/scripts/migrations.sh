#!/bin/bash
# User-level migration management
# Called by wintarch-user-update

set -e

WINTARCH_PATH="${WINTARCH_PATH:-/opt/wintarch}"
MIGRATIONS_DIR="$WINTARCH_PATH/user/migrations"
STATE_DIR="$HOME/.local/state/wintarch/migrations"
SKIPPED_DIR="$STATE_DIR/skipped"

# Show migration status
show_status() {
    local show_all="${1:-false}"

    echo -e "\e[1mUser Migrations:\e[0m"
    echo ""

    local has_pending=false
    local has_completed=false
    local has_skipped=false
    local has_any=false

    for file in "$MIGRATIONS_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        has_any=true

        local filename=$(basename "$file")
        local name="${filename%.sh}"

        if [[ -f "$STATE_DIR/$filename" ]]; then
            if [[ "$show_all" == "true" ]]; then
                echo -e "  \e[32m✓\e[0m $name (completed)"
                has_completed=true
            fi
        elif [[ -f "$SKIPPED_DIR/$filename" ]]; then
            echo -e "  \e[33m⊘\e[0m $name (skipped)"
            has_skipped=true
        else
            echo -e "  \e[34m●\e[0m $name (pending)"
            has_pending=true
        fi
    done

    if [[ "$has_any" == "false" ]]; then
        echo "  No migrations defined."
    elif [[ "$has_pending" == "false" && "$has_skipped" == "false" ]]; then
        if [[ "$show_all" == "false" ]]; then
            echo "  No pending migrations."
        fi
    fi
}

# Run pending migrations
run_migrations() {
    mkdir -p "$STATE_DIR" "$SKIPPED_DIR"

    local has_any=false

    for file in "$MIGRATIONS_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        has_any=true

        local filename=$(basename "$file")

        # Skip if already completed or skipped
        [[ -f "$STATE_DIR/$filename" ]] && continue
        [[ -f "$SKIPPED_DIR/$filename" ]] && continue

        echo -e "\e[32mRunning user migration: ${filename%.sh}\e[0m"

        if bash "$file"; then
            touch "$STATE_DIR/$filename"
            echo -e "\e[32mMigration completed: ${filename%.sh}\e[0m"
        else
            if command -v gum &>/dev/null; then
                if gum confirm "Migration ${filename%.sh} failed. Skip and continue?"; then
                    touch "$SKIPPED_DIR/$filename"
                    echo "Skipped: ${filename%.sh}"
                else
                    echo "Aborting migrations."
                    exit 1
                fi
            else
                echo "Migration failed. Aborting." >&2
                exit 1
            fi
        fi
    done

    if [[ "$has_any" == "true" ]]; then
        echo -e "\e[32mAll user migrations completed.\e[0m"
    fi
}

# Mark all existing migrations as complete (for fresh setup)
mark_all_done() {
    mkdir -p "$STATE_DIR"

    for file in "$MIGRATIONS_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        local filename=$(basename "$file")
        touch "$STATE_DIR/$filename"
    done
}

# Main
case "${1:-}" in
    status)
        show_status true
        ;;
    run)
        run_migrations
        ;;
    mark-done)
        mark_all_done
        ;;
    *)
        echo "Usage: $0 {status|run|mark-done}"
        exit 1
        ;;
esac
