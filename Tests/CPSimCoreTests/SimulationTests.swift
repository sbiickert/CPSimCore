import XCTest
@testable import CPSimCore

final class SimulationTests: XCTestCase {
	
	static var exampleClientRequest: ClientRequest? {
		get {
			do {
				let hwLib = try HardwareLibrary.defaultHardware()
				let hw = hwLib.findHardware("Intel Core i7-4770 4 core (1 chip) 3400 MHz")
				let client = Client(hw!)
				let wfLib = try WorkflowLibrary.defaultWorkflows()
				let w = wfLib.findWorkflow("AGS101 REST 2D V Med 100%Dyn 13x7 PNG24")!
				let cw = ConfiguredWorkflow(name: "test", definition: w, client: client)
				return ClientRequest(configuredWorkflow: cw)
			}
			catch {
				return nil
			}
		}
	}
	
	func testWorkflowLibraryLoad() throws {
		var wLib = try WorkflowLibrary.defaultWorkflows()
		XCTAssert(wLib.count > 0)
		XCTAssert(wLib.findWorkflow("AGD wkstn ArcMap 2D V Lite 100%Dyn 19x10 Feature") != nil)
		
		wLib.aliases["bob"] = "AGS REST 2D V Med 100%Dyn 13x7 PNG24"
		
		let bob = wLib.findWorkflow("bob")
		XCTAssert(bob != nil)
		XCTAssert(bob!.clientServiceTime > 0)
	}
	
	func testDesignLoad() throws {
		let design = try Design(at: "/Users/sjb/Code/Capacity Planning/CPSimCore/Config/design_00_v0.3.json")
		XCTAssert(design.name == "Design 00 (Simple)")
		XCTAssert(design.zones.count == 3)
		
		let internet = design.findZone(named: "Internet")
		XCTAssert(internet != nil)
		XCTAssert(internet!.hosts.count == 0)
		
		let lan = design.findZone(named: "LAN")
		XCTAssert(lan != nil)
		XCTAssert(lan!.hosts.count == 3)
		XCTAssert(lan!.hosts.filter({$0 is PhysicalHost}).count == 1)
		XCTAssert(lan!.hosts.filter({$0 is VirtualHost}).count == 2)
		
		let agol = design.findZone(named: "ArcGIS Online")
		XCTAssert(agol != nil)
		XCTAssert(agol!.hosts.count == 1)
		XCTAssert(agol!.hosts[0].name == "AGOL AMI")
		
		XCTAssert(design.tiers.count == 3)
		let dbTier = design.tiers.first(where: {$0.name == "DBMS"})
		XCTAssert(dbTier != nil)
		XCTAssert(design.defaultTiers[.dbms] === dbTier)
		let gisTier = design.tiers.first(where: {$0.name == "Web GIS"})
		XCTAssert(gisTier != nil)
		XCTAssert(gisTier!.nodes.count == 1)
		XCTAssert(gisTier!.roles.count == 4)
		XCTAssert(gisTier!.roles.contains(.gis))
		
		XCTAssert(design.configuredWorkflows.count == 2)
		let localView = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(localView != nil)
		XCTAssert(localView!.tps == 20000.0 / 60.0 / 60.0)
		XCTAssert(localView!.tiers[.dbms] === dbTier)
		XCTAssert(localView!.tiers[.gis] === gisTier)
		XCTAssert(localView!.tiers[.geoevent] == nil)
		XCTAssert(localView!.definition.serviceTimes[.gis]! > 0)
		
		let localViewZone = design.findZone(containing: localView!)
		XCTAssert(localViewZone != nil)
	}
	
	func testSingleMapRequest() throws {
		let design = try Design(at: "/Users/sjb/Code/Capacity Planning/CPSimCore/Config/design_00_v0.3.json")
		
		var clock = 0.0
		let cw = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(cw != nil)
		let req = ClientRequest(configuredWorkflow: cw!)
		print(req.configuredWorkflow.definition.serviceType.serverRoleChain)
		req.solution = try ClientRequestSolutionFactory.createSolution(for: req, in: design)
		XCTAssert(req.solution != nil)
		
		while req.isFinished == false {
			if let currentStep = req.solution?.currentStep {
				req.startCurrentStep(clock)
				let nextTime = currentStep.calculator.queue.nextEventTime
				XCTAssert(nextTime != nil)
				XCTAssert(nextTime! > clock)
				clock = nextTime!
				let finished = currentStep.calculator.queue.removeFinishedRequests(clock)
				XCTAssert(finished.count == 1)
				_ = req.solution?.next()
			}
		}
		
		XCTAssert(req.metrics.totalServiceTime > 0.0)
		XCTAssert(req.metrics.totalQueueTime == 0.0) // No queueing b/c this is the only request
		XCTAssert(req.metrics.totalLatencyTime > 0.0)
		print("Response time for request \(req.name) was \(req.metrics.responseTime) s")
	}
	
	func testSingleMapRequestWithCache() throws {
		let design = try Design(at: "/Users/sjb/Code/Capacity Planning/CPSimCore/Config/design_00_v0.3.json")
		
		var clock = 0.0
		let cw = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(cw != nil)
		let req = ClientRequest(configuredWorkflow: cw!)
		print(req.configuredWorkflow.definition.serviceType.serverRoleChain)
		req.solution = try ClientRequestSolutionFactory.createSolution(for: req, in: design)
		XCTAssert(req.solution != nil)
		
		var reqs = [req]
		
		if req.configuredWorkflow.definition.hasCache {
			let cacheReq = ClientRequest(configuredWorkflow: cw!)
			cacheReq.configuredWorkflow.definition.serviceType = .cache
			cacheReq.solution = try ClientRequestSolutionFactory.createSolution(for: cacheReq, in: design)
			XCTAssert(req.solution != nil)
			reqs.append(cacheReq)
		}

		// Kick off requests
		for r in reqs {
			r.startCurrentStep(clock)
		}
		
		while reqs.filter({$0.isFinished == false}).count > 0 {
			//print("clock: \(clock)")
			var nextClock = Double.greatestFiniteMagnitude
			for r in reqs {
				// Find the lowest next event time
				if let currentStep = r.solution?.currentStep,
				   let nextTimeForReq = currentStep.calculator.queue.nextEventTime
				{
					nextClock = Double.minimum(nextTimeForReq, nextClock)
				}
			}
			
			assert(nextClock > clock)
			clock = nextClock

			for r in reqs {
				if let currentStep = r.solution?.currentStep,
				   let nextTimeForReq = currentStep.calculator.queue.nextEventTime
				{
					if nextTimeForReq <= clock {
						let finished = currentStep.calculator.queue.removeFinishedRequests(clock)
						XCTAssert(finished.count == 1)
						_ = r.solution?.next()
						r.startCurrentStep(clock)
					}
				}
			}
		}
		
		XCTAssert(req.metrics.totalServiceTime > 0.0)
		XCTAssert(req.metrics.totalQueueTime == 0.0) 		// No queueing b/c this is the first request
		XCTAssert(reqs[1].metrics.totalQueueTime >= 0.0) 	// Queueing b/c this is the second request and had to wait behind first for a bit
		XCTAssert(req.metrics.totalLatencyTime > 0.0)
		for r in reqs {
			print("\(r.name) ST: \(r.metrics.totalServiceTime.roundTo(places: 3)) QT: \(r.metrics.totalQueueTime.roundTo(places: 6))")
		}
	}
}
