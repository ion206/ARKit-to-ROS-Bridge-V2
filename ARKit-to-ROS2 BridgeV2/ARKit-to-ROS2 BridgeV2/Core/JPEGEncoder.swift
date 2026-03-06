import Foundation
import VideoToolbox
import CoreMedia

class JPEGEncoder {
	private var compressionSession: VTCompressionSession?
	private let quality: NSNumber = 0.5
	
	// 1. Update the callback signature to include TimeInterval
	var onCompressedData: ((Data, TimeInterval) -> Void)?

	init(width: Int32, height: Int32) {
		let status = VTCompressionSessionCreate(
			allocator: kCFAllocatorDefault,
			width: width,
			height: height,
			codecType: kCMVideoCodecType_JPEG,
			encoderSpecification: nil,
			imageBufferAttributes: nil,
			compressedDataAllocator: nil,
			outputCallback: compressionCallback,
			refcon: Unmanaged.passUnretained(self).toOpaque(),
			compressionSessionOut: &compressionSession
		)
		
		guard status == noErr, let session = compressionSession else {
			print("Failed to create hardware encoder: \(status)")
			return
		}
		
		VTSessionSetProperty(session, key: kVTCompressionPropertyKey_Quality, value: quality)
		VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
	}

	func encode(pixelBuffer: CVPixelBuffer, presentationTimeStamp: CMTime) {
		guard let session = compressionSession else { return }
		
		VTCompressionSessionEncodeFrame(
			session,
			imageBuffer: pixelBuffer,
			presentationTimeStamp: presentationTimeStamp,
			duration: .invalid,
			frameProperties: nil,
			sourceFrameRefcon: nil,
			infoFlagsOut: nil
		)
	}

	private let compressionCallback: VTCompressionOutputCallback = { outputCallbackRefCon, _, status, infoFlags, sampleBuffer in
		guard status == noErr, let sampleBuffer = sampleBuffer, let refCon = outputCallbackRefCon else { return }
		
		let encoder = Unmanaged<JPEGEncoder>.fromOpaque(refCon).takeUnretainedValue()
		
		// 2. Extract the exact timestamp from the sample buffer
		let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		let timestamp = pts.seconds
		
		guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
		var lengthAtOffset = 0
		var totalLength = 0
		var dataPointer: UnsafeMutablePointer<Int8>?
		
		if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr {
			if let pointer = dataPointer {
				let data = Data(bytesNoCopy: pointer, count: totalLength, deallocator: .none)
				// 3. Pass both the compressed image and the timestamp
				encoder.onCompressedData?(data, timestamp)
			}
		}
	}
}
