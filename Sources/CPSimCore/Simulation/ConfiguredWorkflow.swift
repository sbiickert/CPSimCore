//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-10-05.
//

import Foundation

/// Model object that represents a number of users / processes emitting requests
/// The frequency of the requests is based on the number of users and their productivity,
/// or the transactions per hour (tph).
public class ConfiguredWorkflow: IdentifiedClass {
	/// The number of virtual users
	public var userCount = 0
	
	/// The productivity (number of transactions per minute) of the users.
	public var productivity = 0.0
	
	/// Alternative to users/productivity: just define the number of transactions per hour.
	public var tph = 0
	
	/// The datasource type of the workflow.
	public var dataSource = DataSourceType.DBMS
	
	/// The workflow that is configured.
	public var definition: WorkflowDefinition
	
	/// The client that is emitting the requests and processing the responses.
	public var client: Client
	
	/// The tiers that will handle the required software roles for the requests.
	public var tiers = Dictionary<ComputeRole, Tier>()
	
	/// The next simulation time when this configured workflow will emit a request.
	private(set) public var nextEventTime: Double?
	
	/// Initializer
	/// - Parameters:
	///   - name: The name of the configured workflow.
	///   - definition: The workflow that defines it.
	///   - client: The client compute node that will be emitting the request.
	public init(name: String, definition: WorkflowDefinition, client: Client) {
		self.definition = definition
		self.client = client
		super.init()
		self.name = name
	}
	
	/// Regardless of the choice of user/prod or tph, this accessor returns the transactions per second.
	public var tps: Double {
		if tph > 0 {
			// This configured workflow's rate is in TPH
			return Double(self.tph) / 3600
		}
		// Productivity is in displays per minute
		return  Double(userCount) * Double(productivity) / 60.0
	}
	
	@discardableResult
	/// Calculates the simulation time when the next request will be emitted.
	/// - Parameter clock: The current simulator time in seconds.
	/// - Returns: The future simulator time in seconds when the request will be sent.
	public func calcNextEventTime(currentClock clock:Double) -> Double? {
		let time = clock + (1.0/tps).randomAdjusted()
		assert(time > 0.0)
		self.nextEventTime = time
		return self.nextEventTime
	}
	
	/// Copies the configured workflow.
	/// - Returns: A new instance of the configured workflow with the same values.
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
