//
//  File.swift
//  
//
//  Created by Michael Kowalski on 10/6/20.
//

import XCTest
import TensorFlow
import x10_training_loop

final class TrainingLoopTests: XCTestCase {
    func testTrainingDevices() {
        let devices = Device.trainingDevices
        XCTAssertEqual(devices.count, 1)
    }
}

extension TrainingLoopTests {
  static var allTests = [
    ("testTrainingDevices", testTrainingDevices),
  ]
}

XCTMain([
  testCase(TrainingLoopTests.allTests)
])
