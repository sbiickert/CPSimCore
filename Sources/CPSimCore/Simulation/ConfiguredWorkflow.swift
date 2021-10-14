//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-10-05.
//

import Foundation

class ConfiguredWorkflow: ObjectIdentity {
	var id:String = UUID().uuidString
	var name: String
	var description: String?
	
	var userCount = 0
	var productivity = 0.0
	var tph = 0
	var dataSource = DataSourceType.DBMS
	
	var definition: WorkflowDefinition
	var client: Client
	var tiers = Dictionary<ComputeRole, Tier>()
	
	private(set) public var nextEventTime: Double?
	
	init(name: String, definition: WorkflowDefinition, client: Client) {
		self.name = name
		self.definition = definition
		self.client = client
	}
	
	var tps: Double {
		if tph > 0 {
			// This configured workflow's rate is in TPH
			return Double(self.tph) / 3600
		}
		// Productivity is in displays per minute
		return  Double(userCount) * Double(productivity) / 60.0
	}
	
	@discardableResult
	func calcNextEventTime(currentClock clock:Double) -> Double? {
		let time = clock + (1.0/tps).randomAdjusted()
		assert(time > 0.0)
		self.nextEventTime = time
		return self.nextEventTime
	}

	func copy() -> ConfiguredWorkflow {
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
