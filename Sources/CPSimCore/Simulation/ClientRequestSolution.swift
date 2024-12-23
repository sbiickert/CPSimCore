//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-10-08.
//

import Foundation

/// The set of steps the request needs to follow in order to be completed.
/// Works as a FIFO queue.
public struct ClientRequestSolution {
	/// Internal storage of the steps, in order.
	private var _steps = [ClientRequestSolutionStep]()
	
	/// The number of remaining steps in the solution.
	public var stepCount: Int {
		return _steps.count
	}
	
	/// Appends a step to the end of the solution.
	/// - Parameter step: The step to add to the solution.
	mutating public func addStep(_ step: ClientRequestSolutionStep) {
		_steps.append(step)
	}
	
	/// Gets *and removes* the first step in the solution. **Destructive**
	/// - Returns: The first step in the solution, now removed.
	mutating public func next() -> ClientRequestSolutionStep? {
		return _steps.removeFirst()
	}
	
	/// The first step in the solution. **Non-destructive**
	public var currentStep: ClientRequestSolutionStep? {
		return _steps.first
	}
	
	/// Returns `true` if there are no more steps.
	public var isFinished: Bool {
		return currentStep == nil
	}
}

/// Struct representing a step in the solution.
public struct ClientRequestSolutionStep {
	/// The compute node or network connection that will be handling the step.
	public let calculator: ServiceTimeCalculator
	/// Is this on the outgoing (request) or incoming (response) leg of the solution.
	public let isResponse: Bool
	/// The compute role in the ``ServiceType/serverRoleChain`` that this step represents.
	public let computeRole: ComputeRole
	/// The data size transferring in this step.
	public let dataSize: Double
}

