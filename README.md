# ROS + CUDA Docker Images

This repository provides pre-configured Dockerfiles and scripts to build Docker images combining **ROS** (Robot Operating System) and **NVIDIA CUDA** for GPU acceleration based on **Ubuntu** images.
You can use pre-built images from DockerHub or build your own combinations.

---

## Pre-built Images on DockerHub

Some images are available pre-built on **[DockerHub](https://hub.docker.com/u/annzb)**:

```bash
docker pull annazabnus/ros-cuda:{<X.Y>}{-<ros_distro>}
```

**Example:**
```bash
docker pull annazabnus/ros-cuda:12.6-jazzy
```

## Published Versions

Below is a complete list of pre-built **ROS** and **CUDA** versions. **Only the listed ROS distributions are supported at the moment.**

- `noetic`: 11.4, 11.8, 12.0, 12.2, 12.4, 12.6, 12.8
- `humble`: 11.8, 12.0, 12.2, 12.4, 12.6, 12.8
- `jazzy`: 12.6, 12.8

## System Requirements for Using Images

- **Docker**: Version 20.10+
- **NVIDIA GPU Drivers**: Compatible with the chosen CUDA version
- **NVIDIA Container Toolkit**: For GPU support in Docker


---

## Building Your Own Images

Run the provided script to build an image for your desired **ROS** and **CUDA** versions:

```bash
./build_image.sh <ros_distro> <cuda_version>
```

- **`<ros_distro>`**: ROS distribution (e.g., `noetic`, `humble`, `jazzy`). Leave empty or use `none` for no ROS.
- **`<cuda_version>`**: CUDA version in `X.Y` format (e.g., `12.4`). Use `none` to skip CUDA.

**Examples:**

- Build ROS Noetic with CUDA 12.4:
  ```bash
  ./build_image.sh noetic 12.4
  ```

- Build ROS Jazzy without CUDA:
  ```bash
  ./build_image.sh jazzy none
  ```
  
- Build ROS Humble while **detecting the local CUDA version**:
  ```bash
  ./build_image.sh humble
  ```

## System Requirements for Building Images

- **OS**: Linux (Ubuntu 20.04+ recommended)
- **Docker**: Version 20.10+
- **Python 3**: For helper scripts
- **yq**: YAML processor for bash scripts

---

## Installed Libraries and Tools

Each image includes the following major libraries and tools:

- **ROS:** `ros-<distro>-desktop-full`
- **CUDA Toolkit:** Installed via `cuda-toolkit-<version>`
- **Additional Tools:**
  - `python3-rosdep`
  - `python3-colcon-common-extensions` (for ROS 2)
  - `python3-catkin-tools` (for ROS 1)
  - `build-essential`, `cmake`, and other development utilities

---

## Auto-selection of Base Images

For CUDA builds, base images are **dynamically pulled** from the official **[NVIDIA DockerHub](https://hub.docker.com/r/nvidia/cuda)** repository. The selection process:

- Targets `base` and `devel` images, while ignoring `runtime` images.
- Automatically selects the **latest** compatible tag based on the requested CUDA version and Ubuntu release.

---

## Contributing

Feel free to submit issues or pull requests for new features, supported versions, or bug fixes.

---

## License

This project is licensed under the [Apache 2.0 License](LICENSE).
