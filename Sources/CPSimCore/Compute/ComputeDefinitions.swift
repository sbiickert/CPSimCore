//
//  ComputeDefinitions.swift
//  CPSimCore
//
//  Created by Simon Biickert on 2017-06-17.
//  Copyright © 2017 ii Softwerks. All rights reserved.
//

import Foundation

/// Enumeration of the known computing roles in ArcGIS Enterprise
public enum ComputeRole: String, CaseIterable {
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

	
	/// Is `true` if this component renders raw data into the final result.
	/// Is used in ``ClientRequestSolutionFactory/createSolution(for:in:)`` to determine
	/// when the large source data is rendered into a client image or other result.
	public var isRenderer: Bool {
		return ComputeRole.renderers.contains(self)
	}
	
	/// The list of ``ComputeRole`` that are renderers
	public static var renderers: [ComputeRole] {
		return [.client, .wts, .hosting, .gis, .cache]
	}
}


/// Protocol encapsulating the abstract idea of a compute node that can handle requests on known hardware.
public class ComputeNode: IdentifiedClass, ServiceTimeCalculator {
	public init(coreCount: UInt = 1) {
		queue = MultiQueue(channelCount: coreCount)
		super.init()
	}
	
	/// The definition of the hardware that hosts this ComputeNode.
	public var hardware: HardwareDefinition?
	
	/// The queue for handling requests as they come in.
	public var queue: MultiQueue
	
	/// Client is passed the request at simulation time. It queues the request.
	/// - Parameters:
	///   - request: The request to handle.
	///   - clock: The simulation time that the Client is receiving the request.
	public func handle(request: ClientRequest, clock: Double) {
		queue.enqueue(request, clock: clock)
	}
	
	/// Adjusts the service time based on the `Client` `hardwareDefinition`
	///
	/// - Parameter workflowServiceTime: The standard service time in seconds.
	/// - Returns: The adjusted service time in seconds.
	public func adjustedServiceTime(_ workflowServiceTime: Double) -> Double {
		guard hardware != nil else { return -1.0 }
		return workflowServiceTime * (HardwareDefinition.baselineRatingPerCore / hardware!.specRatingPerCore)
	}
	
	public func calculateServiceTime(for request:ClientRequest) -> Double {
		return 0.0
	}

	public func calculateLatency(for request:ClientRequest) -> Double {
		return 0.0
	}

}

/// Enumeration of known data source types for vector data.
public enum DataSourceType: String {
	case DBMS = "DB"
	case SmallFileGDB = "SFG"
	case LargeFileGDB = "LFG"
	case SmallShapeFile = "SSF"
	case MediumShapeFile = "MSF"
	case LargeShapeFile = "LSF"
	case CachedTiles = "Cache"
	
	/// The correction factor for the compute effort for a data source type
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
	
	/// The correction factor for the network traffic for a data source type
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
