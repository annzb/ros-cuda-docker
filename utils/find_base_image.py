import argparse
import re
import requests
import sys
import yaml


ROS_VERSIONS_FILE = 'ros-versions.yaml'


class ImageSelector:
    def __init__(self, cuda_version, ros_version):
        self.cuda_version = self.validate_cuda_version(cuda_version)
        self.ros_version = ros_version or None
        self.ros_config = self.load_ros_config()

    @staticmethod
    def validate_cuda_version(cuda_version):
        """
        Validate that the input version is in the correct X.Y format with numeric values.
        """
        if cuda_version is None:
            return None

        if not re.match(r"^\d+\.\d+$", cuda_version):
            raise ValueError("Error: CUDA version must be in the format 'X.Y' where X and Y are numeric.")

        return cuda_version

    @staticmethod
    def load_ros_config():
        """
        Load ROS configuration from the YAML file.
        """
        # try:
        with open(ROS_VERSIONS_FILE, 'r') as file:
            data = yaml.safe_load(file)
            return {None if k == 'default' else k: v for k, v in data.get('ros_versions', {}).items()}
        # except FileNotFoundError:
        #     sys.exit(f"Error: Configuration file {ROS_VERSIONS_FILE} not found.", status=1)
        # except yaml.YAMLError as e:
        #     sys.exit(f"Error parsing YAML file: {e}")

    def determine_base_image(self):
        """
        Determine the base image based on CUDA and ROS versions, considering only 'base' and 'devel' images, ignoring 'runtime'.
        """
        if self.ros_version not in self.ros_config:
            available_versions = ", ".join(str(v) for v in self.ros_config.keys())
            raise ValueError(f"Error: ROS version must be one of the following: {available_versions}, not {self.ros_version}")

        ubuntu_version = self.ros_config[self.ros_version]['ubuntu']

        if self.cuda_version is None:
            return f'ubuntu:{ubuntu_version}'
        else:
            image_postfix = f'-ubuntu{ubuntu_version}'
            image_tag = self.get_latest_cuda_tag(image_postfix)
            return f'nvidia/cuda:{image_tag}'

    def get_latest_cuda_tag(self, base_image_postfix):
        """
        Query Docker Hub to find the latest patch version for a given CUDA X.Y version,
        considering only 'base' and 'devel' images, ignoring 'runtime'.
        """
        base_url = "https://hub.docker.com/v2/repositories/nvidia/cuda/tags"
        params = {"page_size": 100}
        latest_patch = None
        latest_patch_version = -1

        try:
            while base_url:
                response = requests.get(base_url, params=params)
                response.raise_for_status()
                data = response.json()

                for result in data.get("results", []):
                    tag = result.get("name", "")
                    if tag.startswith(self.cuda_version) and base_image_postfix in tag and 'runtime' not in tag:
                        match = re.match(rf"{self.cuda_version}\.(\d+)-(base|devel){base_image_postfix}", tag)
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
            raise ValueError(f"No matching CUDA image found for version {self.cuda_version}")



def main(cuda_version, ros_version):
    selector = ImageSelector(cuda_version, ros_version)
    return selector.determine_base_image()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Determine the base Docker image for CUDA and ROS.")
    parser.add_argument("--cuda", required=False, help="CUDA version in X.Y format (e.g., 12.6).")
    parser.add_argument("--ros", required=False, help="ROS version (e.g., noetic).")
    args = parser.parse_args()

    image = main(args.cuda, args.ros)
    print(image)
