import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data

from sensor_msgs.msg import Image, CameraInfo
from std_msgs.msg import Header
import cv2
from cv_bridge import CvBridge
import numpy as np
from geometry_msgs.msg import PoseStamped

class ShuttleDetectionNode(Node):
    def __init__(self):
        super().__init__('shuttle_detection_node')

        self.bridge = CvBridge()
        self.shuttle_pub = self.create_publisher(PoseStamped, '/perception/shuttle_pos', 10)
        self.timer = self.create_timer(1.0, self.publish_shuttle_position)
        self.get_logger().info('Shuttle detection node started (1 Hz)')

    def publish_shuttle_position(self):
        msg = PoseStamped()
        self.shuttle_pub.publish(msg)

def main(args=None):
    rclpy.init(args=args)
    node = ShuttleDetectionNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
    