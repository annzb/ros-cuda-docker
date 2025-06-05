ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS base-image


ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV BUILD_VARIABLES="/tmp/build-variables"
ARG VERBOSE=false
ARG CUDA_VERSION=""
ARG ROS_DISTRO=""


# Set build variables
RUN set -eu; \
    # Log verbosity
    if [ "$VERBOSE" = "true" ]; then \
        APT_FLAGS=""; \
        OUTPUT_REDIRECT=""; \
        echo "Using verbose mode."; \
    else \
        APT_FLAGS="-qq"; \
        OUTPUT_REDIRECT="> /dev/null"; \
        echo "Using quiet mode."; \
    fi; \
    echo "APT_FLAGS=$APT_FLAGS" > $BUILD_VARIABLES; \
    echo "OUTPUT_REDIRECT=$OUTPUT_REDIRECT" >> $BUILD_VARIABLES; \

    # System architecture
    ARCH=$(dpkg --print-architecture | tr '[:upper:]' '[:lower:]'); \
    echo "Detected architecture: $ARCH."; \
    echo "ARCH=$ARCH" >> $BUILD_VARIABLES; \

    # Set package sources
    if [ "$ARCH" = "arm64" ]; then \
        UBUNTU_MIRROR="http://ports.ubuntu.com/ubuntu-ports"; \
        SECURITY_MIRROR="http://ports.ubuntu.com/ubuntu-ports"; \
    else \
        UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"; \
        SECURITY_MIRROR="http://security.ubuntu.com/ubuntu"; \
    fi; \
    UBUNTU_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 || echo "noble"); \
    echo "Using Ubuntu codename: $UBUNTU_CODENAME, Mirror: $UBUNTU_MIRROR, Security Mirror: $SECURITY_MIRROR"; \
    echo "UBUNTU_MIRROR=$UBUNTU_MIRROR" >> $BUILD_VARIABLES; \
    echo "SECURITY_MIRROR=$SECURITY_MIRROR" >> $BUILD_VARIABLES; \
    echo "UBUNTU_CODENAME=$UBUNTU_CODENAME" >> $BUILD_VARIABLES; \

    # Package versions
    CUDA_VERSION_X_Y=$(echo "$CUDA_VERSION" | awk -F. '{print $1"-"$2}'); \
    echo "ROS_DISTRO=$ROS_DISTRO" >> $BUILD_VARIABLES; \
    echo "CUDA_VERSION=$CUDA_VERSION" >> $BUILD_VARIABLES; \
    echo "CUDA_VERSION_X_Y=$CUDA_VERSION_X_Y" >> $BUILD_VARIABLES


# Validate base image
RUN set -eu; \
    OS_NAME=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'); \
    if [ "$OS_NAME" != "ubuntu" ]; then \
        echo "Error: expected an Ubuntu base image, found: $OS_NAME"; \
        exit 1; \
    fi


# Install Ubuntu libraries
RUN set -eu; \
    . $BUILD_VARIABLES; \

    # Add sources
    add_source() { \
        if ! grep -q "$1" /etc/apt/sources.list; then \
            echo "$1" >> /etc/apt/sources.list; \
        fi; \
    }; \
    sed -i '/deb.*main restricted universe multiverse/d' /etc/apt/sources.list; \
    add_source "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME} main restricted universe multiverse"; \
    add_source "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME}-updates main restricted universe multiverse"; \
    add_source "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME}-backports main restricted universe multiverse"; \
    add_source "deb $SECURITY_MIRROR ${UBUNTU_CODENAME}-security main restricted universe multiverse"; \

    # Install packages
    echo "Verbose settings $APT_FLAGS $OUTPUT_REDIRECT"; \
    eval "apt update $APT_FLAGS $OUTPUT_REDIRECT"; \
    eval "apt upgrade -y $APT_FLAGS $OUTPUT_REDIRECT"; \
    eval "apt install --no-install-recommends -y $APT_FLAGS apt-utils $OUTPUT_REDIRECT"; \
    eval "apt install --no-install-recommends -y $APT_FLAGS \
        wget \
        lsb-release \
        gnupg \
        software-properties-common \
        build-essential \
        cmake $OUTPUT_REDIRECT"

        
# Install CUDA
RUN if [ -n "$CUDA_VERSION" ]; then \
        set -eu; \
        . $BUILD_VARIABLES; \
        if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "arm64" ]; then \
            echo "Installing CUDA $CUDA_VERSION_X_Y on architecture $ARCH"; \
            wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/${UBUNTU_CODENAME}/${ARCH}/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb; \
            dpkg -i /tmp/cuda-keyring.deb; \
            rm /tmp/cuda-keyring.deb; \
            eval "apt update $APT_FLAGS $OUTPUT_REDIRECT"; \
            eval "apt install --no-install-recommends -y $APT_FLAGS \
                cuda-toolkit-${CUDA_VERSION_X_Y} \
                nvidia-utils-${CUDA_VERSION_X_Y} \
                nvidia-driver-${CUDA_VERSION_X_Y} $OUTPUT_REDIRECT"; \
            nvcc --version; \
            nvidia-smi; \
        else \
            echo "CUDA not supported on architecture $ARCH"; \
        fi; \
fi


# ROS
RUN if [ -n "$ROS_DISTRO" ]; then \
    set -eu; \
    . $BUILD_VARIABLES; \
    
    # Set up ROS repository
    wget -qO - https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | apt-key add -; \
    UBUNTU_CODENAME=$(lsb_release -sc); \
    if [ "$ROS_DISTRO" = "noetic" ]; then \
        echo "deb http://packages.ros.org/ros/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ros-latest.list; \
    else \
        echo "deb http://packages.ros.org/ros2/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ros2-latest.list; \
    fi; \

    # Install ROS
    eval "apt update $APT_FLAGS $OUTPUT_REDIRECT"; \
    eval "apt install --no-install-recommends -y $APT_FLAGS \
        ros-${ROS_DISTRO}-desktop-full \
        python3-rosdep \
        python3-colcon-common-extensions $OUTPUT_REDIRECT"; \
    rosdep init; rosdep update; \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc; \
else \
    echo "Skipping ROS installation"; \
fi


CMD ["bash"]
