//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

public class Client: ObjectIdentity, ComputeNode {
	public var id: String = UUID().uuidString
	public var name: String = "" {
		didSet {
			self.queue.name = name
		}
	}
	public var description: String?
	
	public var hardware: HardwareDefinition?
	public var queue: MultiQueue

	init(_ hardware: HardwareDefinition) {
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
		self.queue.mode = .processing
	}
	
	public func handle(request: ClientRequest, clock: Double) {
		queue.enqueue(request, clock: clock)
	}
	
	public func calculateServiceTime(for request: ClientRequest) -> Double {
		var serviceTime = ClientRequest.requestTime
		if let step = request.solution?.currentStep {
			serviceTime = request.serviceTimes[step.computeRole] ?? 0.0
			// Adjust by the hardware rating
			serviceTime = adjustedServiceTime(serviceTime)
		}
		return serviceTime
	}
	
	public func calculateLatency(for request: ClientRequest) -> Double {
		return 0.0
	}
	
	public func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
	}
	

}
