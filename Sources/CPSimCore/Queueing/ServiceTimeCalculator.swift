//
//  ServiceTimeCalculator.swift
//  CPSim
//
//  Created by Simon Biickert on 2018-08-29.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Foundation

protocol ServiceTimeCalculator {
	var queue: MultiQueue {get}
	func calculateServiceTime(for request:ClientRequest) -> Double;
	func calculateLatency(for request:ClientRequest) -> Double;
}
