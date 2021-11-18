//
//  ServiceTimeCalculator.swift
//  CPSim
//
//  Created by Simon Biickert on 2018-08-29.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Foundation

/// Protocol adopted by all model objects that receive a request and then have to process it.
/// Includes ``ComputeNode`` objects and ``NetworkConnection`` objects
public protocol ServiceTimeCalculator {
	/// The foundation for compute and network processing
	var queue: MultiQueue {get}
	
	/// Method to get the amount of time it will take to process the request.
	/// - Parameter request: The request that will be processed.
	/// - Returns: The processing time in seconds.
	func calculateServiceTime(for request:ClientRequest) -> Double;
	
	/// Method to get the amount of network latency for the request
	///
	/// - Parameter request: the request to calculate latency for.
	/// - Returns: The calculated network latency in seconds.
	func calculateLatency(for request:ClientRequest) -> Double;
}
