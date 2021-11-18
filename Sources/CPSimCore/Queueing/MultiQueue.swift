//
//  MultiQueue.swift
//  CPSimCore
//
//  Created by Simon Biickert on 2017-06-21.
//  Copyright © 2017 ii Softwerks. All rights reserved.
//

import Foundation

/// Model object responsible for holding requests as they are being processed.
/// Part of the definition of the ``ComputeNode`` protocol and ``NetworkConnection`` class.
public class MultiQueue {
	/// Delegate (the compute node or network connection) that is responsible for determining how long it will take for a job to finish.
	public var delegate: ServiceTimeCalculator?
	
	/// Used for debugging and tracking service time.
	public var name: String = "Unnnamed"
	
	/// The mode used when tracking time (separating queuing, various compute roles, network.
	public var mode: WaitMode = .queueing

	/// The waiting queue if there are more requests being handled than there are channels to process them.
	private var _mainQueue = [WaitingRequest]()
	
	/// The processing channels. i.e. the processing core or the network conduit.
	/// Determines the maximum number of requests than can be processed concurrently.
	private var _channels = [WaitingRequest?]()
	
	/// Object for tracking the metrics of this queue (time queueing, processing).
	private(set) var metrics: MultiQueueMetrics
	
	/// Initializer
	/// - Parameter channelCount: The number of channels for parallel processing.
	public init(channelCount: UInt) {
		for _ in 0..<channelCount {
			_channels.append(nil)
		}
		metrics = MultiQueueMetrics(channelCount: channelCount)
	}
	
	/// Set this value during simulation to alter the number of channels. The queue will adjust during when finished requests are removed.
	/// If this value is decreased and all channels are full, then the number of channels will reduce as requests are completed.
	public var requestedChannelCount: Int?
	
	/// The total number of processing channels.
	public var channelCount: Int {
		get {
			return _channels.count
		}
	}
	
	/// The number of channels that are not currently processing anything.
	public var availableChannelCount: Int {
		return _channels.filter({$0 == nil}).count
	}
	
	/// The total number of requests either in channels or in the main queue, waiting.
	public var requestCount: Int {
		return _mainQueue.count + _channels.filter({$0 != nil}).count
	}
	
	/// The simulation clock when the next request will be finished processing.
	public var nextEventTime: Double? {
		get {
			return self._channels.compactMap({ $0?.waitEndTime }).sorted().first
		}
	}
	
	/// Method used by the owning object to place a request in the queue.
	/// If any channels are available, the request starts processing immediately.
	/// Otherwise, the request is put into the waiting queue until a channel is available.
	/// - Parameters:
	///   - clientRequest: The request to be processed.
	///   - clock: The current simulation time.
	func enqueue(_ clientRequest: ClientRequest, clock: Double) {
		// Track utilization
		metrics.add(dataPoint: (clock: clock, requestCount: self.requestCount))
		
		var startingImmediately = false
		
		for (index, channel) in _channels.enumerated() {
			if channel == nil {
				// There is no request running in this channel
				//print("\(clientRequest.name) put in channel \(index) of queue \(name)")
				let serviceTime = delegate?.calculateServiceTime(for: clientRequest) ?? 0.0
				let latency = delegate?.calculateLatency(for: clientRequest) ?? 0.0
				_channels[index] = WaitingRequest(with: clientRequest,
												  at: clock,
												  withServiceTime: serviceTime,
												  withLatency: latency,
												  mode: self.mode)
				startingImmediately = true
				//assert(_channels[index]!.waitEndTime! > clock)
				break
			}
		}
		
		if !startingImmediately {
			//print("\(clientRequest.name) queued in queue \(name)")
			_mainQueue.append(WaitingRequest(with: clientRequest,
											 at: clock,
											 withServiceTime: nil,
											 withLatency: nil,
											 mode: .queueing))
		}
	}
	
