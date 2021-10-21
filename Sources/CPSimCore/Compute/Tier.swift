//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

public class Tier: ObjectIdentity {
	public var id: String = UUID().uuidString
	public var name: String = ""
	public var description: String?
	
	public var nodes = [ComputeNode]()
	public var roles = Set<ComputeRole>()
	
	public var nextEventTime: Double? {
		let times = nodes.compactMap({$0.queue.nextEventTime}).sorted()
		return times.first
	}
	
	public var coreCount: UInt {
		return nodes.compactMap({$0.hardware?.coreCount}).reduce(0, +)
	}
	
	private var _roundRobinIndex = 0
	public var roundRobinNode: ComputeNode? {
		guard nodes.isEmpty == false else { return nil }
		_roundRobinIndex += 1
		if _roundRobinIndex >= nodes.count {
			_roundRobinIndex = 0
		}
		return nodes[_roundRobinIndex]
	}
	
	public var isHA: Bool {
		get {
			//TODO: If utilization is low enough that a node could be dropped
			return false
		}
	}
}
