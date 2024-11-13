import XCTest
@testable import CPSimCore

final class SimulationTests: XCTestCase {
	private static var hwLib = HardwareLibrary()
	private static var wfLib = WorkflowLibrary()

	override func setUp() async throws {
		try await HardwareLibrary.loadDefaultHardware()
		SimulationTests.hwLib = HardwareLibrary.defaultLibrary
		try await WorkflowLibrary.loadDefaultWorkflows()
		SimulationTests.wfLib = WorkflowLibrary.defaultLibrary
	}
	
	private enum TestDesign: String {
		case simple = "~/Developer/Capacity Planning/CPSimCore/Config/design_00_v0.3.json"
		case waDMZ = "~/Developer/Capacity Planning/CPSimCore/Config/design_01_v0.3.json"
		case ha = "~/Developer/Capacity Planning/CPSimCore/Config/design_02_v0.3.json"
		
		var designData: NSDictionary? {
			let expanded = NSString(string: self.rawValue).expandingTildeInPath
			let url = URL(fileURLWithPath: expanded)
			if let jsonData = try? Data(contentsOf: url),
			   let designData = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
			{
				return designData
			}
			return nil
		}
	}
	
	static func exampleClientRequest(hwLib: HardwareLibrary, wfLib: WorkflowLibrary) -> ClientRequest? {
		if let hw = hwLib.findHardware("Intel Core i7-4770 4 core (1 chip) 3400 MHz"),
		   let w = wfLib.findWorkflow("AGS101 REST 2D V Med 100%Dyn 13x7 PNG24") {
			let client = Client(hw)
			let cw = ConfiguredWorkflow(name: "test", definition: w, client: client)
			return ClientRequest(configuredWorkflow: cw)
		}
		return nil
	}
	
	func testWorkflowLibraryLoad() throws {
		XCTAssert(SimulationTests.wfLib.count > 0)
		XCTAssert(SimulationTests.wfLib.findWorkflow("AGD wkstn ArcMap 2D V Lite 100%Dyn 19x10 Feature") != nil)
		
		SimulationTests.wfLib.aliases["bob"] = "AGS REST 2D V Med 100%Dyn 13x7 PNG24"
		
		let bob = SimulationTests.wfLib.findWorkflow("bob")
		XCTAssert(bob != nil)
		XCTAssert(bob!.clientServiceTime > 0)
	}
	
	func testEmptyDesign() throws {
		let design = Design()
		XCTAssert(design.isValid == false)
	}
	
	func testDesignLoad() throws {
		let design = try Design(from: TestDesign.simple.designData!)
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
		//XCTAssert(localView!.tps == 20000.0 / 60.0 / 60.0)
		XCTAssert(localView!.tiers[.dbms] === dbTier)
		XCTAssert(localView!.tiers[.gis] === gisTier)
		XCTAssert(localView!.tiers[.geoevent] == nil)
		XCTAssert(localView!.definition.serviceTimes[.gis]! > 0)
		
		let localViewZone = design.findZone(containing: localView!)
		XCTAssert(localViewZone != nil)
		
		XCTAssert(design.summary.clients["Client PC"] == 2)
	}
	
	func testDesignSave() throws {
		let design1 = try Design(from: TestDesign.simple.designData!)
		let dict = design1.toDictionary()
		
		XCTAssert(dict["name"] != nil)
		XCTAssert((dict["name"] as! String ) == "Design 00 (Simple)")
		
		let design2 = try Design(from: dict)
		
		XCTAssert(design1.configuredWorkflows.count == design2.configuredWorkflows.count)
		XCTAssert(design1.zones.count == design2.zones.count)
		XCTAssert(design1.tiers.count == design2.tiers.count)
	}
	