	/// Method called by the simulation to cull the finished requests
	/// Requests in the waiting queue are put into available channels.
	/// - Parameter clock: The current simulation time.
	/// - Returns: A list of requests that have been removed from channels because they are finished.
	func removeFinishedRequests(_ clock: Double) -> [ClientRequest] {
		// Track utilization
		metrics.add(dataPoint: (clock: clock, requestCount: self.requestCount))
		
		var finishedRequests = [ClientRequest]()

		for (index, requestBeingProcessed) in self._channels.enumerated() {
			if let wr = requestBeingProcessed,
			   let endTime = wr.waitEndTime {
				if clock >= endTime {
					//print("\(requestBeingProcessed!.name) finished in queue \(name)")
					finishedRequests.append(wr.endWait(in: self, at: clock))
					self._channels[index] = nil
				}
			}
		}
		
		// If the user has adjusted the number of channels up or down
		if let rcc = requestedChannelCount
		{
			if rcc != channelCount {
				// Find any empty channels and remove them
				_channels = _channels.filter { $0 != nil }
				// Expand the number of channels up to rcc
				while rcc > channelCount {
					self._channels.append(nil)
				}
			}
			if rcc == channelCount {
				// The number of channels matches the requested number, no more adjusting
				requestedChannelCount = nil
			}
		}
		
		// Transfer any main queue requests to an available core
		while availableChannelCount > 0 && _mainQueue.count > 0 {
			let waitingRequest = _mainQueue.removeFirst()
			for (index, requestBeingProcessed) in _channels.enumerated() {
				if requestBeingProcessed == nil {
					// Nothing active in this channel
					let clientRequest = waitingRequest.endWait(in: self, at: clock)
					let serviceTime = delegate?.calculateServiceTime(for: waitingRequest.request) ?? 0.0
					let latency = delegate?.calculateLatency(for: clientRequest) ?? 0.0
					//print("\(clientRequest.name) put in channel \(index) of queue \(name)")
					_channels[index] = WaitingRequest(with: clientRequest,
													  at: clock,
													  withServiceTime: serviceTime,
													  withLatency: latency,
													  mode: mode)
					break
				}
			}
		}
		
		return finishedRequests
	}
	
	/// Determine if the given request is being handled by this queue.
	/// Includes active processing (channels) and the waiting queue.
	/// - Parameter request: The request to search for.
	/// - Returns: `true` if the request is being handled.
	public func isRequestBeingHandled(_ request: ClientRequest) -> Bool {
		if _mainQueue.contains(where: { $0.request == request} ) {
			return true
		}
		for waitingRequest in _channels {
			if waitingRequest != nil && waitingRequest!.request == request {
				return true
			}
		}
		return false
	}
}

/// Enumeration of the waiting modes for a queue.
/// processing: in a channel
/// transmitting: in a channel (network)
/// queueing: in the waiting queue
public enum WaitMode {
	case processing
	case transmitting
	case queueing
}

/// Wrapper object for client requests that are in a queue.
/// Made more sense to use a wrapper than to add all these capabilities to the request itself.
class WaitingRequest {
	/// The wrapped request.
	let request: ClientRequest
	
	/// The simulation time when the request was wrapped.
	let waitStartTime: Double
	
	/// The expected time that the queue time will end. (i.e. the start time + the service time)
	/// Requests in the waiting queue don't have an end time. Their wait will end when a channel becomes available.
	let waitEndTime: Double?
	
	/// The network latency that will be recorded for a network transfer.
	let latency: Double
	
	/// The mode of the waiting.
	let mode: WaitMode
	
	/// Initializer
	/// - Parameters:
	///   - request: The request to wrap.
	///   - time: The current simulation time.
	///   - serviceTime: The amount of time this request will take to process in seconds.
	///   - latency: The amount of latency time to add to a network transfer.
	///   - mode: The waiting mode. Used to record the time in the request's ``ClientRequestMetrics``.
	public init(with request: ClientRequest,
				at time: Double,
				withServiceTime serviceTime: Double?,
				withLatency latency: Double?,
				mode: WaitMode) {
		self.request = request
		self.waitStartTime = time
		if mode == .queueing {
			self.waitEndTime = nil
		}
		else if serviceTime != nil {
			assert(serviceTime! >= 0.0)
			self.waitEndTime = time + serviceTime! + (latency ?? 0.0)
		}
		else {
			// This should never happen. Only queueing will have an open-ended service time
			self.waitEndTime = nil
		}
		self.latency = latency ?? 0.0
		self.mode = mode
	}
	
	/// Method to unwrap the request and update its ``ClientRequestMetrics``
	/// - Parameters:
	///   - queue: The queue that the request was in.
	///   - time: The current simulation time.
	/// - Returns: The request with updated metrics.
	public func endWait(in queue:MultiQueue, at time: Double) -> ClientRequest {
		let elapsed = time - waitStartTime - latency
		
		let metricKey = request.solution?.currentStep?.computeRole.rawValue ?? ""
		
		switch self.mode {
		case .processing:
			_ = request.metrics.add(serviceTime: elapsed, to: metricKey)
		case .queueing:
			if queue.mode == .transmitting {
				_ = request.metrics.add(queueTime: elapsed, to: ClientRequestMetrics.NETWORK_KEY)
			}
			else {
				_ = request.metrics.add(queueTime: elapsed, to: metricKey)
			}
		case .transmitting:
			_ = request.metrics.add(serviceTime: elapsed, to: ClientRequestMetrics.NETWORK_KEY)
		}
		
		_ = request.metrics.addLatency(latency)
		
		return request
	}
}
