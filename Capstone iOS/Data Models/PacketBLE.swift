//
//  PacketBLE.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/27/25.
//

import Foundation

struct Packet {
    var accel: Double
    var gyro: Double
    var temp: Double
    var air: [Double]
    
    init(accel: Double, gyro: Double, temp: Double, air:[Double]) {
        self.accel = accel
        self.gyro = gyro
        self.temp = temp
        self.air = air
    }
}
