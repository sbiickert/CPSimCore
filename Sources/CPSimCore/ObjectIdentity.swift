//
//  ObjectIdentity.swift
//  CPSim
//
//  Created by Simon Biickert on 2017-06-17.
//  Copyright © 2017 ii Softwerks. All rights reserved.
//

import Foundation

/// Protocol for assigning id, name and description for all model objects.
public protocol ObjectIdentity {
	var id: String {get set}
	var name: String {get set}
	var description: String {get set}
}

/// Abstract superclass for classes implementing ObjectIdentity
public class IdentifiedClass: ObjectIdentity {
	/// A unique ID that is created when the object is created
	public var id: String = UUID().uuidString
	/// A name for the object (expected to be unique, but not required)
	public var name: String = ""
	public var description: String = ""
	
	public func applyIdentity(from dict: NSDictionary) {
		self.name = dict["name"] as? String ?? ""
		self.id = dict["name"] as? String ?? ""
		self.description = dict["description"] as? String ?? ""
	}
	
	public func saveIdentity(to dict: NSMutableDictionary) {
		dict.setValue(self.name, forKey: "name")
		dict.setValue(self.id, forKey: "id")
		dict.setValue(self.description, forKey: "description")
	}
}
