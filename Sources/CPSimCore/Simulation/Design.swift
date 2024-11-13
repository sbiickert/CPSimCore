import Foundation

/// The top-level model object in ``CPSimCore``. The ``Simulator`` runs a configured design.
public struct Design: ObjectIdentity {
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the design
	public var name: String = ""
	/// A friendly description of the design
	public var description: String = ""
	
	/// A list of network zones. All activity happens in a zone.
	public var zones = [NetworkZone]()
	
	/// The clusters of compute nodes that provide software functionality.
	public var tiers = [Tier]()
	
	/// The defaults for the design. ``ConfiguredWorkflow``s can specify non-default tiers.
	public var defaultTiers = Dictionary<ComputeRole, Tier>()
	
	/// The library of hardware types available for the design.
	public var hardwareLibrary: HardwareLibrary?
	
	/// The library of workflow types available for the design.
	public var workflowLibrary: WorkflowLibrary?
	
	/// For presenting the design
	public var summary: DesignSummary {
		return DesignSummary(design: self)
	}
	
	/// Iniitializer. Creates a completely empty design.
	public init() {
		if self.hardwareLibrary == nil {
			self.hardwareLibrary = HardwareLibrary.defaultLibrary
		}
		if self.workflowLibrary == nil {
			self.workflowLibrary = WorkflowLibrary.defaultLibrary
		}
	}
	
