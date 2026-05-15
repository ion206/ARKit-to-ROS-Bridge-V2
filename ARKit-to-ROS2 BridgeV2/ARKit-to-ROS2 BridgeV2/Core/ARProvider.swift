import ARKit
import Foundation
import Combine

class ARProvider: NSObject, ARSessionDelegate, ObservableObject {
	let session = ARSession()
	var networkStreamer: UDPStream?

	override init() {
		super.init()
		session.delegate = self
	}

	func start() {
		let configuration = ARWorldTrackingConfiguration()
		
		// 🚀 STRIP THE FAT: Turn off absolutely everything except pure VIO tracking
		configuration.planeDetection = []
		configuration.environmentTexturing = .none
		configuration.isLightEstimationEnabled = false
		configuration.sceneReconstruction = []
		
		// Lock to 60fps natively for zero-latency control loops
		if let videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: { $0.framesPerSecond == 60 }) {
			configuration.videoFormat = videoFormat
		}
		session.run(configuration)
	}

	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		let timestamp = frame.timestamp
		
		// ==========================================
		// 1. ODOMETRY ONLY (Topic 2) - 60 Hz
		// ==========================================
		var transform = frame.camera.transform
		let transformData = Data(bytes: &transform, count: MemoryLayout<simd_float4x4>.size)
		
		// Fire it immediately
		networkStreamer?.sendChunked(data: transformData, topicID: 2, timestamp: timestamp)
	}
}
