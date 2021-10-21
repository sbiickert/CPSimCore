//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

public struct HardwareLibrary {
	static let PATH = "/Users/sjb/Code/Capacity Planning/CPSimCore/Config/hardware.json"
	static let GITHUB_URL = "https://raw.githubusercontent.com/sbiickert/CPSimCore/main/Library/hardware.json"
	
	static func defaultHardware() throws -> HardwareLibrary {
		return try HardwareLibrary(at: URL(string: GITHUB_URL)!)
	}
	
	var aliases = Dictionary<String, String>()
	private var _hardware = Dictionary<String, HardwareDefinition>()
	
	var baselineRating: Double = 50.0
	
	init(at path: String) throws {
		let url = URL(fileURLWithPath: path)
		try self.init(at: url)
	}
	
	init(at url: URL) throws {
		if let jsonData = try? Data(contentsOf: url),
		   let jsonResult = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
		{
			baselineRating = jsonResult["arcbaselinerating"] as? Double ?? baselineRating
			
			if let hwTypes = jsonResult["hardwareTypes"] as? NSArray {
				for element in hwTypes {
					if let hwInfo = element as? NSDictionary {
						let hwDef = HardwareDefinition(info: hwInfo)
						_hardware[hwDef.name] = hwDef
					}
				}
			}
		}
	}
	
	public func findHardware(_ key: String) -> HardwareDefinition? {
		if aliases.keys.contains(key) {
			return self._hardware[aliases[key]!]
		}
		return self._hardware[key]
	}
}

public struct HardwareDefinition: ObjectIdentity, Equatable {
	static var baselineRatingPerCore: Double = 50.0

	public var id: String = UUID().uuidString
	public var name: String
	public var description: String?
	
	var category: String?
	var processor: String = ""
	var coreCount: UInt = 1
	var chipCount: UInt = 1
	var mhz: Int = 1000
	var specRating: UInt = 200
	var platform: Platform = .intel
	var referenceYear: UInt = 2000

	init(info: NSDictionary) {
		if let id = info.value(forKey: "id") as? String {
			self.id = id
		}
		id = info["name"] as! String
		name = info["name"] as! String
		category = info["category"] as? String
		processor = info["processor"] as! String
		coreCount = info["nCores"] as! UInt
		chipCount = info["nChips"] as! UInt
		mhz = (info["mhz"] as? NSNumber)?.intValue ?? 1 // AMIs can have fractional mhz for some reason
		specRating = info["spec"] as! UInt
		platform = Platform(rawValue: info["platform"] as! String) ?? .intel
		referenceYear = info["refYear"] as? UInt ?? 2000
	}
	
	var specRatingPerCore: Double {
		get {
			return Double(specRating) / (Double(coreCount) * Double(chipCount))
		}
	}

}

public enum Platform: String {
	case intel = "Intel"
	case amd = "AMD"
	case sparc = "Sun SPARC"
	case itanium = "Itanium"
	case parisc = "PARisc"
	case pseries = "IBM pSeries"
}
