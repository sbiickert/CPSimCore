//
//  ObjectIdentity.swift
//  CPSim
//
//  Created by Simon Biickert on 2017-06-17.
//  Copyright © 2017 ii Softwerks. All rights reserved.
//

import Foundation

protocol ObjectIdentity {
	var id: String {get set}
	var name: String {get set}
	var description: String? {get set}
}
