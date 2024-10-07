#!/usr/bin/env sh

PROJECT_GIT_REPO_URL="https://github.com/fuchs-fabian/satissavebak.git"
PROJECT_NAME=$(basename $PROJECT_GIT_REPO_URL .git)

# The host of the git repository for the backup
GIT_HOST_FOR_BACKUP_REPO="github.com"

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░               PREPARATIONS               ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║               CHECK COMMANDS               ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

check_command() {
    cmd="$1"

    echo "Checking if the '$cmd' command is available..."
    command -v "$cmd" >/dev/null 2>&1 ||
        {
            echo "The '$cmd' command is not available. Please install it and try again."
            exit 1
        }
    echo "The '$cmd' command is available."
}

check_command "git"
check_command "docker"
check_command "ssh-keygen"
check_command "ssh-keyscan"

echo "Checking if 'docker compose' is available..."
docker compose version >/dev/null 2>&1 ||
    {
        echo "The 'docker compose' command is not available."
        exit 1
    }
echo "The 'docker compose' command is available."

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║         CHECK FOR PROJECT ARTIFACTS        ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

if [ -d "$PROJECT_NAME" ]; then
    echo
    echo "The directory '$PROJECT_NAME' already exists. Remove it? (y/n)"
    read -r REMOVE_DIR
    if [ "$REMOVE_DIR" = "y" ]; then
        rm -rf "$PROJECT_NAME" ||
            {
                echo "Failed to remove the directory '$PROJECT_NAME'."
                exit 1
            }
        echo
    else
        echo "The install script cannot continue. You have to set up manually."
        echo "Aborting..."
        exit 1
    fi
fi

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║             CLONE REPOSITORY               ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

echo "Cloning the repository '$PROJECT_GIT_REPO_URL'..."
git clone $PROJECT_GIT_REPO_URL ||
    {
        echo "Failed to clone the repository '$PROJECT_GIT_REPO_URL'."
        exit 1
    }
echo "The repository '$PROJECT_GIT_REPO_URL' has been cloned."

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║             MOVE TO PROJECT DIR            ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

cd "$PROJECT_NAME" ||
    {
        echo "The directory '$PROJECT_NAME' does not exist. Something went wrong."
        exit 1
    }

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░               INSTALLATION               ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

echo "Installing '$PROJECT_NAME'..."

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║          CREATE THE '.env' FILE            ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

echo "Setting up the '.env' file..."

LOG_LEVEL=6
CRON_JOB_MINUTES=10
CRON_SCHEDULE="*/$CRON_JOB_MINUTES * * * *"

echo

echo "Enter the git repo url for the 'simbashlog' notifier (leave empty if not needed):"
read -r GIT_REPO_URL_FOR_SIMBASHLOG_NOTIFIER ||
    {
        echo "Failed to read the git repo url for the 'simbashlog' notifier."
        exit 1
    }
export GIT_REPO_URL_FOR_SIMBASHLOG_NOTIFIER

echo

echo "Enter the absolute path to Satisfactory save games you want to backup:"
read -r SATISFACTORY_SAVE_GAMES_PATH || {
    echo "Failed to read the save game path."
    exit 1
}
export SATISFACTORY_SAVE_GAMES_PATH

echo

echo "Enter the absolute path to Satisfactory blueprints you want to backup:"
read -r SATISFACTORY_BLUEPRINTS_PATH || {
    echo "Failed to read the blueprints path."
    exit 1
}
export SATISFACTORY_BLUEPRINTS_PATH

echo

echo "Enter the ssh git url (from '$GIT_HOST_FOR_BACKUP_REPO') that comes up when you want to clone your 'backup' repository with ssh (Starts with 'git@' and ends with '.git'):"
read -r GIT_REPO_URL_FOR_SATISFACTORY_BACKUP || {
    echo "Failed to read the ssh git url."
    exit 1
}
export GIT_REPO_URL_FOR_SATISFACTORY_BACKUP

echo

echo "Creating the '.env' file..."
cat <<EOF >.env
LOG_LEVEL=$LOG_LEVEL
CRON_SCHEDULE=$CRON_SCHEDULE
GIT_REPO_URL_FOR_SIMBASHLOG_NOTIFIER='$GIT_REPO_URL_FOR_SIMBASHLOG_NOTIFIER'
SATISFACTORY_SAVE_GAMES_PATH=$SATISFACTORY_SAVE_GAMES_PATH
SATISFACTORY_BLUEPRINTS_PATH=$SATISFACTORY_BLUEPRINTS_PATH
GIT_REPO_URL_FOR_SATISFACTORY_BACKUP='$GIT_REPO_URL_FOR_SATISFACTORY_BACKUP'
EOF

cat .env ||
    {
        echo "Failed to create the '.env' file."
        exit 1
    }
echo "The '.env' file has been created."

echo

echo "The log level is set to '$LOG_LEVEL'."
echo "  (0 = emergency, 1 = alert, 2 = critical, 3 = error, 4 = warning, 5 = notice, 6 = info, 7 = debug)"

echo "The cron job will run every $CRON_JOB_MINUTES minutes."

if [ -n "$GIT_REPO_URL_FOR_SIMBASHLOG_NOTIFIER" ]; then
    echo "The git repo url for the 'simbashlog' notifier is set to '$GIT_REPO_URL_FOR_SIMBASHLOG_NOTIFIER'."
