#!/usr/bin/env bash

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Invalid number of arguments. Usage: $0 <log_level> <git_repo_path> [<notifier>]"
    exit 1
fi

LOG_LEVEL="$1"
GIT_REPO_PATH="$2"
NOTIFIER="${3:-}"

if [ -z "$LOG_LEVEL" ]; then
    echo "Log level not set"
    exit 1
fi

LOG_DIR="/var/log/satissavebak/"

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░             LOGGING HELPER               ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function log {
    local severity="$1"
    local message="$2"

    local log_level="$LOG_LEVEL"
    local log_dir="$LOG_DIR"
    local notifier="$NOTIFIER"

    local simbashlog_action="log"
    local severity_code

    # Set severity code
    case "$severity" in
    debug | 7)
        severity_code=7
        ;;
    info | 6)
        severity_code=6
        ;;
    notice | 5)
        severity_code=5
        ;;
    warn | 4)
        severity_code=4
        ;;
    error | 3)
        severity_code=3
        ;;
    crit | 2)
        severity_code=2
        ;;
    alert | 1)
        severity_code=1
        ;;
    emerg | 0)
        severity_code=0
        ;;
    *)
        # Default to debug if severity is unknown
        severity_code=7
        echo "Unknown severity: $severity"
        ;;
    esac

    local simbashlog_command=("simbashlog" "--action" "$simbashlog_action" "--severity" "$severity_code" "--message" "$message" "--log-level" "$log_level" "--log-dir" "$log_dir")

    # Add notifier if set
    if [ -n "$notifier" ]; then
        simbashlog_command+=("--notifier" "$notifier")
    fi

    # Execute simbashlog command
    "${simbashlog_command[@]}" ||
        {
            echo "Failed to execute: simbashlog"
            exit 1
        }

    # Exit if severity is error or higher
    if [[ "$severity_code" -lt 3 ]]; then
        exit 1
    fi
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  MAIN                    ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

if [ -z "$GIT_REPO_PATH" ]; then
    log error "Git repository path not set"
fi

log debug "Log Level: $LOG_LEVEL"
log debug "Git Repo Path: $GIT_REPO_PATH"

cd "$GIT_REPO_PATH" || log error "Git directory not found"

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║              CLEAN GIT HISTORY             ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

TEMP_BRANCH="temp"
MAIN_BRANCH="main"
INITIAL_COMMIT_MESSAGE="Initial commit"

STEP_FOR_GIT_HISTORY_CLEANING=0

function log_info_for_git_history_cleaning {
    ((STEP_FOR_GIT_HISTORY_CLEANING++))
    log info "Clean git history - Step $STEP_FOR_GIT_HISTORY_CLEANING: $1"
}

function log_notice_for_git_history_cleaning {
    log notice "Clean git history (Step $STEP_FOR_GIT_HISTORY_CLEANING): $1"
}

function log_error_for_git_history_cleaning {
    log error "Clean git history (Step $STEP_FOR_GIT_HISTORY_CLEANING) failed: $1"
}

log_info_for_git_history_cleaning "Setting upstream branch..."
git branch --set-upstream-to=origin/$MAIN_BRANCH $MAIN_BRANCH ||
    log_error_for_git_history_cleaning "Failed to set upstream branch"

log_info_for_git_history_cleaning "Checking out the '$MAIN_BRANCH' branch..."
git checkout $MAIN_BRANCH ||
    log_error_for_git_history_cleaning "Failed to checkout the '$MAIN_BRANCH' branch"

log_info_for_git_history_cleaning "Pulling changes from the remote repository (rebase)..."
GIT_PULL_OUTPUT=$(git pull --rebase 2>&1)
GIT_PULL_EXIT_CODE=$?

if [[ $GIT_PULL_EXIT_CODE -eq 0 ]]; then
    if [[ "$GIT_PULL_OUTPUT" == *"Already up to date."* ]]; then
        log_notice_for_git_history_cleaning "Already up to date"
    else
        log_notice_for_git_history_cleaning "$GIT_PULL_OUTPUT"
    fi
else
    git rebase --abort ||
        log_error_for_git_history_cleaning "Failed to pull changes from the remote repository (rebase)"
fi

log_info_for_git_history_cleaning "Creating a new orphan branch..."
git checkout --orphan $TEMP_BRANCH ||
    log_error_for_git_history_cleaning "Failed to create a new orphan branch"

log_info_for_git_history_cleaning "Adding all files to the new branch..."
git add -A ||
    log_error_for_git_history_cleaning "Failed to add all files to the new branch"

log_info_for_git_history_cleaning "Committing changes to the orphan branch..."
git commit -m "$INITIAL_COMMIT_MESSAGE" ||
    log_error_for_git_history_cleaning "Failed to commit changes to the orphan branch"

log_info_for_git_history_cleaning "Deleting the old '$MAIN_BRANCH' branch..."
git branch -D $MAIN_BRANCH ||
    log_error_for_git_history_cleaning "Failed to delete the old '$MAIN_BRANCH' branch"

log_info_for_git_history_cleaning "Renaming the temporary branch to '$MAIN_BRANCH'..."
git branch -m $MAIN_BRANCH ||
    log_error_for_git_history_cleaning "Failed to rename the temporary branch to '$MAIN_BRANCH'"

