//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-28.
//

import Foundation

/// Model object to capture the metrics as a request is processed.
public class ClientRequestMetrics {
	/// Key specific for tracking network transfer times.
	static let NETWORK_KEY = "network"
	
	/// Collection of data defining the performance of the request completion
	private var metrics = Dictionary<String, Metric>()
	
	/// List of the keys in the data collection.
	public var keys: [String] {
		return [String](metrics.keys)
	}
	
	/// Convenience access for summing all service times in seconds.
	public var totalServiceTime: Double {
		var total = 0.0
		for (_, metric) in metrics {
			total += metric.serviceTime
		}
		return total
	}
	
	/// Convenience access for summing all queue times in seconds.
	public var totalQueueTime: Double {
		var total = 0.0
		for (_, metric) in metrics {
			total += metric.queueTime
		}
		return total
	}
	
	/// Convenience access for summing all latency times in seconds.
	public var totalLatencyTime: Double {
		var total = 0.0
		for (_, metric) in metrics {
			total += metric.latency
		}
		return total
	}
	
	/// Convenience access for summing the full response time in seconds.
	public var responseTime: Double {
		return totalLatencyTime + totalServiceTime + totalQueueTime
	}

	@discardableResult
	/// Method to add a data point to the collection for service time (compute/network)
	/// - Parameters:
	///   - serviceTime: The service time in seconds.
	///   - key: The key to record the time against.
	/// - Returns: The new total service time for that key in seconds.
	public func add(serviceTime: Double, to key: String) -> Double {
		assert(serviceTime >= 0.0)
		if metrics.keys.contains(key) == false {
			metrics[key] = Metric()
		}
		let newValue = metrics[key]!.add(serviceTime: serviceTime)
		return newValue
	}
	
	@discardableResult
	/// Method to add a data point to the collection for queue time (compute/network)
	/// - Parameters:
	///   - queueTime: The queue time in seconds.
	///   - key: The key to record the time against.
	/// - Returns: The new total queue time for that key in seconds.
	public func add(queueTime: Double, to key: String) -> Double {
		assert(queueTime >= 0.0)
		if metrics.keys.contains(key) == false {
			metrics[key] = Metric()
		}
		let newValue = metrics[key]!.add(queueTime: queueTime)
		return newValue
	}
	
	@discardableResult
	/// Method to add a data point to the collection for latency time (network).
	/// - Parameter time: Amount of latency time in seconds.
	/// - Returns: The new total latency time in seconds.
	public func addLatency(_ time: Double) -> Double {
		assert(time >= 0.0)
		if metrics.keys.contains(ClientRequestMetrics.NETWORK_KEY) == false {
			metrics[ClientRequestMetrics.NETWORK_KEY] = Metric()
		}
		let newValue = metrics[ClientRequestMetrics.NETWORK_KEY]!.add(latency: time)
		return newValue
	}
}

/// Data point for storing in ``ClientRequestMetrics``
struct Metric {
	/// Add to the service time.
	private(set) var serviceTime: Double = 0.0
	/// The queue time in seconds.
	private(set) var queueTime: Double = 0.0
	/// The latency time in seconds.
	private(set) var latency: Double = 0.0
	
	@discardableResult
	/// Add an amount of service time to the metric
	/// - Parameter serviceTime: Service time in seconds.
	/// - Returns: The new total service time in seconds.
	mutating func add(serviceTime: Double) -> Double {
		let newValue = self.serviceTime + serviceTime
		self.serviceTime = newValue
		return newValue
	}
	
	@discardableResult
	/// Add to the queue time.
	/// - Parameter queueTime: Queue time in seconds.
	/// - Returns: The new total queue time in seconds.
	mutating func add(queueTime: Double) -> Double {
		let newValue = self.queueTime + queueTime
		self.queueTime = newValue
		return newValue
	}
	
	@discardableResult
	/// Add to the latency time.
	/// - Parameter latency: Latency time in seconds.
	/// - Returns: The new total latency time in seconds.
	mutating func add(latency: Double) -> Double {
		let newValue = self.latency + latency
		self.latency = newValue
		return newValue
	}
}