else
    echo "The git repo url for the 'simbashlog' notifier is not set."
fi

echo "The absolute path to the Satisfactory save games is set to '$SATISFACTORY_SAVE_GAMES_PATH'."
echo "The absolute path to the Satisfactory blueprints is set to '$SATISFACTORY_BLUEPRINTS_PATH'."
echo "The git repo url for the 'backup' repository is set to '$GIT_REPO_URL_FOR_SATISFACTORY_BACKUP'."

echo

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║     CREATE NECESSARY FILES FOR VOLUMES     ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

echo "Creating the necessary files for the volumes..."

SSH_DIR="./volumes/ssh"

echo "Creating the ssh directory..."
mkdir -p "$SSH_DIR" ||
    {
        echo "Failed to create the directory '$SSH_DIR'."
        exit 1
    }
echo "The directory '$SSH_DIR' has been created."

echo "Generating the ssh key without a passphrase..."
ssh-keygen -t ed25519 -C "$PROJECT_NAME" -f "$SSH_DIR/${PROJECT_NAME}_key" -N "" ||
    {
        echo "Failed to generate the ssh key."
        exit 1
    }
echo "The ssh key has been generated."

echo "Creating the ssh config file..."
cat <<EOF >$SSH_DIR/config
Host $GIT_HOST_FOR_BACKUP_REPO
    IdentityFile /root/.ssh/${PROJECT_NAME}_key
EOF

cat $SSH_DIR/config ||
    {
        echo "Failed to create the ssh config file."
        exit 1
    }
echo "The ssh config file has been created."

echo "Creating the 'known_hosts' file..."
touch $SSH_DIR/known_hosts ||
    {
        echo "Failed to create the 'known_hosts' file."
        exit 1
    }
echo "The 'known_hosts' file has been created."

echo "Adding the $GIT_HOST_FOR_BACKUP_REPO key to the 'known_hosts' file..."
ssh-keyscan $GIT_HOST_FOR_BACKUP_REPO >>$SSH_DIR/known_hosts ||
    {
        echo "Failed to add the $GIT_HOST_FOR_BACKUP_REPO key to the 'known_hosts' file."
        exit 1
    }

cat $SSH_DIR/known_hosts ||
    {
        echo "Failed to add the $GIT_HOST_FOR_BACKUP_REPO key to the 'known_hosts' file."
        exit 1
    }
echo "The $GIT_HOST_FOR_BACKUP_REPO key has been added to the 'known_hosts' file."

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                  CLEANUP                   ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

# ┌─────────────────────┬──────────────────────┐
# │               GIT ARTIFACTS                │
# └─────────────────────┴──────────────────────┘

echo "Removing unnecessary git artifacts..."

rm -rf .git ||
    {
        echo "Failed to remove the '.git' directory from the project directory."
        exit 1
    }
echo "The '.git' directory has been removed from the project directory."

rm install.sh ||
    {
        echo "Failed to remove the install script from the project directory."
        exit 1
    }
echo "The install script has been removed from the project directory."

# ┌─────────────────────┬──────────────────────┐
# │               INSTALL SCRIPT               │
# └─────────────────────┴──────────────────────┘

echo "Removing the current install script..."

rm ../install.sh ||
    {
        echo "Failed to remove the current install script."
        exit 1
    }
echo "The current install script has been removed."

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║             FINAL EXECUTIONS               ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

echo
echo "Add the public key to your 'backup' repository's ('$GIT_REPO_URL_FOR_SATISFACTORY_BACKUP') deploy keys!"
echo "In GitHub, go to your repository -> Settings -> Deploy keys -> Add deploy key -> Paste the public key from the file '$SSH_DIR/${PROJECT_NAME}_key.pub' -> Allow write access -> Add key"
echo "Add as title '$PROJECT_NAME'"
echo "The deploy key is:"
cat "$SSH_DIR/${PROJECT_NAME}_key.pub" ||
    {
        echo "Failed to show the public key."
        exit 1
    }

check_public_key_added() {
    echo "Is the public key added to your 'backup' repository's ('$GIT_REPO_URL_FOR_SATISFACTORY_BACKUP') deploy keys? (y/n)"
    read -r IS_PUBLIC_KEY_ADDED || {
        echo "Failed to read if the public key is added."
        exit 1
    }

    if [ "$IS_PUBLIC_KEY_ADDED" = "y" ]; then
        echo "Public key is added. Continuing..."
    elif [ "$IS_PUBLIC_KEY_ADDED" = "n" ]; then
        echo "The public key is not added to your 'backup' repository's deploy keys. Please add it otherwise the backup will not work."
    else
        echo "Invalid input. Please enter 'y' for yes or 'n' for no."
        check_public_key_added
    fi
    return 0
}

check_public_key_added
echo

echo "Running the Docker container for '$PROJECT_NAME'..."
docker compose up -d ||
    {
        echo "Failed to run the Docker container."
        exit 1
    }
echo "The Docker container is running."

echo "The installation for '$PROJECT_NAME' is complete."
echo
echo "INFO: If a 'simbashlog' notifier is set and you have to configure it, you have to shut down the container, adjust the configuration and restart the container."
