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

struct HardwareDefinition: ObjectIdentity, Equatable {
	static var baselineRatingPerCore: Double = 50.0
	
	var id: String = UUID().uuidString
	var name: String
	var description: String?
	
	var category: String?
	var processor: String = ""
	var coreCount: UInt = 1
	var chipCount: UInt = 1
	var mhz: Int = 1000
	var specRating: UInt = 200
	var platform: Platform = .intel
	var referenceYear: UInt = 2000

	var specRatingPerCore: Double {
		get {
			return Double(specRating) / (Double(coreCount) * Double(chipCount))
		}
	}

}

enum Platform: String {
	case intel = "Intel"
	case amd = "AMD"
	case sparc = "Sun SPARC"
	case itanium = "Itanium"
	case parisc = "PARisc"
	case pseries = "IBM pSeries"
}
