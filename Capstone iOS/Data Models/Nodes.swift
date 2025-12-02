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
    var sensorData: [Int]
    
    init(UUID: String, advName: String, sensorData: [Int]) {
        self.UUID = UUID
        self.advName = advName
        self.sensorData = sensorData
    }
}
