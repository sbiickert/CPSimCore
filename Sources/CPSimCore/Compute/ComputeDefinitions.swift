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
	case gis = "soc"
	case sde = "sde"
	case geoanalytic = "geoanalytic"
	case geoevent = "geoevent"
	case rasteranalytic = "rasteranalytic"
}

protocol ComputeNode: ServiceTimeCalculator {
	var hardware: HardwareDefinition? {get set}
	var queue: MultiQueue {get set}
	func adjustedServiceTime(_ workflowServiceTime: Double) -> Double
	func handle(request: ClientRequest, clock: Double)
}

enum DataSourceType: String {
	case DBMS = "DB"
	case SmallFileGDB = "SFG"
	case LargeFileGDB = "LFG"
	case SmallShapeFile = "SSF"
	case MediumShapeFile = "MSF"
	case LargeShapeFile = "LSF"
	case CachedTiles = "Cache"
	
	var appAdjustment: Double {
		get {
			switch rawValue {
			case "SFG":
				return 0.8
			case "MSF":
				return 2.0
			case "LSF":
				return 3.0
			default:
				return 1.0
			}
		}
	}
	
	var trafficAdjustment: Double {
		get {
			switch rawValue {
			case "LFG":
				return 1.5
			case "SSF":
				return 5.0
			case "MSF":
				return 10.0
			case "LSF":
				return 15.0
			default:
				return 1.0
			}
		}
	}
}
