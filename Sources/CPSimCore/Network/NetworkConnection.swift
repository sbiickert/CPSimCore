//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

class NetworkConnection: ObjectIdentity, ServiceTimeCalculator {
	var id: String = UUID().uuidString
	var name: String = ""
	var description: String?
	
	var source: NetworkZone {
		willSet {
			source.connections.removeAll(where: {$0 === self})
		}
		didSet {
			source.connections.append(self)
		}
	}
	var destination: NetworkZone {
		willSet {
			destination.connections.removeAll(where: {$0 === self})
		}
		didSet {
			destination.connections.append(self)
		}
	}
	let bandwidth: UInt
	let latency: UInt

	var queue: MultiQueue

	var isLocalConnection: Bool {
		return source === destination
	}

	init(sourceZone: NetworkZone, destZone: NetworkZone, bandwidth bw: UInt = 100, latencyMilliSeconds: UInt = 10) {
		source = sourceZone
		destination = destZone
		bandwidth = bw
		latency = latencyMilliSeconds
		queue = MultiQueue(channelCount: 1)
		queue.delegate = self
		source.connections.append(self)
		if source !== destination {
			destination.connections.append(self)
		}
	}
	
	func calculateServiceTime(for request: ClientRequest) -> Double {
		var serviceTime = 0.0
//		if let step = request.solution?.currentStep {
//			var dataSize = ClientRequest.requestSize
//			if step.isResponse {
//				if step.computeRole == .client {
//					dataSize = request.clientTraffic
//				}
//				else {
//					dataSize = request.serverTraffic
//				}
//			}
//			// data (Mb) / bandwidth (Mb/s) = transfer time in seconds
//			let transferTime = dataSize / Double(bandwidth)
//			// TODO: should this be more complex, and simulate sending (chatter) packets of data?
//			// chatter * latency (milliseconds) * 0.001 = latency time in seconds
//			let latencyTime = Double(request.configuredWorkflow.workflow.chatter) * Double(latency) * 0.001
//			serviceTime = transferTime + latencyTime
//			//assert(serviceTime < 2.1, "Long network service time: \(serviceTime)s")
//		}
		return serviceTime
	}

}
