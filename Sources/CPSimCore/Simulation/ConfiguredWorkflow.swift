//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-10-05.
//

import Foundation

public class ConfiguredWorkflow: ObjectIdentity {
	public var id:String = UUID().uuidString
	public var name: String
	public var description: String?
	
	public var userCount = 0
	public var productivity = 0.0
	public var tph = 0
	public var dataSource = DataSourceType.DBMS
	
	public var definition: WorkflowDefinition
	public var client: Client
	public var tiers = Dictionary<ComputeRole, Tier>()
	
	private(set) public var nextEventTime: Double?
	
	public init(name: String, definition: WorkflowDefinition, client: Client) {
		self.name = name
		self.definition = definition
		self.client = client
	}
	
	public var tps: Double {
		if tph > 0 {
			// This configured workflow's rate is in TPH
			return Double(self.tph) / 3600
		}
		// Productivity is in displays per minute
		return  Double(userCount) * Double(productivity) / 60.0
	}
	
	@discardableResult
	public func calcNextEventTime(currentClock clock:Double) -> Double? {
		let time = clock + (1.0/tps).randomAdjusted()
		assert(time > 0.0)
		self.nextEventTime = time
		return self.nextEventTime
	}

	public func copy() -> ConfiguredWorkflow {
		let duplicate = ConfiguredWorkflow(name: self.name, definition: self.definition, client: self.client)
		duplicate.description = self.description
		duplicate.userCount = self.userCount
		duplicate.productivity = self.productivity
		duplicate.tph = self.tph
		duplicate.dataSource = self.dataSource
		duplicate.tiers = self.tiers
		return duplicate
	}
}
