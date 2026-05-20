import XCTest
@testable import PixelCatPop

final class SystemMonitorTests: XCTestCase {
    func testSnapshotValuesStayInExpectedRanges() {
        let snapshot = SystemMonitor().sample()

        XCTAssertGreaterThanOrEqual(snapshot.cpuUsage, 0)
        XCTAssertLessThanOrEqual(snapshot.cpuUsage, 1)
        XCTAssertGreaterThanOrEqual(snapshot.memoryUsage, 0)
        XCTAssertLessThanOrEqual(snapshot.memoryUsage, 1)
        XCTAssertGreaterThanOrEqual(snapshot.diskUsage, 0)
        XCTAssertLessThanOrEqual(snapshot.diskUsage, 1)
    }
}
