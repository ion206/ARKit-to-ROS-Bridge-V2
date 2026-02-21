# ARkit to ROS2 Bridge V2
Transforms any iPhone/iPad Pro device into a high-performance ROS 2 visual and spatial sensor suite. Wired/Wireless LiDAR, depth, rgb, odometry and more for real-time SLAM and navigation



### ROS 2 Installation (Sparse Checkout)

If you are working on the ROS 2 side and don't want to download the whole iOS Xcode project, use Git's sparse-checkout feature to pull *only* the ROS package directly into your src workspace.

**1. Pull the package into your workspace:**
```bash
cd ~/ros2_ws/src
git clone --no-checkout [https://github.com/ion206/iOS-ARKit-to-ROS2.git](https://github.com/ion206/iOS-ARKit-to-ROS2.git)
cd iOS-ARKit-to-ROS2
git sparse-checkout init --cone
git sparse-checkout set arkit_ros_bridge
git checkout main