	/// Initializer taking a parsed dictionary of a saved design.
	/// - Parameter designData: Previously-saved design data.
	public init(from designData: NSDictionary) throws {
		guard HardwareLibrary.defaultLibrary.isLoaded else {
			return
		}
		guard WorkflowLibrary.defaultLibrary.isLoaded else {
			return
		}
		self.hardwareLibrary = HardwareLibrary.defaultLibrary
		self.workflowLibrary = WorkflowLibrary.defaultLibrary

		applyIdentity(from: designData)
				
		// Network Zones
		if let zoneInfos = designData[JsonKeys.networkZones] as? NSArray {
			for zInfo in zoneInfos {
				do {
					let z = try NetworkZone(info: zInfo as! NSDictionary)
					zones.append(z)
				}
				catch {
					print("Error parsing NetworkZone: \(error)")
				}
			}
		}
		// Network Connections
		if let connInfos = designData[JsonKeys.networkConns] as? NSArray {
			for case let cInfo as NSDictionary in connInfos {
				if let sourceZ = zones.first(where: {$0.name == cInfo[JsonKeys.up] as! String}),
				   let destZ = zones.first(where: {$0.name == cInfo[JsonKeys.down] as! String}) {
					let downC = NetworkConnection(sourceZone: sourceZ,
												  destZone: destZ,
												  bandwidth: cInfo[JsonKeys.dnBW] as! UInt,
												  latencyMilliSeconds: cInfo[JsonKeys.latency] as! UInt)
					let upC = downC.invert()
					upC.bandwidth = cInfo[JsonKeys.upBW] as! UInt
				}
			}
		}
		// Hardware
		if let aliases = designData[JsonKeys.hwAliases] as? NSDictionary {
			for case let hwAlias as String in aliases.allKeys {
				if let hwName = aliases[hwAlias] as? String {
					hardwareLibrary!.aliases[hwAlias] = hwName
				}
			}
		}
		
		var clients = [Client]()
		if let clientInfos = designData[JsonKeys.clients] as? NSArray {
			for case let cInfo as NSDictionary in clientInfos {
				if let hwType = cInfo[JsonKeys.hwType] as? String,
				   let hw = hardwareLibrary!.findHardware(hwType) {
					let client = Client(hw)
					client.applyIdentity(from: cInfo)
					clients.append(client)
				}
			}
		}
		
		if let hostInfos = designData[JsonKeys.hosts] as? NSArray {
			for case let hInfo as NSDictionary in hostInfos {
				if let hwType = hInfo[JsonKeys.hwType] as? String,
				   let hw = hardwareLibrary!.findHardware(hwType),
				   let zName = hInfo[JsonKeys.zone] as? String,
				   let zone = findZone(named: zName) {
					let host = PhysicalHost(hw)
					host.applyIdentity(from: hInfo)
					zone.hosts.append(host)
				}
			}
		}
		
		if let vHostInfos = designData[JsonKeys.vHosts] as? NSArray {
			for case let vhInfo as NSDictionary in vHostInfos {
				if let hName = vhInfo[JsonKeys.host] as? String,
				   let host = hosts.first(where: {$0.name == hName}) as? PhysicalHost,
				   let zone = findZone(containingHostNamed: hName),
				   let vCPUCount = vhInfo[JsonKeys.vCPU] as? UInt {
					let vHost = VirtualHost(host, vCpus: vCPUCount, vMemGB: 16) // TODO: memory
					vHost.applyIdentity(from: vhInfo)
					zone.hosts.append(vHost)
				}
			}
		}

		// Tiers
		if let tierInfos = designData[JsonKeys.tiers] as? NSArray {
			for case let tInfo as NSDictionary in tierInfos {
				if let nodeNames = tInfo[JsonKeys.cNodes] as? NSArray,
				   let roleNames = tInfo[JsonKeys.sRoles] as? NSArray {
					let tier = Tier()
					tier.applyIdentity(from: tInfo)
					for case let nodeName as String in nodeNames {
						if let node = findHost(named: nodeName) {
							tier.nodes.append(node)
						}
					}
					for case let roleName as String in roleNames {
						if let role = ComputeRole(rawValue: roleName) {
							tier.roles.insert(role)
						}
					}
					tiers.append(tier)
				}
			}
		}
		if let defaultTierInfo = designData[JsonKeys.defTiers] as? NSDictionary {
			for case let key as String in defaultTierInfo.allKeys {
				if let role = ComputeRole(rawValue: key),
				   let name = defaultTierInfo[key] as? String,
				   let tier = tiers.first(where: {$0.name == name}) {
					defaultTiers[role] = tier
				}
			}
		}
		
		// Workflows
		if let aliases = designData[JsonKeys.wfAliases] as? NSDictionary {
			for case let wfAlias as String in aliases.allKeys {
				if let wfName = aliases[wfAlias] as? String {
					workflowLibrary!.aliases[wfAlias] = wfName
				}
			}
		}
		
		// Configured Workflows
		if let cwInfos = designData[JsonKeys.configuredWorkflows] as? NSArray {
			for case let cwInfo as NSDictionary in cwInfos {
				if let name = cwInfo["name"] as? String,
				   let wfName = cwInfo[JsonKeys.workflow] as? String,
				   let uCount = cwInfo[JsonKeys.uCount] as? Int,
				   let productivity = cwInfo[JsonKeys.productivity] as? Double,
				   let tph = cwInfo[JsonKeys.tph] as? Int,
				   let cName = cwInfo[JsonKeys.client] as? String,
				   let dsName = cwInfo[JsonKeys.dataSource] as? String,
				   let zName = cwInfo[JsonKeys.zone] as? String,
				   let wf = workflowLibrary!.findWorkflow(wfName),
				   let zone = findZone(named: zName),
				   let client = clients.first(where: {$0.name == cName}) {
					let cw = ConfiguredWorkflow(name: name, definition: wf, client: client)
					cw.applyIdentity(from: cwInfo)
					cw.userCount = uCount
					cw.productivity = productivity
					cw.tph = tph
					cw.dataSource = DataSourceType(rawValue: dsName) ?? .DBMS
					cw.tiers = defaultTiers
					
					// Tier overrides
					if let tierInfo = cwInfo[JsonKeys.tiers] as? NSDictionary {
						for case let key as String in tierInfo.allKeys {
							if let role = ComputeRole(rawValue: key),
							   let name = tierInfo[key] as? String,
							   let tier = tiers.first(where: {$0.name == name}) {
								cw.tiers[role] = tier
							}
						}
					}
					
					zone.configuredWorkflows.append(cw)
				}
			}
		}
	}
	
