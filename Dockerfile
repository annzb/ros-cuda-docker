ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8


# OS
RUN set -eux; \
    UBUNTU_CODENAME=$(grep -oP '(?<=UBUNTU_CODENAME=)\w+' /etc/os-release); \
    echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME} main restricted universe multiverse" > /etc/apt/sources.list; \
    echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-updates main restricted universe multiverse" >> /etc/apt/sources.list; \
    echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-backports main restricted universe multiverse" >> /etc/apt/sources.list; \
    echo "deb http://security.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-security main restricted universe multiverse" >> /etc/apt/sources.list; \
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y \
        apt-utils \
        wget \
        lsb-release \
        gnupg \
        software-properties-common \
        build-essential \
        cmake


# Python
RUN apt update && apt install -y python3-pip python3-setuptools python3-wheel
RUN python3 -m pip install --no-cache-dir --upgrade pip pip-tools pipdeptree
RUN python3 -m pip freeze > /tmp/requirements.txt && \
    pip-compile --output-file=/tmp/requirements-updated.txt /tmp/requirements.txt && \
    python3 -m pip install --no-cache-dir --upgrade -r /tmp/requirements-updated.txt



# CUDA
ARG CUDA_VERSION=""
RUN if [ -n "$CUDA_VERSION" ]; then \
    set -eux; \
    CUDA_VERSION_X_Y=$(echo "$CUDA_VERSION" | awk -F. '{print $1"-"$2}'); \
    apt update && apt install --no-install-recommends -y cuda-toolkit-${CUDA_VERSION_X_Y} && \
    nvcc --version; \
fi


# ROS
ARG ROS_DISTRO=""
RUN if [ -n "$ROS_DISTRO" ]; then \
    wget -qO - https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | apt-key add - && \
    if [ "$ROS_DISTRO" = "noetic" ]; then \
        echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list; \
    else \
        echo "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros2-latest.list; \
    fi && \
    apt update && apt install --no-install-recommends -y \
        ros-${ROS_DISTRO}-desktop-full \
        python3-rosdep \
        python3-colcon-common-extensions && \
    rosdep init && rosdep update && \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc; \
fi




CMD ["bash"]
