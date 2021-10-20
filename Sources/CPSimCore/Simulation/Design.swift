import Foundation

public struct Design: ObjectIdentity {
	public var id: String = UUID().uuidString
	public var name: String = ""
	public var description: String?
	var zones = [NetworkZone]()
	var tiers = [Tier]()
	var defaultTiers = Dictionary<ComputeRole, Tier>()
	var hardwareLibrary: HardwareLibrary!
	var workflowLibrary: WorkflowLibrary!
	
	init() {
	}
	
	init(from designData: NSDictionary) throws {
		name = designData[JsonKeys.name] as? String ?? ""
		
		hardwareLibrary = try HardwareLibrary.defaultHardware()
		workflowLibrary = try WorkflowLibrary.defaultWorkflows()

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
					hardwareLibrary.aliases[hwAlias] = hwName
				}
			}
		}
		
		var clients = [Client]()
		if let clientInfos = designData[JsonKeys.clients] as? NSArray {
			for case let cInfo as NSDictionary in clientInfos {
				if let hwType = cInfo[JsonKeys.hwType] as? String,
				   let name = cInfo[JsonKeys.name] as? String,
				   let desc = cInfo[JsonKeys.desc] as? String,
				   let hw = hardwareLibrary.findHardware(hwType) {
					let client = Client(hw)
					client.name = name
					client.description = desc
					clients.append(client)
				}
			}
		}
		
		if let hostInfos = designData[JsonKeys.hosts] as? NSArray {
			for case let hInfo as NSDictionary in hostInfos {
				if let hwType = hInfo[JsonKeys.hwType] as? String,
				   let name = hInfo[JsonKeys.name] as? String,
				   let desc = hInfo[JsonKeys.desc] as? String,
				   let hw = hardwareLibrary.findHardware(hwType),
				   let zName = hInfo[JsonKeys.zone] as? String,
				   let zone = findZone(named: zName) {
					let host = PhysicalHost(hw)
					host.name = name
					host.description = desc
					zone.hosts.append(host)
				}
			}
		}
		
		if let vHostInfos = designData[JsonKeys.vHosts] as? NSArray {
			for case let vhInfo as NSDictionary in vHostInfos {
				if let name = vhInfo[JsonKeys.name] as? String,
				   let desc = vhInfo[JsonKeys.desc] as? String,
				   let hName = vhInfo[JsonKeys.host] as? String,
				   let host = hosts.first(where: {$0.name == hName}) as? PhysicalHost,
				   let zone = findZone(containingHostNamed: hName),
				   let vCPUCount = vhInfo[JsonKeys.vCPU] as? UInt {
					let vHost = VirtualHost(host, vCpus: vCPUCount, vMemGB: 16) // TODO: memory
					vHost.name = name
					vHost.description = desc
					zone.hosts.append(vHost)
				}
			}
		}

		// Tiers
		if let tierInfos = designData[JsonKeys.tiers] as? NSArray {
			for case let tInfo as NSDictionary in tierInfos {
				if let name = tInfo[JsonKeys.name] as? String,
				   let desc = tInfo[JsonKeys.desc] as? String,
				   let nodeNames = tInfo[JsonKeys.cNodes] as? NSArray,
				   let roleNames = tInfo[JsonKeys.sRoles] as? NSArray {
					let tier = Tier()
					tier.name = name
					tier.description = desc
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
					workflowLibrary.aliases[wfAlias] = wfName
				}
			}
		}
		
		// Configured Workflows
		if let cwInfos = designData[JsonKeys.configuredWorkflows] as? NSArray {
			for case let cwInfo as NSDictionary in cwInfos {
				if let name = cwInfo[JsonKeys.name] as? String,
				   let desc = cwInfo[JsonKeys.desc] as? String,
				   let wfName = cwInfo[JsonKeys.workflow] as? String,
				   let uCount = cwInfo[JsonKeys.uCount] as? Int,
				   let productivity = cwInfo[JsonKeys.productivity] as? Double,
				   let tph = cwInfo[JsonKeys.tph] as? Int,
				   let cName = cwInfo[JsonKeys.client] as? String,
				   let dsName = cwInfo[JsonKeys.dataSource] as? String,
				   let zName = cwInfo[JsonKeys.zone] as? String,
				   let wf = workflowLibrary.findWorkflow(wfName),
				   let zone = findZone(named: zName),
				   let client = clients.first(where: {$0.name == cName}) {
					let cw = ConfiguredWorkflow(name: name, definition: wf, client: client)
					cw.description = desc
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
	
	func toDictionary() -> NSDictionary {
		let dict = NSMutableDictionary()
		
		dict.setValue(self.name, forKey: JsonKeys.name)
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
		for alias in hardwareLibrary.aliases.keys {
			hwaDict.setValue(hardwareLibrary.aliases[alias], forKey: alias)
		}
		dict.setValue(hwaDict, forKey: JsonKeys.hwAliases)
		
		// Clients
		let cArray = NSMutableArray()
		for client in clients {
			let cDict = NSMutableDictionary()
			cDict.setValue(client.name, forKey: JsonKeys.name)
			cDict.setValue(client.description ?? "", forKey: JsonKeys.desc)
			cDict.setValue(client.hardware?.name ?? "", forKey: JsonKeys.hwType)
			cArray.add(cDict)
		}
		dict.setValue(cArray, forKey: JsonKeys.clients)
		
		// Physical hosts
		let hArray = NSMutableArray()
		let pHosts = hosts.compactMap({$0 as? PhysicalHost})
		for host in pHosts {
			let hDict = NSMutableDictionary()
			hDict.setValue(host.name, forKey: JsonKeys.name)
			hDict.setValue(host.description ?? "", forKey: JsonKeys.desc)
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
			vhDict.setValue(vHost.name, forKey: JsonKeys.name)
			vhDict.setValue(vHost.description ?? "", forKey: JsonKeys.desc)
			vhDict.setValue(vHost.physicalHost.name, forKey: JsonKeys.host)
			vhDict.setValue(vHost.vCpuCount, forKey: JsonKeys.vCPU)
			vhArray.add(vhDict)
		}
		dict.setValue(vhArray, forKey: JsonKeys.vHosts)
		
		// Tiers
		let tArray = NSMutableArray()
		for tier in tiers {
			let tDict = NSMutableDictionary()
			tDict.setValue(tier.name, forKey: JsonKeys.name)
			tDict.setValue(tier.description ?? "", forKey: JsonKeys.desc)
			let cnArray = NSMutableArray()
			for cNode in tier.nodes {
				cnArray.add((cNode as! Host).name)
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
		for alias in workflowLibrary.aliases.keys {
			wfaDict.setValue(workflowLibrary.aliases[alias], forKey: alias)
		}
		dict.setValue(wfaDict, forKey: JsonKeys.wfAliases)
		
		// Configured workflows
		let cwArray = NSMutableArray()
		for cw in configuredWorkflows {
			let cwDict = NSMutableDictionary()
			cwDict.setValue(cw.name, forKey: JsonKeys.name)
			cwDict.setValue(cw.description ?? "", forKey: JsonKeys.desc)
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
	
	var isValid:Bool {
		// TODO: improve evaluation of validity of the design
		let bNetworkExists = self.zones.count > 0
		let bHostExists = self.hosts.count > 0
		let bConfiguredWorkflow = self.configuredWorkflows.count > 0
		
		return bNetworkExists && bHostExists && bConfiguredWorkflow
	}

	var configuredWorkflows: [ConfiguredWorkflow] {
		var cw = [ConfiguredWorkflow]()
		for zone in zones {
			cw.append(contentsOf: zone.configuredWorkflows)
		}
		return cw
	}
	
	var clients: [Client] {
		var clientsByName = Dictionary<String, Client>()
		
		for cw in configuredWorkflows {
			let c = cw.client
			clientsByName[c.name] = c
		}
		
		return [Client](clientsByName.values)
	}
	
	var hosts: [Host] {
		var h = [Host]()
		for zone in zones {
			h.append(contentsOf: zone.hosts)
		}
		return h
	}
	
	var computeNodes: [ComputeNode] {
		var nodes = [ComputeNode]()
		nodes.append(contentsOf: hosts)
		for configuredWorkflow in configuredWorkflows {
			nodes.append(configuredWorkflow.client)
		}
		return nodes
	}
	
	var networkConnections: [NetworkConnection] {
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
	
	var interZoneConnections: [(NetworkConnection, NetworkConnection)] {
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
	
	func findZone(named name:String) -> NetworkZone? {
		return zones.first(where: {$0.name == name})
	}
	
	func findZone(containing host: Host) -> NetworkZone? {
		return findZone(containingHostNamed: host.name)
	}
	
	func findZone(containingHostNamed name: String) -> NetworkZone? {
		for zone in zones {
			if zone.hosts.contains(where: {$0.name == name}) {
				return zone
			}
		}
		return nil
	}
	
	func findZone(containing cw: ConfiguredWorkflow) -> NetworkZone? {
		for zone in zones {
			if zone.configuredWorkflows.contains(where: {$0.name == cw.name}) {
				return zone
			}
		}
		return nil
	}
	
	func findHost(named name: String) -> Host? {
		for zone in zones {
			if let host = zone.hosts.first(where: {$0.name == name}) {
				return host
			}
		}
		return nil
	}
	
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
		static let name = "name"
		static let desc = "description"
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
