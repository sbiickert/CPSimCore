import XCTest
@testable import CPSimCore

final class SimulationTests: XCTestCase {
	
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
		
		let localViewZone = design.findZone(containing: localView!)
		XCTAssert(localViewZone != nil)
	}
}