log_info_for_git_history_cleaning "Cleaning up Git history..."
git reflog expire --expire=now --all ||
    log_error_for_git_history_cleaning "Failed to expire reflog"

log_info_for_git_history_cleaning "Git garbage collection..."
git gc --aggressive --prune=now ||
    log_error_for_git_history_cleaning "Failed to run Git garbage collection"

log_info_for_git_history_cleaning "Force updating the remote repository..."
git push --force origin $MAIN_BRANCH ||
    log_error_for_git_history_cleaning "Failed to force update the remote repository"

log_info_for_git_history_cleaning "Setting to upstream branch again..."
git branch --set-upstream-to=origin/$MAIN_BRANCH $MAIN_BRANCH ||
    log_error_for_git_history_cleaning "Failed to set upstream branch"

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║             BACKUP SATISFACTORY            ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

DIR_FOR_SATISFACTORY_SAVES="/mnt/satisfactory/saves"
DIR_FOR_SATISFACTORY_BLUEPRINTS="/mnt/satisfactory/blueprints"

GIT_DIR_FOR_SATISFACTORY_SAVES="$(pwd)/saves"
GIT_DIR_FOR_SATISFACTORY_BLUEPRINTS="$(pwd)/blueprints"

STEP_FOR_BACKUP_SATISFACTORY=0

function log_info_for_backup_satisfactory {
    ((STEP_FOR_BACKUP_SATISFACTORY++))
    log info "Backup Satisfactory - Step $STEP_FOR_BACKUP_SATISFACTORY: $1"
}

function log_error_for_backup_satisfactory {
    log error "Backup Satisfactory (Step $STEP_FOR_BACKUP_SATISFACTORY) failed: $1"
}

log_info_for_backup_satisfactory "Checking if saves directory exists..."
if [ ! -d "$DIR_FOR_SATISFACTORY_SAVES" ]; then
    log_error_for_backup_satisfactory "Saves directory not found"
fi

log_info_for_backup_satisfactory "Checking if blueprints directory exists..."
if [ ! -d "$DIR_FOR_SATISFACTORY_BLUEPRINTS" ]; then
    log_error_for_backup_satisfactory "Blueprints directory not found"
fi

log_info_for_backup_satisfactory "Creating saves directory '$GIT_DIR_FOR_SATISFACTORY_SAVES'..."
mkdir -p "$GIT_DIR_FOR_SATISFACTORY_SAVES" ||
    log_error_for_backup_satisfactory "Failed to create saves directory"

log_info_for_backup_satisfactory "Creating blueprints directory '$GIT_DIR_FOR_SATISFACTORY_BLUEPRINTS'..."
mkdir -p "$GIT_DIR_FOR_SATISFACTORY_BLUEPRINTS" ||
    log_error_for_backup_satisfactory "Failed to create blueprints directory"

log_info_for_backup_satisfactory "Copying saves to git directory '$GIT_DIR_FOR_SATISFACTORY_SAVES'..."
rsync -a $DIR_FOR_SATISFACTORY_SAVES/* "$GIT_DIR_FOR_SATISFACTORY_SAVES" ||
    log_error_for_backup_satisfactory "Failed to copy saves"

log_info_for_backup_satisfactory "Copying blueprints to git directory '$GIT_DIR_FOR_SATISFACTORY_BLUEPRINTS'..."
rsync -a $DIR_FOR_SATISFACTORY_BLUEPRINTS/* "$GIT_DIR_FOR_SATISFACTORY_BLUEPRINTS" ||
    log_error_for_backup_satisfactory "Failed to copy blueprints"

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║              GIT OPERATIONS                ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

COMMIT_MESSAGE="$(date)"

STEP_FOR_GIT_OPERATIONS=0

function log_info_for_git_operations {
    ((STEP_FOR_GIT_OPERATIONS++))
    log info "Git operations - Step $STEP_FOR_GIT_OPERATIONS: $1"
}

function log_notice_for_git_operations {
    log notice "Git operations (Step $STEP_FOR_GIT_OPERATIONS): $1"
}

function log_error_for_git_operations {
    log error "Git operations (Step $STEP_FOR_GIT_OPERATIONS) failed: $1"
}

log_info_for_git_operations "Adding changes to git repository..."
git add . ||
    log_error_for_git_operations "add"

log_info_for_git_operations "Committing changes to git repository..."
GIT_COMMIT_OUTPUT=$(git commit -m "$COMMIT_MESSAGE" 2>&1)
GIT_COMMIT_EXIT_CODE=$?

if [[ $GIT_COMMIT_EXIT_CODE -ne 0 ]]; then
    if [[ "$GIT_COMMIT_OUTPUT" == *"nothing to commit"* ]]; then
        log_notice_for_git_operations "Nothing to commit"
    else
        log_error_for_git_operations "Failed to commit: $GIT_COMMIT_OUTPUT"
    fi
else
    log_info_for_git_operations "Pushing changes to git repository..."
    git push ||
        log_error_for_git_operations "push"
fi

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║             FINAL EXECUTIONS               ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

log notice "Backup successfull"
