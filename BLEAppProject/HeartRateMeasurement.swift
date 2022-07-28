//
//  HeartRateMeasurement.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-06-23.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Bluejay
import Foundation

// https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml

struct HeartRateMeasurement: Receivable {

    private var flags: UInt8 = 0

    private var isMeasurementIn8bits = true

    var measurement: Int {
        return Int(flags)
    }

    init(bluetoothData: Data) throws {
        flags = try bluetoothData.extract(start: 0, length: 1)
    }

}
