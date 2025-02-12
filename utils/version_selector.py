import argparse
import os
import re
import requests
import yaml
from typing import Optional, Dict


NVIDIA_DOCKERHUB_URL = "https://hub.docker.com/v2/repositories/nvidia/cuda/tags"
IGNORE_OS_TAGS = {'runtime', 'cudnn'}


class ImageNotFoundError(Exception):
    pass


class VersionSelector:
    def __init__(self, version_config_file: str = 'ros-versions.yaml') -> None:
        """
        Initializes the ImageSelector with a given ROS version configuration file.
        """
        self.version_config = self._load_ros_config(version_config_file)
        self.available_ros_distros = ", ".join(str(v) for v in self.version_config.keys())

    def validate_cuda_version(self, cuda_version: Optional[str]) -> Optional[str]:
        """
        Validate that the input CUDA version is in the correct X.Y format.
        """
        if not cuda_version:
            return None
        if not re.match(r"^\d+\.\d+$", cuda_version):
            raise ValueError("Error: CUDA version must be in the format 'X.Y' where X and Y are numeric.")
        return cuda_version

    def validate_ros_version(self, ros_version: Optional[str]) -> Optional[str]:
        """
        Validate that the input ROS version is available.
        """
        ros_version = ros_version or None
        if ros_version not in self.version_config:
            raise ValueError(f"Error: ROS version must be one of the following: {self.available_ros_distros}, not {ros_version}")
        return ros_version

    def _load_ros_config(self, version_config_file: str) -> Dict[Optional[str], Dict]:
        """
        Load ROS configuration from a YAML file.
        """
        if not os.path.isfile(version_config_file):
            raise FileNotFoundError(f"Configuration file not found: {version_config_file}")
        with open(version_config_file, 'r') as file:
            data = yaml.safe_load(file)
            return {None if k == 'default' else k: v for k, v in data.get('ros_versions', {}).items()}

    def determine_base_image(self, cuda_version: Optional[str], ros_version: Optional[str]) -> str:
        """
        Determine the base image based on CUDA and ROS versions.
        """
        cuda_version = self.validate_cuda_version(cuda_version)
        ros_version = self.validate_ros_version(ros_version)
        ubuntu_version = self.version_config[ros_version]['ubuntu']
        if cuda_version is None:
            return f'ubuntu:{ubuntu_version}'
        else:
            image_postfix = f'-ubuntu{ubuntu_version}'
            image_tag = self._get_latest_cuda_tag(cuda_version, image_postfix)
            return f'nvidia/cuda:{image_tag}'

    def _get_latest_cuda_tag(self, cuda_version: str, base_image_postfix: str) -> str:
        """
        Query Docker Hub to find the latest patch version for a given CUDA X.Y version.
        """
        params = {"page_size": 100}
        latest_patch = None
        latest_patch_version = -1
        base_url = NVIDIA_DOCKERHUB_URL

        try:
            while base_url:
                response = requests.get(base_url, params=params)
                response.raise_for_status()
                data = response.json()
                for result in data.get("results", []):
                    tag = result.get("name", "")
                    if tag.startswith(cuda_version) and base_image_postfix in tag and not any(t in tag for t in IGNORE_OS_TAGS):
                        match = re.match(rf"{cuda_version}\.(\d+)", tag)
                        if match:
                            patch_version = int(match.group(1))
                            if patch_version > latest_patch_version:
                                latest_patch = tag
                                latest_patch_version = patch_version
                base_url = data.get("next")
        except requests.RequestException as e:
            raise ValueError(f"Error fetching CUDA tags: {e}")

        if latest_patch:
            return latest_patch
        else:
            raise ImageNotFoundError(f"No matching CUDA image found for version {cuda_version}")


def main():
    parser = argparse.ArgumentParser(description="Determine the base Docker image for CUDA and ROS.")
    parser.add_argument("--cuda", required=False, help="CUDA version in X.Y format (e.g., 12.6).")
    parser.add_argument("--ros", required=False, help="ROS version (e.g., noetic).")
    parser.add_argument("--config", default="ros-versions.yaml", help="Path to the ROS version configuration file.")
    args = parser.parse_args()

    selector = VersionSelector(version_config_file=args.config)
    image = selector.determine_base_image(args.cuda, args.ros)
    print(image)


if __name__ == "__main__":
    main()
