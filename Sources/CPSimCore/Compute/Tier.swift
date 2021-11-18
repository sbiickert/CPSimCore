//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// A group of ``ComputeNode``s that shares a set of ``ComputeRole``s
/// The tier will assist the simulator in identifying which node to send a request to.
public class Tier: ObjectIdentity {
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the tier (expected to be unique)
	public var name: String = ""
	/// A friendly description of the tier
	public var description: String?
	
	/// The collection of nodes that make up this tier
	public var nodes = [ComputeNode]()
	/// The compute roles that are assigned to the nodes in this tier
	public var roles = Set<ComputeRole>()
	
	/// The simulation clock when the next event will happen.
	/// i.e. The next time computing finishes on a currently-processing request in this tier.
	public var nextEventTime: Double? {
		let times = nodes.compactMap({$0.queue.nextEventTime}).sorted()
		return times.first
	}
	
	/// The total number of computing cores in all nodes in this tier.
	public var coreCount: UInt {
		return nodes.compactMap({$0.hardware?.coreCount}).reduce(0, +)
	}
	
	private var _roundRobinIndex = 0
	/// The compute node that is next in line for receiving a request.
	public var roundRobinNode: ComputeNode? {
		guard nodes.isEmpty == false else { return nil }
		_roundRobinIndex += 1
		if _roundRobinIndex >= nodes.count {
			_roundRobinIndex = 0
		}
		return nodes[_roundRobinIndex]
	}
	
	/// An evaluation of whether there is enough spare capacity in the tier that a node could drop without affecting the overal system.
	/// Not implemented at the moment. Always returns `false`.
	public var isHA: Bool {
		get {
			//TODO: If utilization is low enough that a node could be dropped
			return false
		}
	}
}
