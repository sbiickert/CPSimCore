import Foundation

public struct CPSimCore {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}


extension Double {
	/// Rounds the double to decimal places value
	func roundTo(places:Int) -> Double {
		let divisor = pow(10.0, Double(places))
		return (self * divisor).rounded() / divisor
	}
	
	
	/// A way to distribute standard values either higher or lower.
	/// - Returns: The value multiplied by a random factor.
	func randomAdjusted() -> Double {
		let randomValue = Double.random(in: 0.0 ... 100.0)
		var adjusted = self
		switch randomValue {
		case 0.0 ..< 25.0:
			adjusted *= 0.9
		case 0.0 ..< 50.0:
			adjusted *= 1.0
		case 0.0 ..< 75.0:
			adjusted *= 1.5
		default:
			adjusted *= 2.0
		}
		return adjusted
	}
}
