//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

protocol Host: ObjectIdentity, ComputeNode {}

class PhysicalHost: Host {
	var id: String = UUID().uuidString
	var name: String = "" {
		didSet {
			self.queue.name = name
		}
	}
	var description: String?
	
	var hardware: HardwareDefinition?
	var queue: MultiQueue
	
	var virtualHosts = [VirtualHost]()

	init(_ hardware: HardwareDefinition) {
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
	}

	func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
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
	
	
}

class VirtualHost: Host {
	var id: String = UUID().uuidString
	var name: String {
		didSet {
			self.queue.name = name
		}
	}
	var description: String?
	
	var vCpuCount: UInt
	var vMemGB: UInt
	weak var physicalHost: PhysicalHost! {
		willSet {
			physicalHost.virtualHosts.removeAll(where: {$0.id == self.id})
		}
		didSet {
			if physicalHost.virtualHosts.contains(where: {$0.id == self.id}) == false {
				physicalHost.virtualHosts.append(self)
			}
		}
	}
	var hardware: HardwareDefinition? {
		get {
			return physicalHost.hardware
		}
		set {
			// Do nothing
		}
	}
	var queue: MultiQueue

	init(_ host: PhysicalHost, vCpus: UInt = 4, vMemGB: UInt = 16) {
		self.name = ""
		self.physicalHost = host
		self.vCpuCount = vCpus
		self.vMemGB = vMemGB
		self.queue = MultiQueue(channelCount: host.hardware?.coreCount ?? 0)
		self.queue.delegate = self
		self.physicalHost.virtualHosts.append(self)
	}

	func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
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
}
