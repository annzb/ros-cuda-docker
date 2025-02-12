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

if ! docker buildx version &> /dev/null; then
    echo "Error: Docker Buildx is not installed. Please install it before proceeding."
    exit 1
fi

# Ensure a Buildx builder exists
if ! docker buildx ls | grep -q '\*'; then
    echo "No active Buildx builder found. Creating ros-cuda-builder."
    docker buildx create --name ros-cuda-builder --use
    docker buildx inspect --bootstrap
fi


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
    exit 1
fi


# Set base image
set +e
BASE_IMAGE=$(python3 "$PYTHON_SCRIPT" --cuda "$DOCKER_CUDA_VERSION" --ros "$ROS_DISTRO")
EXIT_CODE=$?
set -e
if [ $EXIT_CODE -ne 0 ] || [ -z "$BASE_IMAGE" ]; then
    echo "No valid base image found for ROS $ROS_DISTRO and CUDA $DOCKER_CUDA_VERSION. Aborting."
    exit 1
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
CACHE_FROM_DIR="${DOCKER_CACHE_FROM:-/tmp/.buildx-cache}"
CACHE_TO_DIR="${DOCKER_CACHE_TO:-/tmp/.buildx-cache-new}"

DOCKER_BUILDKIT=1 docker buildx build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg ROS_DISTRO="$ROS_DISTRO" \
    --cache-from=type=local,src="$CACHE_FROM_DIR" \
    --cache-to=type=local,dest="$CACHE_TO_DIR",mode=max \
    -t "$OS_IMAGE_NAME" \
    --load \
    .

echo "$OS_IMAGE_NAME"
