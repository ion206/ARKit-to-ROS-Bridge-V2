//
//  JPEGEncoder.swift
//  ARKit-to-ROS2 BridgeV2
//
//  Created by Ayan Syed on 2/19/26.
//


import Foundation
import VideoToolbox
import CoreMedia

class JPEGEncoder {
	private var compressionSession: VTCompressionSession?
	private let quality: NSNumber = 0.5
	var onCompressedData: ((Data) -> Void)?

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
			
			// Hardware encoding happens asynchronously without CPU memory copies.
			let status = VTCompressionSessionEncodeFrame(
				session,
				imageBuffer: pixelBuffer,
				presentationTimeStamp: presentationTimeStamp,
				duration: .invalid,
				frameProperties: nil,
				sourceFrameRefcon: nil,
				infoFlagsOut: nil
			)
			
			if status != noErr {
				print("Encoding error: \(status)")
			}
		}

	private let compressionCallback: VTCompressionOutputCallback = { outputCallbackRefCon, _, status, infoFlags, sampleBuffer in
		guard status == noErr, let sampleBuffer = sampleBuffer, let refCon = outputCallbackRefCon else { return }
		
		let encoder = Unmanaged<JPEGEncoder>.fromOpaque(refCon).takeUnretainedValue()
		
		// Extract the compressed payload safely
		guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
		var lengthAtOffset = 0
		var totalLength = 0
		var dataPointer: UnsafeMutablePointer<Int8>?
		
		if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr {
			if let pointer = dataPointer {
				// Wrap the pointer in Data without duplicating the underlying buffer if possible
				let data = Data(bytesNoCopy: pointer, count: totalLength, deallocator: .none)
				encoder.onCompressedData?(data)
			}
		}
	}
}
