//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// A model representing a computing device that is the source of requests
public class Client: ObjectIdentity, ComputeNode {
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the client (expected to be unique)
	public var name: String = "" {
		didSet {
			self.queue.name = name
		}
	}
	/// A friendly description of the client
	public var description: String = ""
	
	/// The definition of the hardware that hosts this client.
	public var hardware: HardwareDefinition?
	/// The queue for handling requests as they come in.
	public var queue: MultiQueue
	
	/// Initializer. Takes the definition for the compute hardware
	/// - Parameter hardware: The compute hardware that is hosting this client.
	init(_ hardware: HardwareDefinition) {
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
		self.queue.mode = .processing
	}
	
	/// Client is passed the request at simulation time. It queues the request.
	/// - Parameters:
	///   - request: The request to handle.
	///   - clock: The simulation time that the Client is receiving the request.
	public func handle(request: ClientRequest, clock: Double) {
		queue.enqueue(request, clock: clock)
	}
	
	/// Delegate method from ServiceTimeCalculator called to get the amount of time it will take to process the request.
	/// - Parameter request: The ClientRequest that will be processed.
	/// - Returns: The processing time in seconds.
	public func calculateServiceTime(for request: ClientRequest) -> Double {
		var serviceTime = ClientRequest.requestTime
		if let step = request.solution?.currentStep {
			serviceTime = request.serviceTimes[step.computeRole] ?? 0.0
			// Adjust by the hardware rating
			serviceTime = adjustedServiceTime(serviceTime)
		}
		return serviceTime
	}
	
	/// Delegate method from ServiceTimeCalculator to get the amount of network latency for the request
	///
	/// - Parameter request: the ClientRequest to calculate latency for.
	/// - Returns: The calculated network latency in seconds.
	public func calculateLatency(for request: ClientRequest) -> Double {
		return 0.0
	}
	
	/// Adjusts the service time based on the `Client` `hardwareDefinition`
	///
	/// - Parameter workflowServiceTime: The standard service time in seconds.
	/// - Returns: The adjusted service time in seconds.
	public func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
	}
	

}
