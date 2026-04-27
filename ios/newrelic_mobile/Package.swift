// swift-tools-version: 5.9
/*
 * Copyright (c) 2024-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import PackageDescription

let package = Package(
    name: "newrelic_mobile",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "newrelic-mobile", targets: ["newrelic_mobile"])
    ],
    dependencies: [
        .package(url: "https://github.com/newrelic/newrelic-ios-agent-spm", from: "7.7.1")
    ],
    targets: [
        .target(
            name: "newrelic_mobile",
            dependencies: [
                .product(name: "NewRelic", package: "newrelic-ios-agent-spm")
            ],
            publicHeadersPath: "."
        )
    ]
)
