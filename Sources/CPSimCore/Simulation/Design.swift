import Foundation

struct Design: ObjectIdentity {
	var id: String = UUID().uuidString
	var name: String = ""
	var description: String?
	var zones = [NetworkZone]()
	var tiers = [Tier]()
	var defaultTiers = Dictionary<ComputeRole, Tier>()
	
	init(at path:String) throws {
		let url = URL(fileURLWithPath: path)
		if let jsonData = try? Data(contentsOf: url),
		   let designData = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
		{
			name = designData[JsonKeys.name] as? String ?? ""
			
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
			var hwLib = try HardwareLibrary.defaultHardware()
			if let aliases = designData[JsonKeys.hwAliases] as? NSDictionary {
				for case let hwAlias as String in aliases.allKeys {
					if let hwName = aliases[hwAlias] as? String {
						hwLib.aliases[hwAlias] = hwName
					}
				}
			}
			
			var clients = [Client]()
			if let clientInfos = designData[JsonKeys.clients] as? NSArray {
				for case let cInfo as NSDictionary in clientInfos {
					if let hwType = cInfo[JsonKeys.hwType] as? String,
					   let name = cInfo[JsonKeys.name] as? String,
					   let desc = cInfo[JsonKeys.desc] as? String,
					   let hw = hwLib.findHardware(hwType) {
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
					   let hw = hwLib.findHardware(hwType),
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
			var wfLib = try WorkflowLibrary.defaultWorkflows()
			if let aliases = designData[JsonKeys.wfAliases] as? NSDictionary {
				for case let wfAlias as String in aliases.allKeys {
					if let wfName = aliases[wfAlias] as? String {
						wfLib.aliases[wfAlias] = wfName
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
					   let wf = wfLib.findWorkflow(wfName),
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
	}
	
	var isValid:Bool {
		// TODO: evaluate validity of the design
		return true
	}

	var configuredWorkflows: [ConfiguredWorkflow] {
		var cw = [ConfiguredWorkflow]()
		for zone in zones {
			cw.append(contentsOf: zone.configuredWorkflows)
		}
		return cw
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
			conns.append(contentsOf: zone.connections)
		}
		return conns
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