	func testWADMZDesignLoad() throws {
		let design = try Design(from: TestDesign.waDMZ.designData!)
		XCTAssert(design.name == "Design 01 (WA to DMZ)")
		XCTAssert(design.zones.count == 4)
		
		let internet = design.findZone(named: "Internet")
		XCTAssert(internet != nil)
		XCTAssert(internet!.hosts.count == 0)
		
		let lan = design.findZone(named: "LAN")
		XCTAssert(lan != nil)
		XCTAssert(lan!.hosts.count == 3)
		XCTAssert(lan!.hosts.filter({$0 is PhysicalHost}).count == 1)
		XCTAssert(lan!.hosts.filter({$0 is VirtualHost}).count == 2)
		
		let dmz = design.findZone(named: "DMZ")
		XCTAssert(dmz != nil)
		XCTAssert(dmz!.hosts.count == 2)
		XCTAssert(dmz!.hosts.filter({$0 is PhysicalHost}).count == 1)
		XCTAssert(dmz!.hosts.filter({$0 is VirtualHost}).count == 1)

		let agol = design.findZone(named: "ArcGIS Online")
		XCTAssert(agol != nil)
		XCTAssert(agol!.hosts.count == 1)
		XCTAssert(agol!.hosts[0].name == "AGOL AMI")
		
		XCTAssert(design.tiers.count == 4)
		let dbTier = design.tiers.first(where: {$0.name == "DBMS"})
		XCTAssert(dbTier != nil)
		XCTAssert(design.defaultTiers[.dbms] === dbTier)
		let gisTier = design.tiers.first(where: {$0.name == "Web GIS"})
		XCTAssert(gisTier != nil)
		XCTAssert(gisTier!.nodes.count == 1)
		XCTAssert(gisTier!.roles.count == 3)
		XCTAssert(gisTier!.roles.contains(.gis))
		let webTier = design.tiers.first(where: {$0.name == "Web"})
		XCTAssert(webTier != nil)
		XCTAssert(webTier!.nodes.count == 1)
		XCTAssert(webTier!.roles.count == 1)
		XCTAssert(webTier!.roles.contains(.web))

		XCTAssert(design.configuredWorkflows.count == 2)
		let localView = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(localView != nil)
		//XCTAssert(localView!.tps == 20000.0 / 60.0 / 60.0)
		XCTAssert(localView!.tiers[.dbms] === dbTier)
		XCTAssert(localView!.tiers[.gis] === gisTier)
		XCTAssert(localView!.tiers[.geoevent] == nil)
		XCTAssert(localView!.definition.serviceTimes[.gis]! > 0)
		
		let localViewZone = design.findZone(containing: localView!)
		XCTAssert(localViewZone != nil)
	}
	
	func testHADesignLoad() throws {
		let design = try Design(from: TestDesign.ha.designData!)
		XCTAssert(design.name == "Design 02 (HA)")
		XCTAssert(design.zones.count == 4)
		
		let internet = design.findZone(named: "Internet")
		XCTAssert(internet != nil)
		XCTAssert(internet!.hosts.count == 0)
		
		let lan = design.findZone(named: "LAN")
		XCTAssert(lan != nil)
		XCTAssert(lan!.hosts.count == 6)
		XCTAssert(lan!.hosts.filter({$0 is PhysicalHost}).count == 2)
		XCTAssert(lan!.hosts.filter({$0 is VirtualHost}).count == 4)
		
		let dmz = design.findZone(named: "DMZ")
		XCTAssert(dmz != nil)
		XCTAssert(dmz!.hosts.count == 2)
		XCTAssert(dmz!.hosts.filter({$0 is PhysicalHost}).count == 1)
		XCTAssert(dmz!.hosts.filter({$0 is VirtualHost}).count == 1)

		let agol = design.findZone(named: "ArcGIS Online")
		XCTAssert(agol != nil)
		XCTAssert(agol!.hosts.count == 1)
		XCTAssert(agol!.hosts[0].name == "AGOL AMI")
		
		XCTAssert(design.tiers.count == 6)
		let dbTier = design.tiers.first(where: {$0.name == "DBMS"})
		XCTAssert(dbTier != nil)
		XCTAssert(design.defaultTiers[.dbms] === dbTier)
		let gisTier = design.tiers.first(where: {$0.name == "GIS"})
		XCTAssert(gisTier != nil)
		XCTAssert(gisTier!.nodes.count == 2)
		XCTAssert(gisTier!.roles.count == 3)
		XCTAssert(gisTier!.roles.contains(.gis))
		let portalTier = design.tiers.first(where: {$0.name == "Portal"})
		XCTAssert(portalTier != nil)
		XCTAssert(portalTier!.nodes.count == 1)
		XCTAssert(portalTier!.roles.count == 1)
		XCTAssert(portalTier!.roles.contains(.portal))
		let citrixTier = design.tiers.first(where: {$0.name == "Citrix"})
		XCTAssert(citrixTier != nil)
		XCTAssert(citrixTier!.nodes.count == 1)
		XCTAssert(citrixTier!.roles.count == 1)
		XCTAssert(citrixTier!.roles.contains(.wts))
		let webTier = design.tiers.first(where: {$0.name == "Web"})
		XCTAssert(webTier != nil)
		XCTAssert(webTier!.nodes.count == 1)
		XCTAssert(webTier!.roles.count == 1)
		XCTAssert(webTier!.roles.contains(.web))

		XCTAssert(design.configuredWorkflows.count == 2)
		let localView = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(localView != nil)
		//XCTAssert(localView!.tps == 20000.0 / 60.0 / 60.0)
		XCTAssert(localView!.tiers[.dbms] === dbTier)
		XCTAssert(localView!.tiers[.gis] === gisTier)
		XCTAssert(localView!.tiers[.portal] === portalTier)
		XCTAssert(localView!.tiers[.geoevent] == nil)
		XCTAssert(localView!.definition.serviceTimes[.gis]! > 0)
		
		let localViewZone = design.findZone(containing: localView!)
		XCTAssert(localViewZone != nil)
	}

