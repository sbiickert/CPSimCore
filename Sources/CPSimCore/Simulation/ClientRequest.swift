//
//  File.swift
//  
//
//  Created by Simon Biickert on 2021-09-28.
//

import Foundation

class ClientRequest: ObjectIdentity, Equatable {
	static func == (lhs: ClientRequest, rhs: ClientRequest) -> Bool {
		return lhs.id == rhs.id
	}
	static let requestTime = 0.0001 // seconds
	static let requestSize = 0.1 // Mb
	static var _counter:Int = 0
	static var nextID: String  {
		_counter += 1
		return "CR-\(_counter)"
	}

	var id: String = ClientRequest.nextID
	var name: String = ""
	var description: String?

	let metrics = ClientRequestMetrics()
	
}
