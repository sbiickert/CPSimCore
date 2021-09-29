import XCTest
@testable import CPSimCore

final class QueueingTests: XCTestCase {
	
	func testQueue() throws {
		let q = MultiQueue(channelCount: 2)
		q.metricsKey = "test"
		q.mode = .processing
		
		let r1 = ClientRequest()
		q.enqueue(r1, clock: 1.0)
		
		XCTAssert(q.requestCount == 1)
		XCTAssert(q.availableChannelCount == 1)
		
		let r2 = ClientRequest()
		q.enqueue(r2, clock: 1.0)
		
		XCTAssert(q.requestCount == 2)
		XCTAssert(q.availableChannelCount == 0)
		
		let r3 = ClientRequest()
		q.enqueue(r3, clock: 1.0)
		
		XCTAssert(q.requestCount == 3)
		XCTAssert(q.availableChannelCount == 0)
		
		var finished = q.removeFinishedRequests(2.0)
		
		XCTAssert(finished.count == 2)
		XCTAssert(q.requestCount == 1)
		XCTAssert(q.availableChannelCount == 1)
		XCTAssert(finished[0].metrics.totalServiceTime == 1.0)
		XCTAssert(finished[0].metrics.totalQueueTime == 0.0)
		XCTAssert(finished[0].metrics.totalLatencyTime == 0.0)
		
		finished = q.removeFinishedRequests(3.0)
		
		XCTAssert(finished.count == 1)
		XCTAssert(q.requestCount == 0)
		XCTAssert(q.availableChannelCount == 2)
		XCTAssert(finished[0].metrics.totalServiceTime == 1.0)
		XCTAssert(finished[0].metrics.totalQueueTime == 1.0)
		XCTAssert(finished[0].metrics.totalLatencyTime == 0.0)

	}
}