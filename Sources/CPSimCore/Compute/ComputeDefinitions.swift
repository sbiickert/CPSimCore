//
//  ServerRole.swift
//  CPSim
//
//  Created by Simon Biickert on 2017-06-17.
//  Copyright © 2017 ii Softwerks. All rights reserved.
//

import Foundation

enum ComputeRole: String, CaseIterable {
	case client = "client"
	case wts = "wts"
	case web = "web"
	case portal = "portal"
	case dbms = "dbms"
	case file = "file"
	case cache = "cache"
	case hosting = "hosting"
	case gis = "gis"
	case sde = "sde"
	case geoanalytic = "geoanalytic"
	case geoevent = "geoevent"
	case rasteranalytic = "rasteranalytic"
}

protocol ComputeNode: ServiceTimeCalculator {
	var hardware: HardwareDefinition? {get set}
	func adjustedServiceTime(_ workflowServiceTime: Double) -> Double
	func handle(request: ClientRequest, clock: Double)
}

