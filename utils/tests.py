import unittest
from version_selector import VersionSelector, ImageNotFoundError


class TestBaseImage(unittest.TestCase):
    def setUp(self):
        self.selector = VersionSelector()

    def test_no_arguments(self):
        result = self.selector.determine_base_image(None, None)
        self.assertEqual(result, "ubuntu:24.04")

    def test_invalid_cuda(self):
        with self.assertRaises(ValueError):
            self.selector.determine_base_image("12.6.1", None)
        with self.assertRaises(ValueError):
            self.selector.determine_base_image("12", None)
        with self.assertRaises(ValueError):
            self.selector.determine_base_image("abcd", None)
        with self.assertRaises(ImageNotFoundError):
            self.selector.determine_base_image("1222.1222", None)

    def test_invalid_ros(self):
        with self.assertRaises(ValueError):
            self.selector.determine_base_image(None, 'ros')
        with self.assertRaises(ValueError):
            self.selector.determine_base_image(None, '1234')
        with self.assertRaises(ValueError):
            self.selector.determine_base_image(None, 'galactic')

    def test_valid_cuda_no_ros(self):
        result = self.selector.determine_base_image("12.6", None)
        self.assertEqual(result, "nvidia/cuda:12.6.3-devel-ubuntu24.04")

    def test_no_cuda_valid_ros(self):
        result = self.selector.determine_base_image(None, "noetic")
        self.assertEqual(result, "ubuntu:20.04")

    def test_valid_cuda_valid_ros(self):
        result = self.selector.determine_base_image("12.6", "noetic")
        self.assertEqual(result, "nvidia/cuda:12.6.3-devel-ubuntu20.04")

    def test_invalid_cuda_invalid_ros(self):
        with self.assertRaises(ValueError):
            self.selector.determine_base_image("12", "galactic")

    def test_valid_cuda_invalid_ros(self):
        with self.assertRaises(ValueError):
            self.selector.determine_base_image("12.6", "galactic")

    def test_invalid_cuda_valid_ros(self):
        with self.assertRaises(ValueError):
            self.selector.determine_base_image("12", "noetic")


if __name__ == "__main__":
    unittest.main()
