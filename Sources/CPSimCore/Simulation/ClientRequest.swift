//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-28.
//

import Foundation

/// Model object that represents the basic "jobs" that are handled by the simulated system.
/// ``ClientRequest`` objects are created by ``Client``s and work their way through until they are completed.
public class ClientRequest: ObjectIdentity, Equatable {
	/// Equality is based on ``id`` string comparison
	public static func == (lhs: ClientRequest, rhs: ClientRequest) -> Bool {
		return lhs.id == rhs.id
	}
	
	/// The amount of time to process the request in seconds (in addition to any service time)
	public static let requestTime = 0.0001 // seconds
	
	/// The size of the request (usually HTTP) in Megabits.
	public static let requestSize = 0.1 // Mb
	
	static var _counter:Int = 0
	static var nextID: String  {
		_counter += 1
		return "CR-\(_counter)"
	}

	/// Unique string assigned when the request is created.
	/// Prefixed with `CR-` and a sequential number.
	public var id: String = ClientRequest.nextID
	
	/// A name for the request. Not used.
	public var name: String = ""
	/// A description for the request. Not used.
	public var description: String = ""

	/// Definition of the request
	public let configuredWorkflow: ConfiguredWorkflow!
	
	/// The process to solve the request. Assigned by the ``Simulator`` after the request is created.
	public var solution: ClientRequestSolution?
	
	/// The traffic for *this* request, randomly different from other requests
	public var cacheTraffic: Double!
	/// The traffic for *this* request, randomly different from other requests
	public var clientTraffic: Double!
	/// The traffic for *this* request, randomly different from other requests
	public var serverTraffic: Double!
	/// The service times for *this* request, randomly different from other requests
	public var serviceTimes = Dictionary<ComputeRole, Double>()
	
	/// Execution Metrics
	public let metrics = ClientRequestMetrics()
	
	/// Initializer
	/// - Parameter cw: A configured workflow that defines the request.
	public init(configuredWorkflow cw: ConfiguredWorkflow) {
		configuredWorkflow = cw
		name = "\(id): \(cw.name)"
		
		for computeRole in configuredWorkflow.definition.serviceTimes.keys {
			let stdServiceTime = configuredWorkflow.definition.serviceTimes[computeRole]!
			if stdServiceTime > 0.0 {
				serviceTimes[computeRole] = stdServiceTime.randomAdjusted()
			}
		}
		
		let w = configuredWorkflow.definition
		if w.hasCache {
			let traffic = w.clientTraffic.randomAdjusted()
			clientTraffic = traffic * 0.25
			cacheTraffic = traffic * 0.75
		}
		else {
			clientTraffic = w.clientTraffic.randomAdjusted()
			cacheTraffic = 0.0
		}
		serverTraffic = w.serverTraffic.randomAdjusted()
	}
	
	/// Passes the current step from the solution to the compute node or network connection.
	/// - Parameter clock: The current simulation time.
	func startCurrentStep(_ clock: Double) {
		if let step = solution?.currentStep {
			step.calculator.queue.enqueue(self, clock: clock)
		}
	}

	/// Returns `true` if the solution has been completed.
	public var isFinished:Bool {
		// If there is no solution, the request is finished.
		return solution?.isFinished ?? true
	}

}
