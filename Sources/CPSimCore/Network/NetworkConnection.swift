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
	var bandwidth: UInt
	var latency: UInt

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
		queue.mode = .transmitting
		source.connections.append(self)
		if source !== destination {
			destination.connections.append(self)
			self.name = "\(sourceZone.name) -> \(destZone.name)"
		}
		else {
			self.name = "\(sourceZone.name) Local"
		}
		queue.name = "\(name) Q"
	}
	
	func invert() -> NetworkConnection {
		return NetworkConnection(sourceZone: self.destination,
								 destZone: self.source,
								 bandwidth: self.bandwidth,
								 latencyMilliSeconds: self.latency)
	}
	
	func calculateServiceTime(for request: ClientRequest) -> Double {
		var serviceTime = 0.0
		if let step = request.solution?.currentStep {
			// data (Mb) / bandwidth (Mb/s) = transfer time in seconds
			let transferTime = step.dataSize / Double(bandwidth)
			
			serviceTime = transferTime
			//assert(serviceTime < 2.1, "Long network service time: \(serviceTime)s")
		}
		return serviceTime
	}

	func calculateLatency(for request: ClientRequest) -> Double {
		// TODO: should this be more complex, and simulate sending (chatter) packets of data?
		// chatter * latency (milliseconds) * 0.001 = latency time in seconds
		var result = 0.0
		if let step = request.solution?.currentStep {
			if step.isResponse {
				result = Double(request.configuredWorkflow.definition.chatter) * Double(self.latency) * 0.001
			}
		}
		return result
	}
}
