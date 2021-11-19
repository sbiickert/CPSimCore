//
//  Simulator.swift
//  
//
//  Created by Simon Biickert on 2021-10-13.
//

import Foundation

/// The top-level object for simulating the system. The simulator has a design and runs workflows through it.
public class Simulator {
	/// Multiplies the clock run speed to slow or speed up simulation
	/// - minimum allowed value: 0.1 (10% speed)
	/// - maximum allowed value: 10.0 (1000% speed)
	public var clockScale: Double = 1.0 {
		didSet {
			if clockScale < 0.1 {
				clockScale = 0.1
			}
			if clockScale > 10.0 {
				clockScale = 10.0
			}
		}
	}
	
	/// The simulation time in seconds.
	private(set) var clock: Double = 0.0
	/// ``start()`` and ``stop()``  will set this.
	private(set) var isRunning:Bool = false
	
	/// The list of requests that are currently being processed in the simulator.
	public var active = [ClientRequest]()
	/// The list of requests that have completed.
	public var handled = [ClientRequest]()
	
	/// The design that is loaded in the simulator for running.
	public var design: Design? {
		didSet {
			reset()
		}
	}
	
	/// Method to start the simulation running.
	public func start() {
		guard design != nil && design!.isValid else {
			print("Could not start simulator. No valid design.")
			return
		}
		// Calculate the first time every workflow happens
		for cw in design!.configuredWorkflows {
			cw.calcNextEventTime(currentClock: clock)
		}
		
		print("Starting simulator with clock \(clock)")
		isRunning = true
	}
	
	/// Method to stop the simulator. Will reset, ready for a new clean run.
	public func stop() {
		self.isRunning = false
		self.reset()
	}
	
	/// Will stop the simulation without a reset.
	public func pause() {
		self.isRunning = false
	}
	
	/// Returns the simulator back to an initial state.
	private func reset() {
		self.clock = 0.0
		active.removeAll()
		handled.removeAll()
	}
	
	/// Moves the simulation time forward by a number of seconds.
	/// - Parameter seconds: Number of seconds to advance the simulation time.
	public func advanceTime(by seconds: Double) {
		assert(seconds > 0.0, "Call to advanceTime:by: with zero or negative delta time.")
		
		// Clock scale speeds or slows the simulation advance
		let advance = seconds * clockScale
		let time = clock + advance
		//print("Advancing time from \(clock) by \(advance) to \(time)")
		_advanceTime(to: time)
	}
	
	/// Moves the simulation time to a new value.
	/// Processes all new, active and finished requests.
	/// - Parameter toClock: The new simulation time.
	private func _advanceTime(to toClock: Double) {
		guard design != nil else {
			return
		}
		
		while self.isRunning {
			if let nextTime = self.nextEventTime {
				//print("Next event time is \(nextTime)")
				
				// If the next event will happen after the specified clock, then nothing to do
				// This includes all configured workflows (new requests) and existing requests being processed.
				if nextTime > toClock {
					//print("Nothing more to do this time advance")
					break
				}
				
				// Advance simulation to nextTime (where nextTime <= externalClock)
				//print("Time is advanced to \(toClock)")
				self.clock = nextTime
				
				// New requests
				for cw in design!.configuredWorkflows {
					if let nextEventTimeForCW = cw.nextEventTime,
					   nextEventTimeForCW <= self.clock {
						do {
							let request = ClientRequest(configuredWorkflow: cw)
							let solution = try ClientRequestSolutionFactory.createSolution(for: request, in: design!)
							request.solution = solution
							request.startCurrentStep(self.clock)
							self.active.append(request)
							
							if request.configuredWorkflow.definition.hasCache {
								let cacheCW = cw.copy()
								cacheCW.definition.serviceType = .cache
								let cacheReq = ClientRequest(configuredWorkflow: cacheCW)
								cacheReq.name += " $$"
								cacheReq.solution = try ClientRequestSolutionFactory.createSolution(for: cacheReq, in: design!)
								cacheReq.startCurrentStep(self.clock)
								self.active.append(cacheReq)
							}
						}
						catch let error {
							print(error)
						}
						// Reset the configured workflow for the next request
						cw.calcNextEventTime(currentClock: self.clock)
					}
				}
				
				// Active Requests
				for request in self.active {
					if let step = request.solution?.currentStep {
						let finishedRequestsAtThisCalculator = step.calculator.queue.removeFinishedRequests(self.clock)
						for finishedRequest in finishedRequestsAtThisCalculator {
							if let _ = finishedRequest.solution?.next() {
								finishedRequest.startCurrentStep(self.clock)
							}
						}
					}
				}
				
				// Remove all requests with no more steps
				for request in self.active {
					if request.solution?.currentStep == nil {
						// This request is done
						moveRequestToHandled(request: request)
					}
				}
			} // We have a next event time that is less than the new clock
		} // while isRunning
		
		self.clock = toClock
	}
	
	/// Takes a finished request out of the simulator and puts them into the handled list.
	/// - Parameter request: The finished request.
	private func moveRequestToHandled(request: ClientRequest) {
//		if request.name.contains("$$") == false {
//			print("\(request.name) FINISHED [\(request.metrics.responseTime)]")
//		}

		if let idx = active.firstIndex(where: {$0.id == request.id}) {
			active.remove(at: idx)
			handled.append(request)
		}
	}
	
	/// Determines the next time that an event will happen in the simulator.
	/// - a new request started in a configured workflow
	/// - a queueing (compute, network) will be ended
	public var nextEventTime: Double? {
		var nextTime:Double?
		guard design != nil else {
			return nil
		}
		
		for cw in design!.configuredWorkflows {
			if let t = cw.nextEventTime {
				nextTime = (nextTime == nil) ? t : Double.minimum(nextTime!, t)
			}
		}
		
		for request in active {
			if let calculator = request.solution?.currentStep?.calculator,
			   let t = calculator.queue.nextEventTime {
				nextTime = (nextTime == nil) ? t : Double.minimum(nextTime!, t)
			}
		}
		
		return nextTime
	}
}
