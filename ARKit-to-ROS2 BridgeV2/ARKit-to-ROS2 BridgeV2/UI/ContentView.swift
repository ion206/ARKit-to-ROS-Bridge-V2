//
//  ContentView.swift
//  ARKit-to-ROS2 BridgeV2
//
//  Created by Ayan Syed on 2/19/26.
//

import SwiftUI
import ARKit

struct ContentView: View {
	@StateObject private var networkStreamer = UDPStream()
		@StateObject private var arProvider = ARProvider()
		
		@State private var showSettings = false
		@State private var targetIP = "192.168.1.100" // Change based on tether/wifi
		@State private var targetPort = "9876"
		
		var body: some View {
			ZStack {
				// ARKit Camera Background
				ARViewContainer(session: arProvider.session)
					.ignoresSafeArea()
				
				VStack {
					HStack {
						// Status Indicator
						Circle()
							.fill(networkStreamer.isConnected ? Color.green : Color.red)
							.frame(width: 16, height: 16)
							.shadow(radius: 4)
						
						Text(networkStreamer.isConnected ? "Streaming" : "Disconnected")
							.font(.headline)
							.foregroundColor(.white)
							.shadow(radius: 2)
						
						Spacer()
						
						// Settings Button
						Button(action: { showSettings.toggle() }) {
							Image(systemName: "network")
								.font(.title2)
								.foregroundColor(.white)
								.padding()
								.background(Color.black.opacity(0.5))
								.clipShape(Circle())
						}
					}
					.padding()
					
					Spacer()
				}
			}
			.onAppear {
				arProvider.networkStreamer = networkStreamer
				arProvider.start()
				connect()
			}
			.sheet(isPresented: $showSettings) {
				VStack(spacing: 20) {
					Text("ROS 2 Target Configuration")
						.font(.title2).bold()
					
					TextField("IP Address (e.g., macbook.local or 10.0.0.5)", text: $targetIP)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.keyboardType(.numbersAndPunctuation)
					
					TextField("Port (e.g., 9876)", text: $targetPort)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.keyboardType(.numberPad)
					
					Button("Apply & Connect") {
						connect()
						showSettings = false
					}
					.padding()
					.background(Color.blue)
					.foregroundColor(.white)
					.cornerRadius(10)
				}
				.padding()
				.presentationDetents([.medium])
			}
		}
		
		private func connect() {
			if let port = UInt16(targetPort) {
				networkStreamer.connect(host: targetIP, port: port)
			}
		}
	}

	// Simple wrapper to display the ARSession feed in SwiftUI
	struct ARViewContainer: UIViewRepresentable {
		let session: ARSession
		
		func makeUIView(context: Context) -> ARSCNView {
			let view = ARSCNView(frame: .zero)
			view.session = session
			return view
		}
		func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

#Preview {
    ContentView()
}
