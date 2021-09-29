//
//  MulticoreQueue.swift
//  CPSimCore
//
//  Created by Simon Biickert on 2017-06-21.
//  Copyright © 2017 ii Softwerks. All rights reserved.
//

import Foundation

class MultiQueue {
	var delegate: ServiceTimeCalculator?
	
	var name: String = "Unnnamed"
	var mode: WaitMode = .queueing
	var metricsKey: String = ""

	private var _mainQueue = [WaitingRequest]()
	private var _channels = [WaitingRequest?]()
	
	init(channelCount: UInt) {
		for _ in 0..<channelCount {
			_channels.append(nil)
		}
	}

	var requestedChannelCount: Int?
	var channelCount: Int {
		get {
			return _channels.count
		}
	}
	var availableChannelCount: Int {
		return _channels.filter({$0 == nil}).count
	}
	var requestCount: Int {
		return _mainQueue.count + _channels.filter({$0 != nil}).count
	}
	

	var nextEventTime: Double? {
		get {
			return self._channels.compactMap({ $0?.waitEndTime }).sorted().first
		}
	}
	
	func enqueue(_ clientRequest: ClientRequest, clock: Double) {
		var startingImmediately = false
		
		for (index, channel) in _channels.enumerated() {
			if channel == nil {
				// There is no request running in this channel
				//print("\(clientRequest.name) put in channel \(index) of queue \(name)")
				let serviceTime = delegate?.calculateServiceTime(for: clientRequest) ?? 0.0
				_channels[index] = WaitingRequest(with: clientRequest,
												  at: clock,
												  until: clock + serviceTime,
												  mode: self.mode)
				startingImmediately = true
				break
			}
		}
		
		if !startingImmediately {
			//print("\(clientRequest.name) queued in queue \(name)")
			_mainQueue.append(WaitingRequest(with: clientRequest,
											 at: clock,
											 until: nil,
											 mode: .queueing))
		}
	}
	
	func removeFinishedRequests(_ clock: Double) -> [ClientRequest] {
		var finishedRequests = [ClientRequest]()

		for (index, requestBeingProcessed) in self._channels.enumerated() {
			if let wr = requestBeingProcessed,
			   let endTime = wr.waitEndTime {
				if clock >= endTime {
					//print("\(requestBeingProcessed!.name) finished in queue \(name)")
					finishedRequests.append(wr.endWait(metricKey: metricsKey, at: clock))
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
					let clientRequest = waitingRequest.endWait(metricKey: metricsKey, at: clock)
					let serviceTime = delegate?.calculateServiceTime(for: waitingRequest.request) ?? 0.0
					//print("\(clientRequest.name) put in channel \(index) of queue \(name)")
					_channels[index] = WaitingRequest(with: clientRequest,
													  at: clock,
													  until: clock + serviceTime,
													  mode: mode)
					break
				}
			}
		}
		
		return finishedRequests
	}
	
	func isRequestBeingHandled(_ request: ClientRequest) -> Bool {
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

enum WaitMode {
	case processing
	case transmitting
	case queueing
}

class WaitingRequest {
	let request: ClientRequest
	let waitStartTime: Double
	let waitEndTime: Double?
	let mode: WaitMode
	
	public init(with request: ClientRequest,
				at time: Double, until: Double?,
				mode: WaitMode) {
		self.request = request
		self.waitStartTime = time
		self.waitEndTime = until
		self.mode = mode
	}
	
	public func endWait(metricKey: String, at time: Double) -> ClientRequest {
		let elapsed = time - waitStartTime
		
		switch self.mode {
		case .processing:
			_ = request.metrics.add(serviceTime: elapsed, to: metricKey)
		case .queueing:
			_ = request.metrics.add(queueTime: elapsed, to: metricKey)
		case .transmitting:
			_ = request.metrics.add(serviceTime: elapsed, to: ClientRequestMetrics.NETWORK_KEY)
		}
		
		return request
	}
}