	private mutating func applyIdentity(from dict: NSDictionary) {
		self.name = dict["name"] as? String ?? ""
		self.id = dict["id"] as? String ?? ""
		self.description = dict["description"] as? String ?? ""
	}
	
	private func saveIdentity(to dict: NSDictionary) {
		dict.setValue(self.name, forKey: "name")
		dict.setValue(self.id, forKey: "id")
		dict.setValue(self.description, forKey: "description")
	}

	
	/// Method to save the design.
	/// - Returns: Dictionary of the design, can be saved for future use.
	public func toDictionary() -> NSDictionary {
		let dict = NSMutableDictionary()
		
		saveIdentity(to: dict)
		dict.setValue(0.3, forKey: JsonKeys.version)
		
		// Network zones
		let nzArray = NSMutableArray()
		for zone in self.zones {
			let nzDict = zone.toDictionary()
			nzArray.add(nzDict)
		}
		dict.setValue(nzArray, forKey: JsonKeys.networkZones)
		
		// Network connections
		let ncArray = NSMutableArray()
		for link in self.interZoneConnections {
			let ncDict = NSMutableDictionary()
			ncDict.setValue(link.0.name, forKey: JsonKeys.up)
			ncDict.setValue(link.1.name, forKey: JsonKeys.down)
			ncDict.setValue(link.0.bandwidth, forKey: JsonKeys.upBW)
			ncDict.setValue(link.1.bandwidth, forKey: JsonKeys.dnBW)
			ncDict.setValue(max(link.0.latency, link.1.latency), forKey: JsonKeys.latency)
			ncArray.add(ncDict)
		}
		dict.setValue(ncArray, forKey: JsonKeys.networkConns)

		// Hardware aliases
		let hwaDict = NSMutableDictionary()
		for alias in hardwareLibrary!.aliases.keys {
			hwaDict.setValue(hardwareLibrary!.aliases[alias], forKey: alias)
		}
		dict.setValue(hwaDict, forKey: JsonKeys.hwAliases)
		
		// Clients
		let cArray = NSMutableArray()
		for client in clients {
			let cDict = NSMutableDictionary()
			client.saveIdentity(to: cDict)
			cDict.setValue(client.hardware?.name ?? "", forKey: JsonKeys.hwType)
			cArray.add(cDict)
		}
		dict.setValue(cArray, forKey: JsonKeys.clients)
		
		// Physical hosts
		let hArray = NSMutableArray()
		let pHosts = hosts.compactMap({$0 as? PhysicalHost})
		for host in pHosts {
			let hDict = NSMutableDictionary()
			host.saveIdentity(to: hDict)
			hDict.setValue(host.hardware?.name ?? "", forKey: JsonKeys.hwType)
			let zone = self.findZone(containing: host)!
			hDict.setValue(zone.name, forKey: JsonKeys.zone)
			hArray.add(hDict)
		}
		dict.setValue(hArray, forKey: JsonKeys.hosts)
		
		// Virtual hosts
		let vhArray = NSMutableArray()
		let vHosts = hosts.compactMap({$0 as? VirtualHost})
		for vHost in vHosts {
			let vhDict = NSMutableDictionary()
			vHost.saveIdentity(to: vhDict)
			vhDict.setValue(vHost.physicalHost.name, forKey: JsonKeys.host)
			vhDict.setValue(vHost.vCpuCount, forKey: JsonKeys.vCPU)
			vhArray.add(vhDict)
		}
		dict.setValue(vhArray, forKey: JsonKeys.vHosts)
		
		// Tiers
		let tArray = NSMutableArray()
		for tier in tiers {
			let tDict = NSMutableDictionary()
			tier.saveIdentity(to: tDict)
			let cnArray = NSMutableArray()
			for cNode in tier.nodes {
				cnArray.add((cNode as! ( Host)).name)
			}
			tDict.setValue(cnArray, forKey: JsonKeys.cNodes)
			let srArray = NSMutableArray()
			for role in tier.roles {
				srArray.add(role.rawValue)
			}
			tDict.setValue(srArray, forKey: JsonKeys.sRoles)
			tArray.add(tDict)
		}
		dict.setValue(tArray, forKey: JsonKeys.tiers)
		
		// Default Tiers
		let dtDict = NSMutableDictionary()
		for (role, tier) in defaultTiers {
			dtDict.setValue(tier.name, forKey: role.rawValue)
		}
		dict.setValue(dtDict, forKey: JsonKeys.defTiers)
		
		// Workflow aliases
		let wfaDict = NSMutableDictionary()
		for alias in workflowLibrary!.aliases.keys {
			wfaDict.setValue(workflowLibrary!.aliases[alias], forKey: alias)
		}
		dict.setValue(wfaDict, forKey: JsonKeys.wfAliases)
		
		// Configured workflows
		let cwArray = NSMutableArray()
		for cw in configuredWorkflows {
			let cwDict = NSMutableDictionary()
			cw.saveIdentity(to: cwDict)
			cwDict.setValue(cw.definition.name, forKey: JsonKeys.workflow)
			cwDict.setValue(cw.userCount, forKey: JsonKeys.uCount)
			cwDict.setValue(cw.productivity, forKey: JsonKeys.productivity)
			cwDict.setValue(cw.tph, forKey: JsonKeys.tph)
			cwDict.setValue(cw.client.name, forKey: JsonKeys.client)
			cwDict.setValue(cw.dataSource.rawValue, forKey: JsonKeys.dataSource)
			let zone = self.findZone(containing: cw)!
			cwDict.setValue(zone.name, forKey: JsonKeys.zone)
			let tDict = NSMutableDictionary()
			for (cRole, tier) in cw.tiers {
				tDict.setValue(tier.name, forKey: cRole.rawValue)
			}
			cwDict.setValue(tDict, forKey: JsonKeys.tiers)
			cwArray.add(cwDict)
		}
		dict.setValue(cwArray, forKey: JsonKeys.configuredWorkflows)
		
		return dict
	}
	
