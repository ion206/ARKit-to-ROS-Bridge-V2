#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import CompressedImage
import socket
import struct
import time
import array

class UDPReceiverNode(Node):
    def __init__(self):
        super().__init__('ios_camera_bridge')
        self.publisher_ = self.create_publisher(CompressedImage, '/camera/rgb/compressed', 10)
        
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('0.0.0.0', 9876))
        self.sock.setblocking(False)
        
        self.timer = self.create_timer(0.001, self.poll_socket)
        
        self.frame_buffers = {}
        self.last_frame_id = -1

    def poll_socket(self):
        try:
            while True:
                data, _ = self.sock.recvfrom(2048)
                if len(data) < 8:
                    continue
                
                # Unpack header
                frame_id, total_chunks, chunk_idx = struct.unpack('>IHH', data[:8])
                payload = data[8:]
                
                # Drop old frames to prioritize latency
                if frame_id < self.last_frame_id:
                    continue
                    
                if frame_id not in self.frame_buffers:
                    self.frame_buffers[frame_id] = {
                        'chunks': [None] * total_chunks,
                        'received': 0,
                        'timestamp': time.time()
                    }
                
                buffer = self.frame_buffers[frame_id]
                if buffer['chunks'][chunk_idx] is None:
                    buffer['chunks'][chunk_idx] = payload
                    buffer['received'] += 1
                
                # If frame is complete, publish
                if buffer['received'] == total_chunks:
                    self.publish_frame(frame_id, buffer['chunks'])
                    self.last_frame_id = max(self.last_frame_id, frame_id)
                    self.cleanup_old_frames(self.last_frame_id)
                    
        except BlockingIOError:
            pass

    def publish_frame(self, frame_id, chunks):
        jpeg_data = b''.join(chunks)
        msg = CompressedImage()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = "iphone_camera_link"
        msg.format = "jpeg"
        # Fast C-level array conversion
        msg.data = array.array('B', jpeg_data).tolist() 
        self.publisher_.publish(msg)

def main(args=None):
    rclpy.init(args=args)
    node = UDPReceiverNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()