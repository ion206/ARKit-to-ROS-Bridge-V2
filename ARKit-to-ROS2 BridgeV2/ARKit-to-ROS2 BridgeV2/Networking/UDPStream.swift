//
//  UDPStream.swift
//  ARKit-to-ROS2 BridgeV2
//
//  Created by Ayan Syed on 2/19/26.
//

import Foundation
import Network
import Combine

class UDPStream: ObservableObject {
	@Published var isConnected: Bool = false
	
	private var connection: NWConnection?
	private let queue = DispatchQueue(label: "daes.network.queue", qos: .userInteractive)
	private let mtuSize = 1400
	private var frameCounter: UInt32 = 0
	
	func connect(host: String, port: UInt16) {
		connection?.cancel()
		
		let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
		let parameters = NWParameters.udp
		parameters.allowFastOpen = true
		
		connection = NWConnection(to: endpoint, using: parameters)
		
		connection?.stateUpdateHandler = { [weak self] state in
			DispatchQueue.main.async {
				switch state {
				case .ready:
					self?.isConnected = true
				case .failed(_), .cancelled:
					self?.isConnected = false
				default:
					break
				}
			}
		}
		connection?.start(queue: queue)
	}

	func sendChunked(jpegData: Data) {
		guard isConnected, let connection = connection else { return }
		
		frameCounter &+= 1
		let currentFrameId = frameCounter
		let totalChunks = UInt16((jpegData.count + mtuSize - 1) / mtuSize)
		
		for chunkIndex in 0..<totalChunks {
			let offset = Int(chunkIndex) * mtuSize
			let length = min(mtuSize, jpegData.count - offset)
			let chunkData = jpegData.subdata(in: offset..<(offset + length))
			
			var header = Data()
			var fId = currentFrameId.bigEndian
			var tChunks = totalChunks.bigEndian
			var cIdx = chunkIndex.bigEndian
			
			header.append(Data(bytes: &fId, count: 4))
			header.append(Data(bytes: &tChunks, count: 2))
			header.append(Data(bytes: &cIdx, count: 2))
			
			connection.send(content: header + chunkData, completion: .contentProcessed({ _ in }))
		}
	}
}
