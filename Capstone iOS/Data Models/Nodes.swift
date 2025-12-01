//
//  Nodes.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/27/25.
//

import Foundation

struct Node{
    var UUID: String
    var advName: String
    var sensorData: String
    
    init(UUID: String, advName: String, sensorData: String) {
        self.UUID = UUID
        self.advName = advName
        self.sensorData = sensorData
    }
}
