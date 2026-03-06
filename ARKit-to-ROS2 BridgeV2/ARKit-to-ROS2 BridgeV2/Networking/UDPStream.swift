import Foundation
import Network
import Combine

class UDPStream: ObservableObject {
	@Published var isConnected: Bool = false
	
	private var connection: NWConnection?
	private let queue = DispatchQueue(label: "daes.network.queue", qos: .userInteractive)
	private let mtuSize = 1400
	
	func connect(host: String, port: UInt16) {
		connection?.cancel()
		
		let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
		let parameters = NWParameters.udp
		parameters.allowFastOpen = true
		
		// CRUCIAL FOR DOCKER: Force IPv4 so the Linux VM doesn't drop the packets
		if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
			ipOptions.version = .v4
		}
		
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

	// ONLY the Multiplexed 14-byte sender should exist
	func sendChunked(data: Data, topicID: UInt8, timestamp: TimeInterval) {
		guard isConnected, let connection = connection else { return }
		
		let sec = UInt32(floor(timestamp))
		let nano = UInt32((timestamp - floor(timestamp)) * 1_000_000_000)
		
		let totalChunks = UInt16((data.count + mtuSize - 1) / mtuSize)
		
		
		for chunkIndex in 0..<totalChunks {
			let offset = Int(chunkIndex) * mtuSize
			let length = min(mtuSize, data.count - offset)
			let chunkData = data.subdata(in: offset..<(offset + length))
			print("📲 Sending Chunk: \(chunkData.count) bytes for Topic \(topicID)")
			
			var header = Data()
			var tID = topicID
			var pad: UInt8 = 0
			var s = sec.bigEndian
			var n = nano.bigEndian
			var tChunks = totalChunks.bigEndian
			var cIdx = chunkIndex.bigEndian
			
			header.append(Data(bytes: &tID, count: 1))
			header.append(Data(bytes: &pad, count: 1))
			header.append(Data(bytes: &s, count: 4))
			header.append(Data(bytes: &n, count: 4))
			header.append(Data(bytes: &tChunks, count: 2))
			header.append(Data(bytes: &cIdx, count: 2))
			
			connection.send(content: header + chunkData, completion: .contentProcessed({ _ in }))
		}
	}
}
