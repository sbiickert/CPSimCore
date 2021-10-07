import XCTest
@testable import CPSimCore

final class CPSimCoreTests: XCTestCase {
    func testDoubleExtensions() throws {
		let val = 10.0
		let r = val.randomAdjusted()
		print(r)
		let rnd = r.roundTo(places: 2)
		print(rnd)
    }
	
	func testComputeRole() throws {
		let r:ComputeRole = .dbms
		XCTAssert(r.rawValue == "dbms")
	}
}
