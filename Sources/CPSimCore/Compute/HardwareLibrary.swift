//
//  HardwareLibrary.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// A container for ``HardwareDefinition`` objects loaded from the source JSON definition.
public struct HardwareLibrary {
	static let PATH = "/Users/sjb/Developer/Capacity Planning/CPSimCore/Config/hardware.json"
	/// The online location of the master copy of the hardware library.
	public static let GITHUB_URL = "https://raw.githubusercontent.com/sbiickert/CPSimCore/main/Library/hardware.json"
	
	/// Creates a library based on the online location
	public static func defaultHardware() throws -> HardwareLibrary {
		return try HardwareLibrary(at: URL(string: GITHUB_URL)!)
	}
	
	/// Shorter alias names referencing the full names of hardware definitions
	var aliases = Dictionary<String, String>()
	/// Private storage of the hardware definitions by name
	private var _hardware = Dictionary<String, HardwareDefinition>()
	
	
	/// Convenience initializer for opening a local file
	/// - Parameter path: The file path to read hardware definitions from.
	init(at path: String) throws {
		let url = URL(fileURLWithPath: path)
		try self.init(at: url)
	}
	
	/// Initializer for opening the hardware definitions from a URL (file or Internet)
	/// - Parameter url: The URL to read hardware definitions from.
	init(at url: URL) throws {
		if let jsonData = try? Data(contentsOf: url),
		   let jsonResult = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
		{
			HardwareDefinition.baselineRatingPerCore = jsonResult["arcbaselinerating"] as? Double ?? HardwareDefinition.baselineRatingPerCore
			
			if let hwTypes = jsonResult["hardwareTypes"] as? NSArray {
				for element in hwTypes {
					if let hwInfo = element as? NSDictionary {
						let hwDef = HardwareDefinition(hardwareData: hwInfo)
						_hardware[hwDef.name] = hwDef
					}
				}
			}
		}
	}
	
	/// Searches the library for a hardware definition by either name or alias
	/// - Parameter key: The hardware definition's name or alias
	/// - Returns: The hardware definition if found. `nil` if not found.
	public func findHardware(_ key: String) -> HardwareDefinition? {
		if aliases.keys.contains(key) {
			return self._hardware[aliases[key]!]
		}
		return self._hardware[key]
	}
}

/// Structure encapsulating the relevant attributes of a hardware platform
/// This includes the per-core performance and the number of processing cores
public struct HardwareDefinition: ObjectIdentity, Equatable {
	/// The standard performance rating used when defining the workflow service times
	public static var baselineRatingPerCore: Double = 50.0

	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the hardware (expected to be unique)
	public var name: String
	/// A friendly description of the hardware
	public var description: String?
	
	/// Classification of hardware (desktop, server)
	public var category: String?
	/// The identifier of the hardware. e.g. "Intel Core i7-2600"
	public var processor: String = ""
	/// The number of physical processor cores per chip
	public var coreCount: UInt = 1
	/// The number of CPU chips in the hardware
	public var chipCount: UInt = 1
	/// The clock cycle frequency. Not used except for helping to identify the processor.
	public var mhz: Int = 1000
	/// The [SPECint_rate2006](https://spec.org) score for the processor.
	public var specRating: UInt = 200
	/// The platorm type of the hardware
	public var platform: Platform = .intel
	/// The year that the hardware was identified and tested by SPEC
	public var referenceYear: UInt = 2000

	
	/// Initializer
	/// - Parameter info: The decoded information from hardware.json
	init(hardwareData: NSDictionary) {
		if let id = hardwareData.value(forKey: "id") as? String {
			self.id = id
		}
		id = hardwareData["name"] as! String
		name = hardwareData["name"] as! String
		category = hardwareData["category"] as? String
		processor = hardwareData["processor"] as! String
		coreCount = hardwareData["nCores"] as! UInt
		chipCount = hardwareData["nChips"] as! UInt
		mhz = (hardwareData["mhz"] as? NSNumber)?.intValue ?? 1 // AMIs can have fractional mhz for some reason
		specRating = hardwareData["spec"] as! UInt
		platform = Platform(rawValue: hardwareData["platform"] as! String) ?? .intel
		referenceYear = hardwareData["refYear"] as? UInt ?? 2000
	}
	
	/// The ``specRating`` divided by the total number of cores (``coreCount`` * ``chipCount``)
	var specRatingPerCore: Double {
		get {
			return Double(specRating) / (Double(coreCount) * Double(chipCount))
		}
	}

}

/// Enumeration of hardware platforms
/// Not used at the moment, but could restrict software roles to particular ``ComputeNode``s
public enum Platform: String {
	case intel = "Intel"
	case amd = "AMD"
	case sparc = "Sun SPARC"
	case itanium = "Itanium"
	case parisc = "PARisc"
	case pseries = "IBM pSeries"
}
