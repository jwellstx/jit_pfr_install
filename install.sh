#!/bin/bash

# Default values
USER=""
TOKEN=""
REPO=""
DEST_DIR="/app"
BRANCH="main"

# Function to display usage
usage() {
    echo "Usage: $0 --user USERNAME --token TOKEN --repo REPO [--dest-dir DIR] [--branch BRANCH]"
    echo "  --user       GitHub username"
    echo "  --token      GitHub personal access token"
    echo "  --repo       Repository name"
    echo "  --dest-dir   Destination directory (default: /app)"
    echo "  --branch     Branch to clone (default: main)"
    exit 1
}

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --user)
            USER="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --dest-dir)
            DEST_DIR="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check for required arguments
if [[ -z "$USER" || -z "$TOKEN" || -z "$REPO" ]]; then
    echo "Error: --user, --token, and --repo are required."
    usage
fi

# Function to check if the default 'python' command points to Python 3
check_python_version() {
    PYTHON_VERSION=$(python --version 2>&1)
    if [[ $PYTHON_VERSION == Python\ 3* ]]; then
        echo "[ -I- ] Python 3 is detected: $PYTHON_VERSION"
    else
        echo "[ -E- ] Python 3 is required but '$PYTHON_VERSION' is detected. Please make sure Python 3 is set as the default."
        exit 1
    fi
}
check_python_version

# Update the system's package list and check if python3-venv is installed.
echo "[ -I- ] Running updates..."
sudo apt-get -y update
echo "[ -I- ] Running upgrades..."
sudo apt-get -y upgrade
echo "[ -I- ] Running autoremove..."
sudo apt-get -y autoremove
echo "[ -I- ] Checking if python3-venv is installed.."
sudo apt-get install -y python3-venv

# Create destination dir if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
	echo "[ -I- ] Creating $DEST_DIR."
	sudo mkdir -p "$DEST_DIR"
	sudo chmod 777 "$DEST_DIR"
else
	echo "[ -I- ] $DEST_DIR already exists."
fi
cd "$DEST_DIR" || exit 1

# Create virtual environment if it doesn't exist
if [ ! -d "$DEST_DIR/venv" ]; then
	echo "[ -I- ] Creating a virtual environment..."
	python -m venv --system-site-packages venv
fi

# Setup virtual environment
echo "[ -I- ] Activating the virtual environment..."
source venv/bin/activate

# Clone or pull updates from repo
REPO_DIR="$DEST_DIR/$REPO"
if [ -d "$REPO_DIR/.git" ]; then
	# Repo exists, pull
	echo "[ -I- ] Pulling latest changes from $REPO repo..."
	pushd "$REPO_DIR/" && git pull origin "$BRANCH" && popd
else
	# Construct the authenticated GitHub URL
	REPO_URL="https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git"

	# Print the arguments (for debugging or confirmation)
	echo "Cloning repository from $REPO_URL"
	echo "Destination directory: $DEST_DIR"
	echo "Branch: $BRANCH"

	# Clone the repository
	git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

PACKAGE_DIR="$REPO_DIR/dependencies/packages/"
if ls "$PACKAGE_DIR"/*.deb 1> /dev/null 2>&1; then
	echo "[ -I- ] Installing system level apt library requirements..."
	# xargs -a apt_requirements.txt sudo apt-get install -y
	# Install apt libraries from dependencies/package folder, so its the same flow as update
	sudo dpkg -i "$PACKAGE_DIR"/*.deb
else
	echo "[ -I- ] No .deb files found in $PACKAGE_DIR to install."
fi

if ls "$PACKAGE_DIR"/*.whl 1> /dev/null 2>&1; then
	echo "[ -I- ] Installing venv level pip library requirements..."
	pip install --upgrade pip
	pip install "$PACKAGE_DIR"/*.whl
else
	echo "[ -I- ] No .whl files found in $PACKAGE_DIR to install."
fi

echo ""
echo "Setup complete!"
echo ""
