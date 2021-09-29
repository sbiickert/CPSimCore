//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

class Client: ObjectIdentity, ComputeNode {
	var id: String = UUID().uuidString
	var name: String = "" {
		didSet {
			self.queue.name = name
		}
	}
	var description: String?
	
	var hardware: HardwareDefinition?
	var queue: MultiQueue

	init(_ hardware: HardwareDefinition) {
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
	}
	
	func handle(request: ClientRequest, clock: Double) {
		queue.enqueue(request, clock: clock)
	}
	
	func calculateServiceTime(for request: ClientRequest) -> Double {
		var serviceTime = ClientRequest.requestTime
//		if let step = request.solution?.currentStep {
//			if step.isResponse {
//				serviceTime = request.referenceServiceTimes[step.computeRole] ?? 0.0
//			}
//			// Adjust by the hardware rating
//			serviceTime = adjustedServiceTime(serviceTime)
//		}
		return serviceTime
	}
	
	func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
	}
	

}