/// Factory object with one responsibility: to create a solution for a request based on the ``Simulator/design``.
public class ClientRequestSolutionFactory {
	/// Method to create the solution.
	/// - Parameters:
	///   - cr: The request to create a solution for.
	///   - design: The current design.
	/// - Returns: The solution. Will return `nil` if no solution is possible.
	public static func createSolution(for cr:ClientRequest, in design:Design) throws -> ClientRequestSolution? {
		var solution = ClientRequestSolution()
		var computeNodeStack = [ ComputeNode]()

		// REQUEST PHASE ------------------
		// Start with the client

		// Commented out b/c compute for the host will be processed on the return leg
		//solution.addStep(ClientRequestSolutionStep(calculator: cr.configuredWorkflow.client, isResponse: false, computeRole: .client))
		computeNodeStack.append(cr.configuredWorkflow.client)
		
		// Find zone where this request is initiated from
		let clientZone = design.findZone(containing: cr.configuredWorkflow)
		var fromZone = clientZone
		if fromZone == nil {
			print("Could not find network zone containing client \(cr.configuredWorkflow.client.name)")
			return nil
		}
		
		// Get the server role chain from the workflow
		var chain = cr.configuredWorkflow.definition.serviceType.serverRoleChain
		// Some workflows may not have service times for all roles in the chain
		// e.g. a local desktop workflow that does not have a wts service time
		chain = chain.filter({cr.serviceTimes[$0] != nil})
		
		// For each server role in the chain
		for computeRole in chain {
			// Determine the tier supporting that compute role (configured workflow)
			let tier = cr.configuredWorkflow.tiers[computeRole]
			guard tier != nil else {
				print("Could not find tier for compute role \(computeRole)")
				return nil
			}

			// Determine the compute node in that tier to route to
			let optComputeNode = tier!.roundRobinNode
			guard optComputeNode != nil else {
				print("No available compute nodes in tier \(tier!.name)")
				return nil
			}
			let host = optComputeNode as! Host

			// Store the host so we can use it in the reponse phase
			computeNodeStack.append(host)

			// Find the compute node in the network
			let toZone = design.findZone(containing: host)
			guard toZone != nil else {
				print("Could not find network zone containing host \(host.name)")
				return nil
			}
			
			let route = NetworkRouteFinder(fromZone: fromZone!, toZone: toZone!).find()
			guard route != nil else {
				print("Could not find route from \(fromZone!.name) to \(toZone!.name)")
				return nil
			}

			// For each leg of the network route
			for nc in route! {
				// Add a solution step
				solution.addStep(ClientRequestSolutionStep(calculator: nc,
														   isResponse: false,
														   computeRole: computeRole,
														   dataSize: ClientRequest.requestSize))
			}
			
			// Add a solution step for the compute node
			// Portal is only on the request leg. All others on the return leg
			if computeRole == .portal {
				solution.addStep(ClientRequestSolutionStep(calculator: host,
														   isResponse: false,
														   computeRole: computeRole,
														   dataSize: ClientRequest.requestSize))
			}
			
			fromZone = toZone
		}
		
		
		// RESPONSE PHASE ------------------
		
		assert(computeNodeStack.count > 1) // Client plus at least one host
		
		// Start with the far end of the chain of compute nodes
		computeNodeStack.reverse()
		chain.reverse()
		
		let client = computeNodeStack.removeLast() // Client will be used at the end of the chain
		
		let start = computeNodeStack.removeFirst() as! Host
		var computeRole = chain.removeFirst()
		
		// Data size starts at "server" size and steps down to "client" size after rendering
		// Or cache size if this is a cache response
		var hasSteppedDown = false
		func calcDataSize() -> Double {
			if cr.configuredWorkflow.definition.serviceType == .cache {
				return cr.cacheTraffic
			}
			if hasSteppedDown {
				return cr.clientTraffic!
			}
			if computeRole.isRenderer {
				hasSteppedDown = true
				return cr.clientTraffic!
			}
			return cr.serverTraffic!
		}
		var dataSize = calcDataSize()
		
		solution.addStep(ClientRequestSolutionStep(calculator: start,
												   isResponse: true,
												   computeRole: computeRole,
												   dataSize: dataSize))
		fromZone = design.findZone(containing: start) // Don't need to test for nil: we've found these once already
		
		// For each compute node in reversed chain
		for case let host as Host in computeNodeStack {
			// The compute role that is being done at this node
			computeRole = chain.removeFirst()
			
			if computeRole == .portal {
				// Don't send the response back through the Portal
				continue
			}
			
			dataSize = calcDataSize()
			
			// Find network route to compute node
			let toZone = design.findZone(containing: host) // Don't need to test for nil: we've found these once already
			
			let route = NetworkRouteFinder(fromZone: fromZone!, toZone: toZone!).find()
			guard route != nil else {
				print("Could not find reverse route from \(fromZone!.name) to \(toZone!.name)")
				return nil
			}

			// For each leg of the network route
			for nc in route! {
				// Add a solution step
				solution.addStep(ClientRequestSolutionStep(calculator: nc,
														   isResponse: true,
														   computeRole: computeRole,
														   dataSize: dataSize))
			}
		
			// Add a solution step for the compute node
			solution.addStep(ClientRequestSolutionStep(calculator: host,
													   isResponse: true,
													   computeRole: computeRole,
													   dataSize: dataSize))
			
			fromZone = toZone
		}
		
		// Client processing
		computeRole = .client
		dataSize = cr.clientTraffic
		let route = NetworkRouteFinder(fromZone: fromZone!, toZone: clientZone!).find()
		guard route != nil else {
			print("Could not find reverse route from \(fromZone!.name) to \(clientZone!.name)")
			return nil
		}

		// For each leg of the network route to the client
	   for nc in route! {
		   // Add a solution step
		   solution.addStep(ClientRequestSolutionStep(calculator: nc,
													  isResponse: true,
													  computeRole: computeRole,
													  dataSize: dataSize))
	   }
   
	   // Add a solution step for the client
		solution.addStep(ClientRequestSolutionStep(calculator: client,
												   isResponse: true,
												   computeRole: computeRole,
												   dataSize: dataSize))

		return solution
	}
}

