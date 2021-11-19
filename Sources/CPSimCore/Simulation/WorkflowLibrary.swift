//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-10-05.
//

import Foundation

/// A container for ``WorkflowDefinition`` objects loaded from the source JSON definition.
public struct WorkflowLibrary {
	static let PATH = "/Users/sjb/Developer/Capacity Planning/CPSimCore/Config/workflows.json"
	/// The online location of the master copy of the workflow library.
	public static let GITHUB_URL = "https://raw.githubusercontent.com/sbiickert/CPSimCore/main/Library/workflows.json"
	
	/// Creates a library based on the online location
	public static func defaultWorkflows() throws -> WorkflowLibrary {
		return try WorkflowLibrary(at: URL(string: GITHUB_URL)!)
	}

	/// Shorter alias names referencing the full names of workflow definitions
	public var aliases = Dictionary<String, String>()
	
	/// Private storage of the workflow definitions by name
	private var _workflows = Dictionary<String, WorkflowDefinition>()
	
	/// Convenience initializer for opening a local file
	/// - Parameter path: The file path to read workflow definitions from.
	public init(at path:String) throws {
		let url = URL(fileURLWithPath: path)
		try self.init(at: url)
	}
	
	/// Initializer for opening the workflow definitions from a URL (file or Internet)
	/// - Parameter url: The URL to read workflow definitions from.
	public init(at url:URL) throws {
		if let jsonData = try? Data(contentsOf: url),
		   let workflowData = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
		{
			if let workflowInfos = workflowData["workflows"] as? NSArray {
				for wInfo in workflowInfos {
					let w = try WorkflowDefinition(workflowData: wInfo as! NSDictionary)
					_workflows[w.name] = w
				}
			}
		}
	}
	
	/// Searches the library for a workflow definition by either name or alias
	/// - Parameter key: The workflow definition's name or alias
	/// - Returns: The workflow definition if found. `nil` if not found.
	public func findWorkflow(_ key: String) -> WorkflowDefinition? {
		if aliases.keys.contains(key) {
			return self._workflows[aliases[key]!]
		}
		return self._workflows[key]
	}
	
	/// The number of workflows in the library.
	public var count: Int {
		return _workflows.count
	}
}

/// Structure encapsulating the relevant attributes of a workflow
/// Includes key values like service times, network traffic.
public struct WorkflowDefinition: ObjectIdentity {
	/// Standard time in seconds for service times for cached operations.
	public static let cacheServiceTime = 0.001
	
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the workflow (expected to be unique)
	public var name: String
	/// A friendly description of the workflow
	public var description: String?

	/// Mapping of the service times for the workflow. Workflows do not have service times for all roles.
	public var serviceTimes = Dictionary<ComputeRole, Double>()
	/// General categorization: standard, sample.
	public var category: String?
	/// The type of service associated with this workflow
	public var serviceType = ServiceType.map
	/// The amount of network chatter between the client and the system.
	public var chatter: UInt = 0
	/// The amount of network traffic after rendering. In Mb.
	public var clientTraffic: Double = 0.0
	/// The amount of network traffic before rendering. In Mb.
	public var serverTraffic: Double = 0.0
	/// The minimum amount of think time for the workflow in seconds.
	public var thinkTime: UInt = 0
	
	/// Initalizer
	/// - Parameter workflowData: The decoded information from workflows.json
	public init(workflowData: NSDictionary) throws {
		if let id = workflowData.value(forKey: "id") as? String {
			self.id = id
		}
		self.name = workflowData.value(forKey: "name") as! String
		self.description = workflowData.value(forKey: "description") as? String
		
		self.category = workflowData.value(forKey: "category") as? String
		let wType = workflowData.value(forKey: "wType") as! String
		self.serviceType = ServiceType.from(string: wType)
		self.chatter = workflowData.value(forKey: "chatter") as! UInt
		self.clientTraffic = workflowData.value(forKey: "clientTraffic") as! Double
		self.serverTraffic = workflowData.value(forKey: "dbTraffic") as! Double
		self.thinkTime = workflowData.value(forKey: "think") as! UInt

		for cr in ComputeRole.allCases {
			let stKey = "\(cr.rawValue)ST"
			let st = workflowData.value(forKey: stKey) as? Double ?? 0.0
			serviceTimes[cr] = st
		}
		
		serviceTimes[.cache] = WorkflowDefinition.cacheServiceTime
	}
	
	/// Convenience accessor to get the ``ComputeRole/client`` service time from ``serviceTimes``.
	public var clientServiceTime: Double {
		return serviceTimes[ComputeRole.client] ?? 0.0
	}

	/// Returns `true` if the name has the `+$$` flag.
	public var hasCache: Bool {
		get {
			let nameHasCache = self.name.contains("+$$")
			let descHasCache = self.description?.contains("+$$") ?? false
			
			return nameHasCache || descHasCache
		}
	}
}

/// Enumeration of the known GIS service types
/// Each service type is known to have a particular chain of software roles that work together to create a response.
public enum ServiceType: String, CaseIterable {
	case map = "map"
	case cache = "$$"
	case feature = "feature"
	case image = "image"
	case geocode = "geocode"
	case geodata = "geodata"
	case geometry = "geometry"
	case geoprocessing = "geoprocessing"
	case network = "network"
	case scene = "scene"
	case schematic = "schematic"
	case sync = "sync"
	case stream = "stream"
	case custom = "custom"
	case insights = "insights"
	case rasterAnalytics = "raster_analytics"
	case geoAnalytics = "geo_analytics"
	
	/// Convenience method to create a service type from a string.
	/// - Parameter value: Case-independent way to pass a raw value.
	/// - Returns: The corresponding service type. If the string does not evaluate to a known type, ``ServiceType/custom`` is returned.
	public static func from(string value:String) -> ServiceType {
		let lc = value.lowercased()
		return ServiceType(rawValue: lc) ?? ServiceType.custom
	}
	
	/// For a given service type, return the series of compute roles to create the response.
	public var serverRoleChain: [ComputeRole] {
		var chain = [ComputeRole]()
		switch self {
		case .geoAnalytics:
			chain.append(contentsOf: [.wts, .web, .portal, .hosting, .geoanalytic, .dbms, .file])
		case .rasterAnalytics:
			chain.append(contentsOf: [.wts, .web, .portal, .hosting, .rasteranalytic, .dbms, .file])
		case .cache:
			chain.append(contentsOf: [.wts, .web, .cache])
		default:
			chain.append(contentsOf: [.wts, .web, .portal, .gis, .dbms, .file])
		}
		return chain
	}
}
