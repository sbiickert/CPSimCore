//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-10-05.
//

import Foundation

public struct WorkflowLibrary {
	static let PATH = "/Users/sjb/Code/Capacity Planning/CPSimCore/Config/workflows.json"
	static let GITHUB_URL = "https://raw.githubusercontent.com/sbiickert/CPSimCore/main/Library/workflows.json"
	static func defaultWorkflows() throws -> WorkflowLibrary {
		return try WorkflowLibrary(at: URL(string: GITHUB_URL)!)
	}

	var aliases = Dictionary<String, String>()
	private var _workflows = Dictionary<String, WorkflowDefinition>()
	
	init(at path:String) throws {
		let url = URL(fileURLWithPath: path)
		try self.init(at: url)
	}
	
	init(at url:URL) throws {
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
	
	func findWorkflow(_ key: String) -> WorkflowDefinition? {
		if aliases.keys.contains(key) {
			return self._workflows[aliases[key]!]
		}
		return self._workflows[key]
	}
	
	var count: Int {
		return _workflows.count
	}
}

public struct WorkflowDefinition: ObjectIdentity {
	static let cacheServiceTime = 0.001
	
	public var id: String = UUID().uuidString
	public var name: String
	public var description: String?

	var serviceTimes = Dictionary<ComputeRole, Double>()
	var category: String?
	var serviceType = ServiceType.map
	var chatter: UInt = 0
	var clientTraffic: Double = 0.0
	var serverTraffic: Double = 0.0
	var thinkTime: UInt = 0
	
	init(workflowData: NSDictionary) throws {
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
	
	var clientServiceTime: Double {
		return serviceTimes[ComputeRole.client] ?? 0.0
	}

	
	var hasCache: Bool {
		get {
			let nameHasCache = self.name.contains("+$$")
			let descHasCache = self.description?.contains("+$$") ?? false
			
			return nameHasCache || descHasCache
		}
	}
}

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
	
	static func from(string value:String) -> ServiceType {
		let lc = value.lowercased()
		return ServiceType(rawValue: lc) ?? ServiceType.custom
	}
	
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
