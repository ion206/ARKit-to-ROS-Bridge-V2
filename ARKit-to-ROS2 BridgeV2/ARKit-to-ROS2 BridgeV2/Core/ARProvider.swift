import ARKit
import Foundation
import Combine
import CoreImage

class ARProvider: NSObject, ARSessionDelegate, ObservableObject {
	let session = ARSession()
	var networkStreamer: UDPStream?
	private var frameCounter: Int = 0
	
	// Force CoreImage to use the GPU (Metal) for zero-latency resizing
	private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
	
	// 🚀 THE RTAB-MAP GOLDEN RESOLUTION
	private let targetW: CGFloat = 480.0
	private let targetH: CGFloat = 360.0

	override init() {
		super.init()
		session.delegate = self
	}

	func start() {
		let configuration = ARWorldTrackingConfiguration()
		
		// 🚀 STRIP THE FAT: Turn off everything RTAB-Map doesn't need
		configuration.planeDetection = []
		configuration.environmentTexturing = .none
		configuration.isLightEstimationEnabled = false
		configuration.sceneReconstruction = []
		
		if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
			configuration.frameSemantics.insert(.sceneDepth)
		}
		
		// Lock to 60fps natively
		if let videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: { $0.framesPerSecond == 60 }) {
			configuration.videoFormat = videoFormat
		}
		session.run(configuration)
	}

	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		frameCounter += 1
		
		// 🚀 THE 15 HZ LOCK: Everything fires together at 15fps
		if frameCounter % 4 != 0 { return }
		
		let timestamp = frame.timestamp
		
		// ==========================================
		// 1. ODOMETRY (Topic 2)
		// ==========================================
		var transform = frame.camera.transform
		let transformData = Data(bytes: &transform, count: MemoryLayout<simd_float4x4>.size)
		networkStreamer?.sendChunked(data: transformData, topicID: 2, timestamp: timestamp)

		// ==========================================
		// 2. CAMERA INFO / INTRINSICS (Topic 3)
		// ==========================================
		let imageResolution = frame.camera.imageResolution
		let scaleX = Float(targetW / imageResolution.width)
		let scaleY = Float(targetH / imageResolution.height)
		
		var k = frame.camera.intrinsics
		// Mathematically scale the focal lengths to match the new 480x360 size
		k[0][0] *= scaleX // fx
		k[1][1] *= scaleY // fy
		k[2][0] *= scaleX // cx
		k[2][1] *= scaleY // cy
		
		var intrinsicsArray: [Float] = [
			k[0][0], k[0][1], k[0][2],
			k[1][0], k[1][1], k[1][2],
			k[2][0], k[2][1], k[2][2]
		]
		let intrinsicsData = Data(bytes: &intrinsicsArray, count: 36)
		networkStreamer?.sendChunked(data: intrinsicsData, topicID: 3, timestamp: timestamp)

		// ==========================================
		// 3. RGB IMAGE (Topic 0) - Scaled to 480x360
		// ==========================================
		let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
		let rgbScaleX = targetW / ciImage.extent.width
		let rgbScaleY = targetH / ciImage.extent.height
		let scaledRGB = ciImage.transformed(by: CGAffineTransform(scaleX: rgbScaleX, y: rgbScaleY))
		
		if let cgImage = ciContext.createCGImage(scaledRGB, from: scaledRGB.extent) {
			let uiImage = UIImage(cgImage: cgImage)
			if let jpegData = uiImage.jpegData(compressionQuality: 0.5) {
				networkStreamer?.sendChunked(data: jpegData, topicID: 0, timestamp: timestamp)
			}
		}

		// ==========================================
		// 4. LiDAR DEPTH (Topic 1) - Scaled to 480x360
		// ==========================================
		guard let sceneDepth = frame.sceneDepth else { return }
		let depthCI = CIImage(cvPixelBuffer: sceneDepth.depthMap)
		let depthScaleX = targetW / depthCI.extent.width
		let depthScaleY = targetH / depthCI.extent.height
		
		// 🚀 NEAREST NEIGHBOR is required so depth values aren't mathematically blended!
		let scaledDepth = depthCI.samplingNearest()
								 .transformed(by: CGAffineTransform(scaleX: depthScaleX, y: depthScaleY))
		
		// Render directly to a Float32 array (ROS expects 32FC1)
		var depthPixels = [Float32](repeating: 0, count: Int(targetW * targetH))
		ciContext.render(scaledDepth,
						 toBitmap: &depthPixels,
						 rowBytes: Int(targetW) * MemoryLayout<Float32>.size,
						 bounds: CGRect(x: 0, y: 0, width: targetW, height: targetH),
						 format: .Lf, // CoreImage Float32 format
						 colorSpace: nil)
		
		let depthData = Data(bytes: &depthPixels, count: Int(targetW * targetH) * 4)
		
		// Zlib compression before sending
		let nsData = NSData(data: depthData)
		if let compressedDepth = try? nsData.compressed(using: .zlib) as Data {
			networkStreamer?.sendChunked(data: compressedDepth, topicID: 1, timestamp: timestamp)
		}
	}
}
