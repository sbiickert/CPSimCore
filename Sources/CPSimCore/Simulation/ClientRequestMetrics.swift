//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-28.
//

import Foundation

class ClientRequestMetrics {
	static let NETWORK_KEY = "network"
	private var metrics = Dictionary<String, Metric>()
	
	var keys: Dictionary<String, Metric>.Keys {
		return metrics.keys
	}
	
	var totalServiceTime: Double {
		var total = 0.0
		for (_, metric) in metrics {
			total += metric.serviceTime
		}
		return total
	}
	
	var totalQueueTime: Double {
		var total = 0.0
		for (_, metric) in metrics {
			total += metric.queueTime
		}
		return total
	}
	
	var totalLatencyTime: Double {
		var total = 0.0
		for (_, metric) in metrics {
			total += metric.latency
		}
		return total
	}

	@discardableResult
	func add(serviceTime: Double, to key: String) -> Double {
		if metrics.keys.contains(key) == false {
			metrics[key] = Metric()
		}
		let newValue = metrics[key]!.add(serviceTime: serviceTime)
		return newValue
	}
	
	@discardableResult
	func add(queueTime: Double, to key: String) -> Double {
		if metrics.keys.contains(key) == false {
			metrics[key] = Metric()
		}
		let newValue = metrics[key]!.add(queueTime: queueTime)
		return newValue
	}
	
	@discardableResult
	func addLatency(_ time: Double) -> Double {
		if metrics.keys.contains(ClientRequestMetrics.NETWORK_KEY) == false {
			metrics[ClientRequestMetrics.NETWORK_KEY] = Metric()
		}
		let newValue = metrics[ClientRequestMetrics.NETWORK_KEY]!.add(latency: time)
		return newValue
	}
}

struct Metric {
	private(set) var serviceTime: Double = 0.0
	private(set) var queueTime: Double = 0.0
	private(set) var latency: Double = 0.0
	
	@discardableResult
	mutating func add(serviceTime: Double) -> Double {
		let newValue = self.serviceTime + serviceTime
		self.serviceTime = newValue
		return newValue
	}
	
	@discardableResult
	mutating func add(queueTime: Double) -> Double {
		let newValue = self.queueTime + queueTime
		self.queueTime = newValue
		return newValue
	}
	
	@discardableResult
	mutating func add(latency: Double) -> Double {
		let newValue = self.latency + latency
		self.latency = newValue
		return newValue
	}
}
