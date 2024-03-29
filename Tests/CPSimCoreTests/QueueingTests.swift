import XCTest
@testable import CPSimCore

final class QueueingTests: XCTestCase {
	private var hwLib = HardwareLibrary()
	private var wfLib = WorkflowLibrary()

	override func setUp() async throws {
		try await HardwareLibrary.loadDefaultHardware()
		hwLib = HardwareLibrary.defaultLibrary
		try await WorkflowLibrary.loadDefaultWorkflows()
		wfLib = WorkflowLibrary.defaultLibrary
	}

	func testQueue() throws {
		let q = MultiQueue(channelCount: 2)
		q.mode = .processing
		
		let r1 = SimulationTests.exampleClientRequest(hwLib: hwLib, wfLib: wfLib)
		q.enqueue(r1!, clock: 1.0)
		
		XCTAssert(q.requestCount == 1)
		XCTAssert(q.availableChannelCount == 1)
		
		let r2 = SimulationTests.exampleClientRequest(hwLib: hwLib, wfLib: wfLib)
		q.enqueue(r2!, clock: 1.0)
		
		XCTAssert(q.requestCount == 2)
		XCTAssert(q.availableChannelCount == 0)
		
		let r3 = SimulationTests.exampleClientRequest(hwLib: hwLib, wfLib: wfLib)
		q.enqueue(r3!, clock: 1.0)
		
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
	
	func testResizeQueue() throws {
		let q = MultiQueue(channelCount: 2)
		q.mode = .processing
		
		let r1 = SimulationTests.exampleClientRequest(hwLib: hwLib, wfLib: wfLib)
		q.enqueue(r1!, clock: 1.01)
		
		XCTAssert(q.requestCount == 1)
		XCTAssert(q.availableChannelCount == 1)
		
		q.requestedChannelCount = 4
		var finished = q.removeFinishedRequests(1.0)
		
		XCTAssert(finished.count == 0)
		XCTAssert(q.requestCount == 1)
		XCTAssert(q.availableChannelCount == 3)
		
		q.requestedChannelCount = 2
		finished = q.removeFinishedRequests(1.0)
		
		XCTAssert(finished.count == 0)
		XCTAssert(q.requestCount == 1)
		XCTAssert(q.availableChannelCount == 1)
	}
	
	func testUtilization() throws {
		var mqm = MultiQueueMetrics(channelCount: 4)
		
		mqm.add(dataPoint: (clock: 0.0, requestCount: 2))
		
		XCTAssert(mqm.utilization(inPrevious: nil) == 0.5)
		
		mqm.add(dataPoint: (clock: 1.0, requestCount: 4))
		XCTAssert(mqm.utilization(inPrevious: nil) == 1.0)
		
		mqm.add(dataPoint: (clock: 2.0, requestCount: 2))
		XCTAssert(mqm.utilization(inPrevious: nil) == 0.75)
		
		mqm.add(dataPoint: (clock: 10.0, requestCount: 1))
		XCTAssert(mqm.utilization(inPrevious: 5.0) == 0.25)
	}
}