	/// Is the design complete enough to run?
	public var isValid:Bool {
		// TODO: improve evaluation of validity of the design
		let bNetworkExists = self.zones.count > 0
		let bHostExists = self.hosts.count > 0
		let bConfiguredWorkflow = self.configuredWorkflows.count > 0
		
		return bNetworkExists && bHostExists && bConfiguredWorkflow
	}
	
	/// List of all configured workflows.
	public var configuredWorkflows: [ConfiguredWorkflow] {
		var cw = [ConfiguredWorkflow]()
		for zone in zones {
			cw.append(contentsOf: zone.configuredWorkflows)
		}
		return cw
	}
	
	/// List of all clients.
	public var clients: [Client] {
		var clientsByName = Dictionary<String, Client>()
		
		for cw in configuredWorkflows {
			let c = cw.client
			clientsByName[c.name] = c
		}
		
		return [Client](clientsByName.values)
	}
	
	/// List of all hosts.
	public var hosts: [Host] {
		var h = [ Host]()
		for zone in zones {
			h.append(contentsOf: zone.hosts)
		}
		return h
	}
	
	/// List of all compute nodes (i.e. hosts and clients).
	public var computeNodes: [ComputeNode] {
		var nodes = [ComputeNode]()
		nodes.append(contentsOf: hosts)
		for configuredWorkflow in configuredWorkflows {
			nodes.append(configuredWorkflow.client)
		}
		return nodes
	}
	
	/// List of all network connections
	public var networkConnections: [NetworkConnection] {
		var conns = [NetworkConnection]()
		for zone in zones {
			let noDupes = zone.exitConnections.filter({a in
				let idx = conns.firstIndex(where: {$0.id == a.id})
				return idx == nil
			})
			conns.append(contentsOf: noDupes)
			conns.append(zone.localConnection!)
		}
		return conns
	}
	
