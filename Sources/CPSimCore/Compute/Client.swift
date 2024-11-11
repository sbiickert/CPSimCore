//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// A model representing a computing device that is the source of requests
public class Client: ComputeNode {
	public override var name: String {
		didSet {
			self.queue.name = name
		}
	}
	
	/// Initializer. Takes the definition for the compute hardware
	/// - Parameter hardware: The compute hardware that is hosting this client.
	init(_ hardware: HardwareDefinition) {
		super.init()
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
		self.queue.mode = .processing
	}
	
	/// Delegate method from ServiceTimeCalculator called to get the amount of time it will take to process the request.
	/// - Parameter request: The ClientRequest that will be processed.
	/// - Returns: The processing time in seconds.
	public override func calculateServiceTime(for request: ClientRequest) -> Double {
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
	public override func calculateLatency(for request: ClientRequest) -> Double {
		return 0.0
	}
	

}
