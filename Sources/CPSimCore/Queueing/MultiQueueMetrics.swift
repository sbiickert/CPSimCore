//
//  MultiQueueMetrics.swift
//  
//
//  Created by Simon Biickert on 2021-10-15.
//

import Foundation

/// Useful alias for a tuple of a clock time in seconds and the number of requests currently being handled by the ``MultiQueue``.
public typealias QueueMetric = (clock: Double, requestCount: Int)

/// Structure for tracking the performance of a ``MultiQueue`` and calculating utilization.
public struct MultiQueueMetrics {
	/// The number of channels in the ``MultiQueue``. If the queue is resized, the metrics are reset.
	public var channelCount: UInt {
		didSet {
			assert(channelCount > 0)
			// If queue is resized, existing utilization values cleared
			_data.removeAll()
		}
	}
	
	/// Structure for holding the metrics data.
	private var _data = [QueueMetric]()
	
	/// Initializer
	/// - Parameter channelCount: The number of channels in the owning ``MultiQueue``.
	public init(channelCount: UInt) {
		self.channelCount = channelCount
	}
	
	/// The amount of simulation time in seconds that the data has been collected for.
	public var dataTimeWindow: Double? {
		guard _data.count > 0 else {
			return nil
		}
		return _data.last!.clock - _data.first!.clock
	}
	
	/// The simulation clock time of the most recent recorded metric.
	public var lastClock: Double? {
		return _data.last?.clock
	}
	
	/// Method for adding a new data point.
	mutating public func add(dataPoint: QueueMetric) {
		_data.append(dataPoint)
	}
	
	/// Calculates the utilization as a percentage (1.0 is 100%)
	/// - Less than all channels full -> X / channelCount (less than 1.0)
	/// - All channels full -> 100% (1.0)
	/// - All channels full and some in the queue -> X / channelCount (more than 1.0)
	/// - Parameter time: If set, only calculate for the most recent `time` seconds. Otherwise, the entire available set of data.
	/// - Returns: The utilization of the ``MultiQueue`` as a percentage (1.0 is 100%)
	public func utilization(inPrevious time: Double?) -> Double {
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


