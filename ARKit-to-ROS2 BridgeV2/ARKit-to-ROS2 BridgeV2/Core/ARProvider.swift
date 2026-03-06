import ARKit
import Foundation
import Combine
import CoreImage // <-- Required for native compression

class ARProvider: NSObject, ARSessionDelegate, ObservableObject {
	let session = ARSession()
	var networkStreamer: UDPStream?
	private var frameCounter: Int = 0
	private let ciContext = CIContext(options: nil) // Replaces JPEGEncoder
	
	override init() {
		super.init()
		session.delegate = self
	}
	
	func start() {
		let configuration = ARWorldTrackingConfiguration()
		if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
			configuration.frameSemantics.insert(.sceneDepth)
		}
		if let videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: { $0.framesPerSecond == 60 }) {
			configuration.videoFormat = videoFormat
		}
		session.run(configuration)
	}
	
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
			let timestamp = frame.timestamp
			frameCounter += 1
			
			// 1. Send Odometry (TF) at MAXIMUM frequency (60 Hz)
			// This keeps your RViz robot model moving smoothly without stuttering
			var transform = frame.camera.transform
			let transformData = Data(bytes: &transform, count: MemoryLayout<simd_float4x4>.size)
			networkStreamer?.sendChunked(data: transformData, topicID: 2, timestamp: timestamp)
			
			// 2. THROTTLE HEAVY PAYLOADS: Only process RGB and Depth every 4th frame (15 Hz)
			if frameCounter % 4 != 0 {
				return
			}
			
			// 3. RGB (Topic 0) @ 15 Hz
			let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
			let scale = 640.0 / ciImage.extent.width
			let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
			
			if let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
				let uiImage = UIImage(cgImage: cgImage)
				if let jpegData = uiImage.jpegData(compressionQuality: 0.5) {
					networkStreamer?.sendChunked(data: jpegData, topicID: 0, timestamp: timestamp)
				}
			}
			
		// 4. LiDAR Depth (Topic 1) @ 15 Hz
				if let sceneDepth = frame.sceneDepth {
					let depthMap = sceneDepth.depthMap
					CVPixelBufferLockBaseAddress(depthMap, .readOnly)
					if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
						let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
						let height = CVPixelBufferGetHeight(depthMap)
						let depthData = Data(bytes: baseAddress, count: bytesPerRow * height)
						
						// 🚀 Compress the 196KB float array using standard Zlib
						let nsData = NSData(data: depthData)
						if let compressedDepth = try? nsData.compressed(using: .zlib) as Data {
							networkStreamer?.sendChunked(data: compressedDepth, topicID: 1, timestamp: timestamp)
						}
					}
					CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
				}
			
			// 5. Camera Intrinsics (Topic 3) - Sent every ~2 seconds
			if frameCounter % 120 == 0 {
				let k = frame.camera.intrinsics
				var intrinsicsArray: [Float] = [
					k[0][0], k[0][1], k[0][2],
					k[1][0], k[1][1], k[1][2],
					k[2][0], k[2][1], k[2][2]
				]
				let intrinsicsData = Data(bytes: &intrinsicsArray, count: 36)
				networkStreamer?.sendChunked(data: intrinsicsData, topicID: 3, timestamp: timestamp)
			}
		}
}
