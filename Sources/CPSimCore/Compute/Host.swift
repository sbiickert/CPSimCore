//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

public protocol Host: ObjectIdentity, ComputeNode {}

public class PhysicalHost: Host {
	public var id: String = UUID().uuidString
	public var name: String = "" {
		didSet {
			self.queue.name = name
		}
	}
	public var description: String?
	
	public var hardware: HardwareDefinition?
	public var queue: MultiQueue
	
	var virtualHosts = [VirtualHost]()

	init(_ hardware: HardwareDefinition) {
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
		self.queue.mode = .processing
	}

	public func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
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
}

public class VirtualHost: Host {
	public var id: String = UUID().uuidString
	public var name: String {
		didSet {
			self.queue.name = name
		}
	}
	public var description: String?
	
	public var vCpuCount: UInt
	public var vMemGB: UInt
	public weak var physicalHost: PhysicalHost! {
		willSet {
			physicalHost.virtualHosts.removeAll(where: {$0.id == self.id})
		}
		didSet {
			if physicalHost.virtualHosts.contains(where: {$0.id == self.id}) == false {
				physicalHost.virtualHosts.append(self)
			}
		}
	}
	public var hardware: HardwareDefinition? {
		get {
			return physicalHost.hardware
		}
		set {
			// Do nothing
		}
	}
	public var queue: MultiQueue

	public init(_ host: PhysicalHost, vCpus: UInt = 4, vMemGB: UInt = 16) {
		self.name = ""
		self.physicalHost = host
		self.vCpuCount = vCpus
		self.vMemGB = vMemGB
		self.queue = MultiQueue(channelCount: host.hardware?.coreCount ?? 0)
		self.queue.delegate = self
		self.queue.mode = .processing
		self.physicalHost.virtualHosts.append(self)
	}

	public func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
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
}
