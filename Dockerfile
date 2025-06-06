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
        OUTPUT_REDIRECT='" > /dev/null"'; \
        echo "Using quiet mode."; \
    fi; \
    echo "APT_FLAGS=$APT_FLAGS" > $BUILD_VARIABLES; \
    echo "OUTPUT_REDIRECT=$OUTPUT_REDIRECT" >> $BUILD_VARIABLES; \
    \
    # System architecture
    ARCH=$(dpkg --print-architecture | tr '[:upper:]' '[:lower:]'); \
    echo "Detected architecture: $ARCH."; \
    echo "ARCH=$ARCH" >> $BUILD_VARIABLES; \
    \
    # Ubuntu package sources
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
    \
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
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
        mv /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.disabled; \
    fi; \
    sed -i '/deb.*main restricted universe multiverse/d' /etc/apt/sources.list; \
    add_source() { \
        if ! grep -qF "$1" /etc/apt/sources.list; then \
            echo "$1" >> /etc/apt/sources.list; \
        fi; \
    }; \
    # add_source "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME} main restricted universe multiverse"; \
    # add_source "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME}-updates main restricted universe multiverse"; \
    # add_source "deb $UBUNTU_MIRROR ${UBUNTU_CODENAME}-backports main restricted universe multiverse"; \
    # add_source "deb $SECURITY_MIRROR ${UBUNTU_CODENAME}-security main restricted universe multiverse"; \
    sh -c "apt update $APT_FLAGS $OUTPUT_REDIRECT"; \
    sh -c "apt upgrade -y $APT_FLAGS $OUTPUT_REDIRECT"; \
    # sh -c "apt install --no-install-recommends -y $APT_FLAGS apt-utils $OUTPUT_REDIRECT"; \
    sh -c "apt install --no-install-recommends -y $APT_FLAGS \
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
            sh -c "apt update -o Acquire::http::No-Cache=True $APT_FLAGS $OUTPUT_REDIRECT"; \
            sh -c "apt clean $APT_FLAGS $OUTPUT_REDIRECT"; \
            sh -c "apt install --no-install-recommends -y $APT_FLAGS nvidia-settings libxnvctrl0 $OUTPUT_REDIRECT"; \
            sh -c "apt install --no-install-recommends -y $APT_FLAGS cuda-toolkit-${CUDA_VERSION_X_Y} $OUTPUT_REDIRECT"; \
            nvcc --version; \
        else \
            echo "CUDA not supported on architecture $ARCH"; \
        fi; \
fi


# Install ROS
RUN if [ -n "$ROS_DISTRO" ]; then \
    set -eu; \
    . $BUILD_VARIABLES; \
    wget -qO /usr/share/keyrings/ros.gpg https://raw.githubusercontent.com/ros/rosdistro/master/ros.key; \
    case "$ROS_DISTRO" in noetic|melodic|kinetic) \
            echo "deb [signed-by=/usr/share/keyrings/ros.gpg] http://packages.ros.org/ros/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ros-latest.list ;; \
        *) \
            echo "deb [signed-by=/usr/share/keyrings/ros.gpg] http://packages.ros.org/ros2/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ros2-latest.list ;; \
    esac; \
    sh -c "apt update $APT_FLAGS $OUTPUT_REDIRECT"; \
    sh -c "apt -o Acquire::Retries=3 install --no-install-recommends -y $APT_FLAGS \
        ros-${ROS_DISTRO}-desktop-full \
        python3-rosdep \
        python3-colcon-common-extensions $OUTPUT_REDIRECT"; \
    rosdep init; rosdep update; \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc; \
else \
    echo "Skipping ROS installation"; \
fi


CMD ["bash"]
