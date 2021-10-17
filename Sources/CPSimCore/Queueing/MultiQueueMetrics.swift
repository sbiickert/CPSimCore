//
//  MultiQueueMetrics.swift
//  
//
//  Created by Simon Biickert on 2021-10-15.
//

import Foundation

typealias QueueMetric = (clock: Double, requestCount: Int)

struct MultiQueueMetrics {
	var channelCount: UInt {
		didSet {
			assert(channelCount > 0)
			// If queue is resized, existing utilization values cleared
			_data.removeAll()
		}
	}
	private var _data = [QueueMetric]()
	
	init(channelCount: UInt) {
		self.channelCount = channelCount
	}
	
	var dataTimeWindow: Double? {
		guard _data.count > 0 else {
			return nil
		}
		return _data.last!.clock - _data.first!.clock
	}
	
	var lastClock: Double? {
		return _data.last?.clock
	}
	
	mutating func add(dataPoint: QueueMetric) {
		_data.append(dataPoint)
	}
	
	func utilization(inPrevious time: Double?) -> Double {
		guard _data.count > 0 else {
			return 0.0
		}
		
		// Determine what records are in the time window
		// nil timeWindow -> all data
		let recs = (time == nil) ? _data : _data.filter({$0.clock >= lastClock! - time!})
		
		guard recs.count > 1 else {
			return Double(recs.first!.requestCount) / Double(channelCount)
		}

		// For every time slice, there will be X requests in the queue.
		// Less than all channels full -> X / channelCount (less than 1.0)
		// All channels full -> 100% (1.0)
		// All channels full and some in the queue -> X / channelCount (more than 1.0)
		let timeWindow = dataTimeWindow!
		var utilization = 0.0
		for idx in 1 ..< recs.count {
			let deltaT = _data[idx].clock - _data[idx-1].clock
			let util = Double(_data[idx].requestCount) / Double(channelCount)
			// Increment utilization by the relative amount that this measurement represents
			utilization += util * (deltaT/timeWindow)
		}
		return utilization
	}
}


