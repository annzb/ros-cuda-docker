ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8


# Base image check
RUN set -eux; \
    OS_NAME=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'); \
    if [ "$OS_NAME" != "ubuntu" ]; then \
        echo "Error: expected an Ubuntu base image, found: $OS_NAME"; \
        exit 1; \
    fi


# Install ubuntu libraries
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    if [ "$ARCH" = "arm64" ]; then \
        UBUNTU_MIRROR="http://ports.ubuntu.com/ubuntu-ports"; \
        SECURITY_MIRROR="http://ports.ubuntu.com/ubuntu-ports"; \
    else \
        UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"; \
        SECURITY_MIRROR="http://security.ubuntu.com/ubuntu"; \
    fi; \
    UBUNTU_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 || echo "noble"); \
    echo "Using Ubuntu codename: $UBUNTU_CODENAME, Mirror: $UBUNTU_MIRROR, Security Mirror: $SECURITY_MIRROR"; \
    echo "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME} main restricted universe multiverse" > /etc/apt/sources.list; \
    echo "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME}-updates main restricted universe multiverse" >> /etc/apt/sources.list; \
    echo "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME}-backports main restricted universe multiverse" >> /etc/apt/sources.list; \
    echo "deb $SECURITY_MIRROR ${UBUNTU_CODENAME}-security main restricted universe multiverse" >> /etc/apt/sources.list; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y \
        apt-utils \
        wget \
        lsb-release \
        gnupg \
        software-properties-common \
        build-essential \
        cmake


# Install CUDA
ARG CUDA_VERSION=""
RUN ARCH=$(dpkg --print-architecture); \
    if [ -n "$CUDA_VERSION" ] && [ "$ARCH" = "amd64" ]; then \
        set -eux; \
        CUDA_VERSION_X_Y=$(echo "$CUDA_VERSION" | awk -F. '{print $1"-"$2}'); \
        apt update && apt install --no-install-recommends -y cuda-toolkit-${CUDA_VERSION_X_Y} && \
        nvcc --version; \
    else \
        echo "Skipping CUDA installation on ARM64"; \
    fi

# Install ROS
ARG ROS_DISTRO=""
RUN if [ -n "$ROS_DISTRO" ]; then \
    set -eux; \
    wget -qO - https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | apt-key add -; \
    UBUNTU_CODENAME=$(lsb_release -sc); \
    if [ "$ROS_DISTRO" = "noetic" ]; then \
        echo "deb http://packages.ros.org/ros/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ros-latest.list; \
    else \
        echo "deb http://packages.ros.org/ros2/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ros2-latest.list; \
    fi; \
    apt update && apt install --no-install-recommends -y \
        ros-${ROS_DISTRO}-desktop-full \
        python3-rosdep \
        python3-colcon-common-extensions; \
    rosdep init && rosdep update; \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc; \
else \
    echo "Skipping ROS installation"; \
fi


CMD ["bash"]
