import XCTest
@testable import CPSimCore

final class ComputeTests: XCTestCase {
	
	func testHWLibraryLoad() throws {
		var hwLib = try HardwareLibrary.defaultHardware()
		XCTAssert(hwLib.baselineRating == 58.0)
		XCTAssert(hwLib.findHardware("Intel Core i7-4770 4 core (1 chip) 3400 MHz") != nil)
		
		hwLib.aliases["bob"] = "Intel Core i7-4770 4 core (1 chip) 3400 MHz"
		
		XCTAssert(hwLib.findHardware("bob") != nil)
	}
	
	func testClient() throws {
		let request = SimulationTests.exampleClientRequest!
		let client = request.configuredWorkflow.client
		client.handle(request: request, clock: 1.0)
		
		XCTAssert(client.queue.requestCount == 1)
		
		let finished = client.queue.removeFinishedRequests(2.0)
		
		XCTAssert(finished.count == 1)
		XCTAssert(client.queue.requestCount == 0)
	}
	
	func testHost() throws {
		let hwLib = try HardwareLibrary.defaultHardware()
		let hw = hwLib.findHardware("Xeon E5-2430 12 core (2 chip) 2200 MHz")
		let pHost = PhysicalHost(hw!)
		_ = VirtualHost(pHost)
		_ = VirtualHost(pHost)
		
		XCTAssert(pHost.virtualHosts.count == 2)
	}
	
	func testMigration() throws {
		let hwLib = try HardwareLibrary.defaultHardware()
		let hw = hwLib.findHardware("Xeon E5-2430 12 core (2 chip) 2200 MHz")
		let pHost1 = PhysicalHost(hw!)
		let pHost2 = PhysicalHost(hw!)
		let vHost = VirtualHost(pHost1)
		
		XCTAssert(pHost1.virtualHosts.contains(where: {$0 === vHost}))
		
		vHost.physicalHost = pHost2
		
		XCTAssert(pHost1.virtualHosts.contains(where: {$0 === vHost}) == false)
		XCTAssert(pHost2.virtualHosts.contains(where: {$0 === vHost}))
	}
}
