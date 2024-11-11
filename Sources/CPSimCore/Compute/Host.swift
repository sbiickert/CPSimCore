//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// Abstract superclass shared by ``PhysicalHost`` and ``VirtualHost``
/// Allows easier collection of mixed physical and virtual hosts in a design.
public class Host: ComputeNode {}

/// Model object representing a physical hardware host.
/// Required in order to have virtual hosts, or can be a stand-alone physical server performing a role.
public class PhysicalHost: Host {
	public override var name: String {
		didSet {
			self.queue.name = name
		}
	}
	
	/// A list of the virtual hosts running on this physical host.
	public var virtualHosts = [VirtualHost]()
	
	/// Initializer
	/// - Parameter hardware: The hardware definition of the physical host
	init(_ hardware: HardwareDefinition) {
		super.init()
		self.hardware = hardware
		self.queue = MultiQueue(channelCount: hardware.coreCount)
		self.queue.delegate = self
		self.queue.mode = .processing
	}

	/// Adjusts the service time based on the relative performance of the hardware
	///
	/// - Parameter workflowServiceTime: The standard service time in seconds.
	/// - Returns: The adjusted service time in seconds.
	public override func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
	}
	
	/// Passes the request to the ``queue``
	/// - Parameters:
	///   - request: The request to be processed.
	///   - clock: The current simulation time.
	public override func handle(request: ClientRequest, clock: Double) {
		queue.enqueue(request, clock: clock)
	}
	
	
	/// The length of time in seconds it will take the host to process this request.
	/// - Parameter request: The request to process.
	/// - Returns: Processing service time in seconds.
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

public class VirtualHost: Host {
	public override var name: String {
		didSet {
			self.queue.name = name
		}
	}
	
	/// The number of virtual CPUs assigned to this virtual machine
	public var vCpuCount: UInt
	/// The amount of memory in GB assigned to this virtual machine (not used in simulation)
	public var vMemGB: UInt
	
	/// Used when assigning a virtual host to a physical host or migrating from one physical host to another.
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
	
	/// Returns the hardware from the physical host. Read-only.
	public override var hardware: HardwareDefinition? {
		get {
			return physicalHost.hardware
		}
		set {
			// Do nothing
		}
	}
	
	/// Initializer
	/// - Parameters:
	///   - host: The physical host for the virtual machine
	///   - vCpus: The number of virtual CPUs assigned to the virtual machine
	///   - vMemGB: The amount of memory in GB assigned to this virtual machine
	public init(_ host: PhysicalHost, vCpus: UInt = 4, vMemGB: UInt = 16) {
		self.physicalHost = host
		self.vCpuCount = vCpus
		self.vMemGB = vMemGB
		super.init()
		self.queue = MultiQueue(channelCount: host.hardware?.coreCount ?? 0)
		self.queue.delegate = self
		self.queue.mode = .processing
		self.physicalHost.virtualHosts.append(self)
	}

	/// Adjusts the service time based on the relative performance of the physical host's hardware
	///
	/// - Parameter workflowServiceTime: The standard service time in seconds.
	/// - Returns: The adjusted service time in seconds.
	public override func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
	}
	
	/// Passes the request to the ``queue``
	/// - Parameters:
	///   - request: The request to be processed.
	///   - clock: The current simulation time.
	public override func handle(request: ClientRequest, clock: Double) {
		queue.enqueue(request, clock: clock)

	}
	
	/// The length of time in seconds it will take the host to process this request.
	/// - Parameter request: The request to process.
	/// - Returns: Processing service time in seconds.
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
