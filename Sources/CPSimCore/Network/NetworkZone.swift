//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-29.
//

import Foundation

class NetworkZone: ObjectIdentity {
	var id: String =  UUID().uuidString
	var name: String = ""
	var description: String?
	
	var localBandwidth: UInt = 1000
	var connections = [NetworkConnection]()
	var hosts = [Host]()
	
	init(bandwidth bw: UInt = 100) {
		localBandwidth = bw
		_ = NetworkConnection(sourceZone: self, destZone: self, bandwidth: bw, latencyMilliSeconds: 0) // localConnection
	}
	
	var localConnection: NetworkConnection? {
		return connections.first(where: {$0.isLocalConnection})
	}
	
	var exitConnections: [NetworkConnection] {
		return connections.filter({$0.isLocalConnection == false})
	}
	
	func exitConnection(to zone:NetworkZone) -> NetworkConnection? {
		let connections = exitConnections
		for conn in connections {
			if conn.destination === zone {
				return conn
			}
		}
		return nil
	}

}
