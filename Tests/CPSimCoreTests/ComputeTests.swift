import XCTest
@testable import CPSimCore

final class ComputeTests: XCTestCase {
	
	func testClient() throws {
		let hw = HardwareDefinition(id: "hw1", name: "", description: "", category: "", processor: "abc123", coreCount: 4, chipCount: 1, mhz: 2000, specRating: 45, platform: .intel, referenceYear: 2020)
		let client = Client(hw)
		let request = ClientRequest()
		client.handle(request: request, clock: 1.0)
		
	}
}