	func testSingleMapRequest() throws {
		let design = try Design(from: TestDesign.ha.designData!)
		
		var clock = 0.0
		let cw = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(cw != nil)
		let req = ClientRequest(configuredWorkflow: cw!)
		print(req.configuredWorkflow.definition.serviceType.serverRoleChain)
		req.solution = try ClientRequestSolutionFactory.createSolution(for: req, in: design)
		XCTAssert(req.solution != nil)
		XCTAssert(req.solution!.stepCount > 0)

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
		if req.configuredWorkflow.tiers[.portal]!.name == "AGOL" {
			XCTAssert(req.metrics.totalLatencyTime > 0.0)
		}
		print("Response time for request \(req.name) was \(req.metrics.responseTime) s")
	}
	
	func testSingleMapRequestWithCache() throws {
		let design = try Design(from: TestDesign.ha.designData!)
		
		var clock = 0.0
		let cw = design.configuredWorkflows.first(where: {$0.name == "Local View"})
		XCTAssert(cw != nil)
		let req = ClientRequest(configuredWorkflow: cw!)
		print(req.configuredWorkflow.definition.serviceType.serverRoleChain)
		req.solution = try ClientRequestSolutionFactory.createSolution(for: req, in: design)
		XCTAssert(req.solution != nil)
		
		var reqs = [req]
		
		if req.configuredWorkflow.definition.hasCache {
			let cacheCW = cw!.copy()
			let cacheReq = ClientRequest(configuredWorkflow: cacheCW)
			cacheReq.configuredWorkflow.definition.serviceType = .cache
			XCTAssert(req.configuredWorkflow.definition.serviceType != cacheReq.configuredWorkflow.definition.serviceType)
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
		if req.configuredWorkflow.tiers[.portal]!.name == "AGOL" {
			XCTAssert(req.metrics.totalLatencyTime > 0.0)
		}
		for r in reqs {
			print("\(r.name) ST: \(r.metrics.totalServiceTime.roundTo(places: 3)) QT: \(r.metrics.totalQueueTime.roundTo(places: 6))")
		}
	}
	
	func testSimulation() throws {
		let simulator = Simulator()
		let design = try Design(from: TestDesign.ha.designData!)
		simulator.design = design
		
		simulator.start()
		
		for _ in 0..<10 {
			simulator.advanceTime(by: 1.0)
		}
		print(simulator.handled.count)
		for cNode in simulator.design!.computeNodes {
			print("\(cNode.name) utilization: \(cNode.queue.metrics.utilization(inPrevious: nil))")
		}
		for nConn in simulator.design!.networkConnections {
			print("\((nConn as (any ObjectIdentity)).name) utilization: \(nConn.queue.metrics.utilization(inPrevious: nil))")
		}
	}
}
