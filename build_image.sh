#!/bin/bash


set -euo pipefail


# Check dependencies
for cmd in yq python3 docker; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed."
        case $cmd in
            yq) echo "Please run 'apt install yq'";;
            python3) echo "Please install Python 3.";;
            docker) echo "Please install Docker.";;
        esac
        exit 1
    fi
done


# Validate configuration
CONFIG_FILE="ros-versions.yaml"
PYTHON_SCRIPT="utils/find_base_image.py"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: Python script '$PYTHON_SCRIPT' not found."
    exit 1
fi


# Set ROS distribution
AVAILABLE_ROS_DISTROS=$(yq '.ros_versions | keys | map(select(. != "default")) | join(" ")' "$CONFIG_FILE")
ROS_DISTRO="${1:-}"
if [ -z "$ROS_DISTRO" ] || [ "$ROS_DISTRO" = "none" ]; then
    ROS_DISTRO=""
    echo "No ROS distribution selected. Using base Ubuntu image."
elif ! yq -e ".ros_versions | has(\"$ROS_DISTRO\")" "$CONFIG_FILE" > /dev/null; then
    echo "Error: Invalid ROS distribution '$ROS_DISTRO'."
    echo "Available options: $AVAILABLE_ROS_DISTROS"
    exit 1
else
    echo "Using ROS distribution: '$ROS_DISTRO'"
fi


# Set CUDA version
if [ "${2:-}" = "none" ]; then
    DOCKER_CUDA_VERSION=""
elif [ -n "${2:-}" ]; then
    DOCKER_CUDA_VERSION="$2"
else
    DOCKER_CUDA_VERSION=$(nvcc --version | grep -oP "release \K[0-9]+\.[0-9]+" || true)
    DOCKER_CUDA_VERSION=${DOCKER_CUDA_VERSION:-""}
fi
echo "Using CUDA version: ${DOCKER_CUDA_VERSION:-None}"


# Set base image
BASE_IMAGE=$(python3 "$PYTHON_SCRIPT" --cuda "$DOCKER_CUDA_VERSION" --ros "$ROS_DISTRO")
if [ -z "$BASE_IMAGE" ]; then
    echo "Error: Failed to determine base image."
    exit 1
fi
echo "Using base image: $BASE_IMAGE"


# Construct image name
UBUNTU_VERSION=$(echo "$BASE_IMAGE" | grep -oP "ubuntu:?\K[0-9]+\.[0-9]+" || true)
UBUNTU_VERSION=${UBUNTU_VERSION:-""}
OS_IMAGE_NAME="ubuntu:${UBUNTU_VERSION:-latest}"
[ -n "$DOCKER_CUDA_VERSION" ] && OS_IMAGE_NAME+="-cuda$DOCKER_CUDA_VERSION"
[ -n "$ROS_DISTRO" ] && OS_IMAGE_NAME+="-$ROS_DISTRO"
echo "Building OS image: $OS_IMAGE_NAME"


# Build image
docker build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg ROS_DISTRO="$ROS_DISTRO" \
    -t "$OS_IMAGE_NAME" .

echo "$OS_IMAGE_NAME"
