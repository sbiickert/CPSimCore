//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-28.
//

import Foundation

class ClientRequest: ObjectIdentity, Equatable {
	static func == (lhs: ClientRequest, rhs: ClientRequest) -> Bool {
		return lhs.id == rhs.id
	}
	static let requestTime = 0.0001 // seconds
	static let requestSize = 0.1 // Mb
	static var _counter:Int = 0
	static var nextID: String  {
		_counter += 1
		return "CR-\(_counter)"
	}

	var id: String = ClientRequest.nextID
	var name: String = ""
	var description: String?

	// Definition of the request
	let configuredWorkflow: ConfiguredWorkflow!
	
	// The means to solve the request
	var solution: ClientRequestSolution?
	
	// The traffic and service times for *this* request, randomly different from other requests
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
		clientTraffic = w.clientTraffic.randomAdjusted()
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
