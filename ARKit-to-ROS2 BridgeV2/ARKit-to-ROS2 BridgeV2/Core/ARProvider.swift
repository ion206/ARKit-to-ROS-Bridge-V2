//
//  ARProvider.swift
//  ARKit-to-ROS2 BridgeV2
//
//  Created by Ayan Syed on 2/19/26.
//

import ARKit
import Foundation
import Combine

class ARProvider: NSObject, ARSessionDelegate, ObservableObject {
	let session = ARSession()
	private var encoder: JPEGEncoder?
	var networkStreamer: UDPStream?
	
	override init() {
		super.init()
		session.delegate = self
		// Initialize encoder for 640x480 (standard low-latency SLAM resolution)
		encoder = JPEGEncoder(width: 640, height: 480)
		
		encoder?.onCompressedData = { [weak self] data in
			self?.networkStreamer?.sendChunked(jpegData: data)
		}
	}
	
	func start() {
		let configuration = ARWorldTrackingConfiguration()
		// Provide 60fps buffer delivery
		if let videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: { $0.framesPerSecond == 60 }) {
			configuration.videoFormat = videoFormat
		}
		session.run(configuration)
	}
	
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		// Pass the IOSurface-backed buffer directly to the media engine
		encoder?.encode(pixelBuffer: frame.capturedImage, presentationTimeStamp: CMTime(seconds: frame.timestamp, preferredTimescale: 1000))
	}
}
