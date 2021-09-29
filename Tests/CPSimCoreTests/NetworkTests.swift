import XCTest
@testable import CPSimCore

final class NetworksTests: XCTestCase {
	
	func testSimpleNetwork() throws {
		let z1 = NetworkZone()
		let z2 = NetworkZone(bandwidth: 1000)
		
		XCTAssert(z1.connections.count == 1)
		XCTAssert(z2.connections.count == 1)
		XCTAssert(z1.localConnection != nil)
		XCTAssert(z2.localConnection != nil)

		_ = NetworkConnection(sourceZone: z1, destZone: z2, bandwidth: 10, latencyMilliSeconds: 20)
		
		XCTAssert(z1.connections.count == 2)
		XCTAssert(z2.connections.count == 2)

		_ = NetworkConnection(sourceZone: z2, destZone: z1, bandwidth: 15, latencyMilliSeconds: 25)
		
		XCTAssert(z1.connections.count == 3)
		XCTAssert(z2.connections.count == 3)
		
		XCTAssert(z1.exitConnection(to: z2) != nil)
		XCTAssert(z1.exitConnection(to: z2)?.bandwidth == 10)
		XCTAssert(z2.exitConnection(to: z1) != nil)
		XCTAssert(z2.exitConnection(to: z1)?.bandwidth == 15)
	}
	
}
