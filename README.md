#  ARKit to ROS 2 Bridge V2 (iOS App)

[![Swift](https://img.shields.io/badge/Swift-5.0+-FA7343?logo=swift)](https://developer.apple.com/swift/)
[![ARKit](https://img.shields.io/badge/Apple-ARKit-000000?logo=apple)](#)

## <img width="200" height="200" alt="v2 logo" src="https://github.com/user-attachments/assets/42ee3a30-1cfd-4e4a-88fd-4343540083de" />

A native iOS application that extracts high-fidelity Visual-Inertial Odometry (VIO), LiDAR depth, and RGB video from Apple's ARKit and streams it directly to a ROS 2 network. 

This repository is the **sender** half of the bridge. For the ROS 2 **receiver** package, see the [arkit_ros2_bridge](https://github.com/ion206/arkit_ros2_bridge) repository.

What's New in V2?
* **High-Speed UDP Streaming:** We stripped out the heavy TCP/WebSocket overhead. V2 uses a custom chunked UDP protocol, drastically reducing latency and preventing packet-queue backups.
* **Dual-Mode Architecture:** The app is now split into two dedicated branches (`vio` and `mapping`) to optimize network bandwidth based on your specific robotics use case.

V1: https://github.com/ion206/iOS-ARKit-to-ROS2

Note: This V2 with lower latency was developed for autonomous vehicle navigation. Check it out!!: https://github.com/daengineeringsociety/AutonomousRacer/tree/main

##  Branch Guide & Operational Modes

This repository has two distinct branches. **You must checkout the branch that matches your current robotics goal:**

### Topic Availability Matrix
Depending on the active branch, the iOS app transmits different payloads to the ROS 2 network.

| ROS 2 Topic | `vio` Branch | `mapping` Branch | Data Type | Description |
| :--- | :---: | :---: | :--- | :--- |
| `/synced/odom` | ✅ | ✅ | `nav_msgs/Odometry` | 6-DOF Visual-Inertial Odometry |
| `/tf` | ✅ | ✅ | `tf2_msgs/TFMessage` | Transform tree (`odom` ➔ `camera_link` ➔ `base_link`) |
| `/synced/rgb/image_raw` | ❌ | ✅ | `sensor_msgs/Image` | Compressed RGB video stream |
| `/synced/depth/image_raw` | ❌ | ✅ | `sensor_msgs/Image` | Native LiDAR depth map (32FC1) |
| `/synced/camera_info` | ❌ | ✅ | `sensor_msgs/CameraInfo`| Camera intrinsics and distortion models |

### 1. `vio` Branch (High-Speed Telemetry)
* **Best for:** Real-time autonomous navigation, control loops (Nav2), and hardware bridging.
* **Performance:** Streams pure odometry at ARKit's native **60Hz**, generating a ~180Hz `/tf` broadcast on the ROS end. Blazing Fast

### 2. `mapping` Branch (Full Spatial Payload)
* **Best for:** 3D SLAM, RTAB-Map, and environmental reconstruction.
* **Performance:** Transmits the complete multi-megabyte RGB-D sensor suite. Network bandwidth limits update rates to roughly ~6Hz, which is standard and ideal for dense map generation.

## 🛠️ Setup & Installation

1. Clone this repository and checkout your desired branch:
   ```bash
   git clone https://github.com/ion206/ARKit-to-ROS-Bridge-V2.git
   cd ARKit-to-ROS-Bridge-V2
   git checkout vio  # OR: git checkout mapping

2. Apple allows "Personal Development" for free, meaning you don't need to pay the $99/year Developer Program fee just to run your code on your own hardware. Deploying your own Swift apps to your personal iPhone/iPad is a straightforward process, but it requires a specific set of steps to bypass the standard App Store submission.
* **See [AppDeployment.md](https://github.com/ion206/ARKit-to-ROS-Bridge-V2/blob/b2bfe6fd1b2dbd93e2cc1326b7ea96a9da6c5005/AppDeloyment.md) for more details**
3. Configure and use over Wi-Fi, Ethernet, or USB-Tethering (USB-C -> USB-C)
