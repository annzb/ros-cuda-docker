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
    echo "No ROS distribution selected."
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


if [ -z "$DOCKER_CUDA_VERSION" ] && [ -z "$ROS_DISTRO" ]; then
    echo "Error: Neither ROS distribution nor CUDA version specified. Skipping build."
    exit 0
fi


# Set base image
set +e
BASE_IMAGE=$(python3 "$PYTHON_SCRIPT" --cuda "$DOCKER_CUDA_VERSION" --ros "$ROS_DISTRO")
EXIT_CODE=$?
set -e
if [ $EXIT_CODE -ne 0 ] || [ -z "$BASE_IMAGE" ]; then
    echo "No valid base image found for ROS $ROS_DISTRO and CUDA $DOCKER_CUDA_VERSION. Aborting."
    exit 0
fi
echo "Using base image: $BASE_IMAGE"


# Construct image name
OS_IMAGE_NAME="annazabnus/ros-cuda"
if [ -n "$DOCKER_CUDA_VERSION" ] && [ -n "$ROS_DISTRO" ]; then
    OS_IMAGE_NAME+=":$DOCKER_CUDA_VERSION-$ROS_DISTRO"
elif [ -n "$DOCKER_CUDA_VERSION" ]; then
    OS_IMAGE_NAME+=":$DOCKER_CUDA_VERSION"
elif [ -n "$ROS_DISTRO" ]; then
    OS_IMAGE_NAME+=":$ROS_DISTRO"
fi
echo "Building image: $OS_IMAGE_NAME"


# Build image
docker build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg ROS_DISTRO="$ROS_DISTRO" \
    -t "$OS_IMAGE_NAME" .

echo "$OS_IMAGE_NAME"