	/// List of all network connections that connect different network zones.
	public var interZoneConnections: [(NetworkConnection, NetworkConnection)] {
		var links = [(NetworkConnection, NetworkConnection)]()
		let conns = self.networkConnections.filter({$0.source.id != $0.destination.id})
		var ids = Set<String>()
		
		for conn in conns {
			if ids.contains(conn.id) == false {
				// Find the connection in the opposite direction
				if let revConn = conns.first(where: {$0.destination.id == conn.source.id && $0.source.id == conn.destination.id}) {
					links.append( (conn, revConn) )
					ids.insert(conn.id)
					ids.insert(revConn.id)
				}
			}
		}
		return links
	}
	
	/// Method to find a network zone by name
	/// - Parameter name: Name of the network zone.
	/// - Returns: The named network zone if it exists.
	public func findZone(named name:String) -> NetworkZone? {
		return zones.first(where: {$0.name == name})
	}
	
	/// Method to find a network zone that contains a given host.
	/// - Parameter host: The host in the network zone
	/// - Returns: The network zone containing the host if it exists.
	public func findZone(containing host: Host) -> NetworkZone? {
		return findZone(containingHostNamed: host.name)
	}
	
	/// Method to find a network zone that contains a host with a given name.
	/// - Parameter name: The name of the host.
	/// - Returns: The network zone containing the named host if it exists.
	public func findZone(containingHostNamed name: String) -> NetworkZone? {
		for zone in zones {
			if zone.hosts.contains(where: {$0.name == name}) {
				return zone
			}
		}
		return nil
	}
	
	/// Method to find a network zone that contains a named configured workflow.
	/// - Parameter cw: The name of the configured workflow.
	/// - Returns: The network zone containing the named configured workflow if it exists.
	public func findZone(containing cw: ConfiguredWorkflow) -> NetworkZone? {
		for zone in zones {
			if zone.configuredWorkflows.contains(where: {$0.name == cw.name}) {
				return zone
			}
		}
		return nil
	}
	
	/// Method to find a named host.
	/// - Parameter name: The name of the host to find.
	/// - Returns: The named host if it exists.
	public func findHost(named name: String) -> ( Host)? {
		for zone in zones {
			if let host = zone.hosts.first(where: {$0.name == name}) {
				return host
			}
		}
		return nil
	}
	
	/// Constants for encoding/decoding the design information.
	/// These are names of keys in the dictionary.
	private struct JsonKeys {
		static let version = "version"
		static let networkZones = "networkZones"
		static let networkConns = "networkConnections"
		static let up = "up"
		static let down = "down"
		static let upBW = "upBW"
		static let dnBW = "downBW"
		static let latency = "latency"
		static let hwAliases = "hardwareAliases"
		static let clients = "clients"
		static let hosts = "hosts"
		static let vHosts = "virtualHosts"
		static let hwType = "hardwareType"
		static let zone = "zone"
		static let host = "host"
		static let vCPU = "vCPUCount"
		static let tiers = "tiers"
		static let cNodes = "computeNodes"
		static let sRoles = "serverRoles"
		static let defTiers = "defaultTiers"
		static let wfAliases = "workflowAliases"
		static let configuredWorkflows = "configuredWorkflows"
		static let workflow = "workflow"
		static let uCount = "userCount"
		static let tph = "tph"
		static let productivity = "productivity"
		static let client = "client"
		static let dataSource = "dataSource"
	}
}

public struct DesignSummary {
	public let design: Design
	
	public var clients: Dictionary<String, Int> {
		let names = design.clients.map {$0.name}.sorted()
		var summary = Dictionary<String, Int>()
		for name in names {
			if !summary.keys.contains(name) {
				summary[name] = 0
			}
			summary[name]! += 1
		}
		return summary
	}
}
