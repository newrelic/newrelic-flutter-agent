/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Flutter
import UIKit
import XCTest

import newrelic_mobile

// Unit tests for the Swift method-channel handler.
//
// The Dart side always sends every key in the params map, so an omitted
// optional argument arrives here as NSNull rather than as a missing key.

class RunnerTests: XCTestCase {

    func testRecordMetricWithoutValueOrUnits() {
        let result = invoke("recordMetric", arguments: [
            "name": "GetFromCache",
            "category": "GetBasicUserInfo",
            "value": NSNull(),
            "countUnit": NSNull(),
            "valueUnit": NSNull(),
        ])

        XCTAssertEqual(result as? String, "Recorded Metrics")
    }

    func testRecordMetricWithValueOnly() {
        let result = invoke("recordMetric", arguments: [
            "name": "GetFromCache",
            "category": "GetBasicUserInfo",
            "value": 12.5,
            "countUnit": NSNull(),
            "valueUnit": NSNull(),
        ])

        XCTAssertEqual(result as? String, "Recorded Metrics")
    }

    func testRecordMetricWithValueAndValueUnit() {
        let result = invoke("recordMetric", arguments: [
            "name": "GetFromCache",
            "category": "GetBasicUserInfo",
            "value": 12.5,
            "countUnit": NSNull(),
            "valueUnit": "sec",
        ])

        XCTAssertEqual(result as? String, "Recorded Metrics")
    }

    func testRecordMetricWithValueAndUnits() {
        let result = invoke("recordMetric", arguments: [
            "name": "GetFromCache",
            "category": "GetBasicUserInfo",
            "value": 12.5,
            "countUnit": "op",
            "valueUnit": "sec",
        ])

        XCTAssertEqual(result as? String, "Recorded Metrics")
    }

    private func invoke(_ method: String, arguments: [String: Any]) -> Any? {
        let plugin = NewrelicMobilePlugin()
        let call = FlutterMethodCall(methodName: method, arguments: arguments)

        var received: Any?
        let resultExpectation = expectation(description: "result block must be called.")
        plugin.handle(call) { result in
            received = result
            resultExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)
        return received
    }
}
