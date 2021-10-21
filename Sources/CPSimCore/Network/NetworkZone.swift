//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

public class NetworkZone: ObjectIdentity {
	public var id: String =  UUID().uuidString
	public var name: String = ""
	public var description: String?
	
	public var localBandwidth: UInt = 1000
	public var connections = [NetworkConnection]()
	
	public var configuredWorkflows = [ConfiguredWorkflow]()
	public var hosts = [Host]()
	
	public init(bandwidth bw: UInt = 100) {
		localBandwidth = bw
		_ = NetworkConnection(sourceZone: self, destZone: self, bandwidth: bw, latencyMilliSeconds: 0) // localConnection
	}
	
	private struct JsonKeys {
		static let name = "name"
		static let desc = "description"
		static let bw = "localBW"
	}

	init(info: NSDictionary) throws {
		name = info[JsonKeys.name] as! String
		description = info[JsonKeys.desc] as? String
		localBandwidth = info[JsonKeys.bw] as! UInt
		_ = NetworkConnection(sourceZone: self, destZone: self, bandwidth: localBandwidth, latencyMilliSeconds: 0) // localConnection
	}
	
	func toDictionary() -> NSDictionary {
		let nzDict = NSMutableDictionary()
		nzDict.setValue(self.name, forKey: JsonKeys.name)
		nzDict.setValue(self.description ?? "", forKey: JsonKeys.desc)
		nzDict.setValue(self.localConnection?.bandwidth ?? 0, forKey: JsonKeys.bw)
		return nzDict
	}
	
	public var localConnection: NetworkConnection? {
		return connections.first(where: {$0.isLocalConnection})
	}
	
	public var exitConnections: [NetworkConnection] {
		return connections.filter({$0.isLocalConnection == false})
	}
	
	public func exitConnection(to zone:NetworkZone) -> NetworkConnection? {
		let connections = exitConnections
		for conn in connections {
			if conn.destination === zone {
				return conn
			}
		}
		return nil
	}

}
