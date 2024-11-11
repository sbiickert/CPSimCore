//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

/// Model object representing a network zone that can contain hosts and clients.
/// More esoteric examples include an "Internet" for bridging between LAN and cloud, for example.
public class NetworkZone: ObjectIdentity {
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the zone (expected to be unique)
	public var name: String = ""
	/// A friendly description of the zone
	public var description: String = ""
	
	/// Convenience accessor for the bandwidth of the ``localConnection``
	var localBandwidth: UInt {
		get {
			return self.localConnection?.bandwidth ?? 0
		}
	}
	
	/// List of the connections that have their ``NetworkConnection/source``  in this zone.
	public var connections = [NetworkConnection]()
	
	/// List of the configured workflows whose client is in this zone.
	public var configuredWorkflows = [ConfiguredWorkflow]()
	
	/// List of hosts that are located in this zone.
	public var hosts = [Host]()
	
	/// Initializer
	/// - Parameter bw: The local bandwidth within the zone in Mbps.
	public init(bandwidth bw: UInt = 100) {
		_ = NetworkConnection(sourceZone: self, destZone: self, bandwidth: bw, latencyMilliSeconds: 0) // localConnection
	}
	
	private struct JsonKeys {
		static let name = "name"
		static let desc = "description"
		static let bw = "localBW"
	}
	
	/// Initializer for creating the zone from a parsed dictionary
	/// - Parameter info: The parsed content from the design file (JSON).
	public init(info: NSDictionary) throws {
		name = info[JsonKeys.name] as! String
		description = info[JsonKeys.desc] as! String
		let bw = info[JsonKeys.bw] as! UInt
		_ = NetworkConnection(sourceZone: self, destZone: self, bandwidth: bw, latencyMilliSeconds: 0) // localConnection
	}
	
	/// Encodes this zone back to a dictionary.
	/// - Returns: Dictionary ready for re-encoding to a file representation.
	public func toDictionary() -> NSDictionary {
		let nzDict = NSMutableDictionary()
		nzDict.setValue(self.name, forKey: JsonKeys.name)
		nzDict.setValue(self.description, forKey: JsonKeys.desc)
		nzDict.setValue(self.localConnection?.bandwidth ?? 0, forKey: JsonKeys.bw)
		return nzDict
	}
	
	/// The connection in ``connections`` that has a source and destination in this zone.
	public var localConnection: NetworkConnection? {
		return connections.first(where: {$0.isLocalConnection})
	}
	
	/// The list of connections that does not include the ``localConnection``.
	public var exitConnections: [NetworkConnection] {
		return connections.filter({$0.isLocalConnection == false})
	}
	
	/// Finds a connection that exits this zone and ends at the specified other zone.
	/// - Parameter zone: The zone the connection leads to.
	/// - Returns: The connection from ``connections`` that goes to the zone. `nil` if no connections go to the specified zone.
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
