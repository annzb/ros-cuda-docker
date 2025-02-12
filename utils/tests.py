import unittest
from find_base_image import main


class TestBaseImage(unittest.TestCase):
    def test_main_no_arguments(self):
        result = main(None, None)
        self.assertEqual(result, "ubuntu:24.04")

    def test_main_invalid_cuda(self):
        with self.assertRaises(SystemExit):
            main("12.6.1", None)
        with self.assertRaises(SystemExit):
            main("12", None)
        with self.assertRaises(SystemExit):
            main("abcd", None)
        with self.assertRaises(SystemExit):
            main("1222.1222", None)

    def test_main_invalid_ros(self):
        with self.assertRaises(SystemExit):
            main(None, 'ros')
        with self.assertRaises(SystemExit):
            main(None, '1234')
        with self.assertRaises(SystemExit):
            main(None, 'galactic')

    def test_main_valid_cuda_no_ros(self):
        result = main("12.6", None)
        self.assertEqual(result, "nvidia/cuda:12.6.3-base-ubuntu24.04")

    def test_main_no_cuda_valid_ros(self):
        result = main(None, "noetic")
        self.assertEqual(result, "ubuntu:20.04")

    def test_main_valid_cuda_valid_ros(self):
        result = main("12.6", "noetic")
        self.assertEqual(result, "nvidia/cuda:12.6.3-base-ubuntu20.04")

    def test_main_invalid_cuda_invalid_ros(self):
        with self.assertRaises(SystemExit):
            main("12", "galactic")

    def test_main_valid_cuda_invalid_ros(self):
        with self.assertRaises(SystemExit):
            main("12.6", "galactic")

    def test_main_invalid_cuda_valid_ros(self):
        with self.assertRaises(SystemExit):
            main("12", "noetic")


if __name__ == "__main__":
    unittest.main()
