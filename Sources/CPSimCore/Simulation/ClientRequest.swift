//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-28.
//

import Foundation

public class ClientRequest: ObjectIdentity, Equatable {
	public static func == (lhs: ClientRequest, rhs: ClientRequest) -> Bool {
		return lhs.id == rhs.id
	}
	static let requestTime = 0.0001 // seconds
	static let requestSize = 0.1 // Mb
	static var _counter:Int = 0
	static var nextID: String  {
		_counter += 1
		return "CR-\(_counter)"
	}

	public var id: String = ClientRequest.nextID
	public var name: String = ""
	public var description: String?

	// Definition of the request
	let configuredWorkflow: ConfiguredWorkflow!
	
	// The means to solve the request
	var solution: ClientRequestSolution?
	
	// The traffic and service times for *this* request, randomly different from other requests
	var cacheTraffic: Double!
	var clientTraffic: Double!
	var serverTraffic: Double!
	var serviceTimes = Dictionary<ComputeRole, Double>()
	
	// Execution Metrics
	let metrics = ClientRequestMetrics()

	init(configuredWorkflow cw: ConfiguredWorkflow) {
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
	
	func startCurrentStep(_ clock: Double) {
		if let step = solution?.currentStep {
			step.calculator.queue.enqueue(self, clock: clock)
		}
	}

	var isFinished:Bool {
		// If there is no solution, the request is finished.
		return solution?.isFinished ?? true
	}

}
