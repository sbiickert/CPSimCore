//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// Model object representing a one-way connection between ``NetworkZone``s. In order for there
/// to be two-way communication between zones, two connections are needed, one in each direction.
/// This allows for asymmetric networking.
public class NetworkConnection: ObjectIdentity, ServiceTimeCalculator {
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the connection (expected to be unique)
	public var name: String = ""
	/// A friendly description of the connection
	public var description: String?
	
	/// The zone that data flows **from**
	public var source: NetworkZone {
		willSet {
			source.connections.removeAll(where: {$0 === self})
		}
		didSet {
			source.connections.append(self)
		}
	}
	/// The zone that data flows **to**
	public var destination: NetworkZone {
		willSet {
			destination.connections.removeAll(where: {$0 === self})
		}
		didSet {
			destination.connections.append(self)
		}
	}
	/// The connection bandwidth in Mbps
	public var bandwidth: UInt
	/// The connection latency in milliseconds
	public var latency: UInt

	/// The queue for transferring data over the connection. Single channel.
	public var queue: MultiQueue

	/// Test to see if this connection begins and ends in the same zone.
	public var isLocalConnection: Bool {
		return source === destination
	}
	
	/// Initializer
	/// - Parameters:
	///   - sourceZone: The zone where data is flowing from.
	///   - destZone: The zone where data is flowing to.
	///   - bw: The bandwidth in Mbps.
	///   - latencyMilliSeconds: The latency in milliseconds.
	public init(sourceZone: NetworkZone, destZone: NetworkZone, bandwidth bw: UInt = 100, latencyMilliSeconds: UInt = 10) {
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
	
	/// Convenience method to clone this connection in the opposite direction (destination -> source)
	public func invert() -> NetworkConnection {
		return NetworkConnection(sourceZone: self.destination,
								 destZone: self.source,
								 bandwidth: self.bandwidth,
								 latencyMilliSeconds: self.latency)
	}
	
	/// Delegate method from ServiceTimeCalculator called to get the amount of time it will take to transfer the request's data.
	/// - Parameter request: The request to process.
	/// - Returns: The time in seconds to transfer the data.
	public func calculateServiceTime(for request: ClientRequest) -> Double {
		var serviceTime = 0.0
		if let step = request.solution?.currentStep {
			// data (Mb) / bandwidth (Mb/s) = transfer time in seconds
			let transferTime = step.dataSize / Double(bandwidth)
			
			serviceTime = transferTime
			//assert(serviceTime < 2.1, "Long network service time: \(serviceTime)s")
		}
		return serviceTime
	}

	/// Delegate method from ServiceTimeCalculator to get the amount of network latency for the request
	///
	/// - Parameter request: the ClientRequest to calculate latency for.
	/// - Returns: The calculated network latency in seconds.
	public func calculateLatency(for request: ClientRequest) -> Double {
		// TODO: should this be more complex, and simulate sending (chatter) packets of data?
		// chatter * latency (milliseconds) * 0.001 = latency time in seconds
		var result = 0.0
		if let step = request.solution?.currentStep {
			if step.isResponse == false {
				// Will calc latency on the request leg
				result = Double(request.configuredWorkflow.definition.chatter) * Double(self.latency) * 0.001
			}
		}
		return result
	}
}