/// Utility class to build a network route between network zones.
private class NetworkRouteFinder {
	/// The zone to navigate from.
	let fromZone: NetworkZone
	/// The zone to navigate to.
	let toZone: NetworkZone
	
	private var breadcrumbs = NetworkRoute()
	private var followedConnections = Dictionary<String, NetworkConnection>() // Should never follow the same connection twice
	private var exploredZones = Dictionary<String, NetworkZone>() // Should never explore the same zone twice
	private var routes = [NetworkRoute]()
	
	init(fromZone fz: NetworkZone, toZone tz: NetworkZone) {
		fromZone = fz
		toZone = tz
	}
	
	/// Returns `true` if the from zone and to zone are the same.
	var isLocalRoute: Bool {
		return self.fromZone.id == self.toZone.id
	}
	
	/// Method to find the network route.
	/// - Returns: List of network connections to traverse in order to route through the network.
	func find() -> [NetworkConnection]? {
		if isLocalRoute {
			return [fromZone.localConnection!]
		}
		rFind(currentZone: fromZone)
		guard routes.count > 0 else {
			print("No route found from zone \(fromZone.name) to zone \(toZone.name)")
			return nil
		}
		let route = bestRoute
		guard route != nil else {
			print("Could not determine which of the routes was best")
			return nil
		}
		return networkConnections(for: route!)
	}
	
	/// Recursive worker function to find the route.
	/// - Parameter currentZone: The current zone when tracing through the network.
	private func rFind(currentZone: NetworkZone) {
		// Add currentZone to the explored zones so that routes don't double back.
		exploredZones[currentZone.id] = currentZone
		for connection in currentZone.connections {
			followedConnections[connection.id] = connection
			breadcrumbs.append(id: connection.id)
			if connection.destination.id == self.toZone.id {
				//print("found toZone at the end of \(connection.name)")
				routes.append(breadcrumbs) // Should pass by value
				breadcrumbs.pop()
				return // Found a route
			}
			else if exploredZones.keys.contains(connection.destination.id) == false
			{
				// Follow this connection and see if it makes a route
				rFind(currentZone: connection.destination)
			}
			else {
				breadcrumbs.pop()
			}
		}
		breadcrumbs.pop()
	}
	
	/// If the network tracing finds more than one route, this accessor will return the best.
	private var bestRoute: NetworkRoute? {
		if routes.count == 0 {
			return nil
		}
		
		var bestBW:UInt = 0 // Higher bandwidth is better
		var bestHops = Int.max // Fewer hops is better
		var bestRouteIndex = 0
		
		for (index, route) in routes.enumerated() {
			let hops = route.hopCount
			let bw = minBandwidth(for: route)
			
			if bw > bestBW {
				bestBW = bw
				bestHops = hops
				bestRouteIndex = index
			}
			else if bw == bestBW && hops < bestHops {
				bestHops = hops
				bestRouteIndex = index
			}
		}
		
		return routes[bestRouteIndex]
	}
	
	private func minBandwidth(for route:NetworkRoute) -> UInt {
		var minBW:UInt = 1000000 // Ridiculously high
		for id in route.connectionIds {
			if let connection = followedConnections[id] {
				if connection.bandwidth < minBW {
					minBW = connection.bandwidth
				}
			}
		}
		return minBW
	}

	private func networkConnections(for route:NetworkRoute) -> [NetworkConnection] {
		var connections = [NetworkConnection]()
		
		for id in route.connectionIds {
			if let connection = followedConnections[id] {
				connections.append(connection)
			}
		}
		
		return connections
	}
}

private struct NetworkRoute {
	var connectionIds: [String]

	init() {
		connectionIds = [String]()
	}
	
	var hopCount: Int {
		return connectionIds.count
	}
	
	mutating func append(id: String) {
		connectionIds.append(id)
	}
	
	@discardableResult
	mutating func pop() -> String? {
		return connectionIds.popLast()
	}
}
