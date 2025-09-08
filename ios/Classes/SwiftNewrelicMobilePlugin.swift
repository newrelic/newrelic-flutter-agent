/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Flutter
import NewRelic
import NewRelic.NRLogger
import UIKit

public class SwiftNewrelicMobilePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "newrelic_mobile",
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftNewrelicMobilePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any?]

        do {
            switch call.method {
            case "startAgent":
                let response = try startAgent(args: args)
                result(response)
            case "getPlatformVersion":
                let response = try getPlatformVersion()
                result(response)
            case "setUserId":
                let response = try setUserId(args: args)
            case "setAttribute":
                let response = try setAttribute(args: args)
                result(response)
            case "removeAttribute":
                let response = try removeAttribute(args: args)
                result(response)
            case "recordBreadcrumb":
                let response = try recordBreadcrumb(args: args)
                result(response)
            case "recordCustomEvent":
                let response = try recordCustomEvent(args: args)
                result(response)
            case "startInteraction":
                let response = try startInteraction(args: args)
                result(response)
            case "endInteraction":
                let response = try endInteraction(args: args)
                result(response)
            case "setMaxEventBufferTime":
                let response = try setMaxEventBufferTime(args: args)
                result(response)
            case "setMaxEventPoolSize":
                let response = try setMaxEventPoolSize(args: args)
                result(response)
            case "setMaxOfflineStorageSize":
                let response = try setMaxOfflineStorageSize(args: args)
                result(response)
            case "recordError":
                let response = try recordError(args: args)
                result(response)
            case "noticeDistributedTrace":
                let response = try noticeDistributedTrace()
                result(response)
            case "addHTTPHeadersTrackingFor":
                let response = try addHTTPHeadersTrackingFor(args: args)
                result(response)
            case "getHTTPHeadersTrackingFor":
                let response = try getHTTPHeadersTrackingFor()
                result(response)
            case "noticeHttpTransaction":
                let response = try noticeHttpTransaction(args: args)
                result(response)
            case "noticeNetworkFailure":
                let response = try noticeNetworkFailure(args: args)
                result(response)
            case "shutDown":
                let response = try shutDown()
                result(response)
            case "currentSessionId":
                let response = try currentSessionId()
                result(response)
            case "incrementAttribute":
                let response = try incrementAttribute(args: args)
                result(response)
            case "recordMetric":
                let response = try recordMetric(args: args)
                result(response)
            case "logAttributes":
                let response = try logAttributes(args: args)
                result(response)
            case "crashNow":
                let response = try crashNow(args: args)
                result(response)
            default:
                result(FlutterMethodNotImplemented)
                return
            }

        } catch let error as NewRelicPluginError {
            let flutterError = error.flutterError
            let attributes: [String: Any] = [
                "name": "NewRelicPluginError",
                "code": flutterError.code,
                "reason": flutterError.message ?? "",
                "fatal": false,
            ]
            NewRelic.recordHandledException(withStackTrace: attributes)
            result(flutterError)
        } catch {
            let error = NewRelicPluginError.unknownError(
                message:
                    "An unexpected error occurred: \(error.localizedDescription)"
            )
            result(error.flutterError)
        }
    }

    private func startAgent(args: [String: Any?]?) throws -> String {
        guard let applicationToken = args?["applicationToken"] as? String,
            !applicationToken.isEmpty
        else {
            throw NewRelicPluginError.invalidArgument(
                message: "applicationToken is required and cannot be empty"
            )
        }

        let dartVersion = args?["dartVersion"] as? String ?? "Unknown"
        var logLevel = NRLogLevelDebug.rawValue
        var collectorAddress: String? = nil
        var crashCollectorAddress: String? = nil

        // Safely handle boolean flags with default values
        let crashReportingEnabled =
            args?["crashReportingEnabled"] as? Bool ?? true
        let networkRequestEnabled =
            args?["networkRequestEnabled"] as? Bool ?? true
        let networkErrorRequestEnabled =
            args?["networkErrorRequestEnabled"] as? Bool ?? true
        let httpResponseBodyCaptureEnabled =
            args?["httpResponseBodyCaptureEnabled"] as? Bool ?? true
        let webViewInstrumentation =
            args?["webViewInstrumentation"] as? Bool ?? true
        let interactionTracingEnabled =
            args?["interactionTracingEnabled"] as? Bool ?? true
        let fedRampEnabled = args?["fedRampEnabled"] as? Bool ?? false
        let offlineStorageEnabled =
            args?["offlineStorageEnabled"] as? Bool ?? false
        let backgroundReportingEnabled =
            args?["backgroundReportingEnabled"] as? Bool ?? false
        let distributedTracingEnabled =
            args?["distributedTracingEnabled"] as? Bool ?? false
        let newEventSystemEnabled =
            args?["newEventSystemEnabled"] as? Bool ?? false
        let loggingEnabled = args?["loggingEnabled"] as? Bool ?? false

        if !crashReportingEnabled {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_CrashReporting
            )
        }
        if !networkRequestEnabled {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_NetworkRequestEvents
            )
        }
        if !networkErrorRequestEnabled {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_RequestErrorEvents
            )
        }
        if !httpResponseBodyCaptureEnabled {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_HttpResponseBodyCapture
            )
        }
        if !webViewInstrumentation {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_WebViewInstrumentation
            )
        }
        if !interactionTracingEnabled {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_DefaultInteractions
            )
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_InteractionTracing
            )
        }

        if fedRampEnabled {
            NewRelic.enableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_FedRampEnabled
            )
        }

        if offlineStorageEnabled {
            NewRelic.enableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_OfflineStorage
            )
        } else {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_OfflineStorage
            )
        }

        if let logLevelString = args?["logLevel"] as? String {
            let strToLogLevel = [
                "ERROR": NRLogLevelError.rawValue,
                "WARNING": NRLogLevelWarning.rawValue,
                "INFO": NRLogLevelInfo.rawValue,
                "VERBOSE": NRLogLevelVerbose.rawValue,
                "AUDIT": NRLogLevelAudit.rawValue,
                "DEBUG": NRLogLevelDebug.rawValue,
            ]

            if let configLogLevel = strToLogLevel[logLevelString] {
                logLevel = configLogLevel
            }
        }

        if backgroundReportingEnabled {
            NewRelic.enableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_BackgroundReporting
            )
        } else {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_BackgroundReporting
            )
        }

        if distributedTracingEnabled {
            NewRelic.enableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_DistributedTracing
            )
        } else {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_DistributedTracing
            )
        }

        if newEventSystemEnabled {
            NewRelic.enableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_NewEventSystem
            )
        } else {
            NewRelic.disableFeatures(
                NRMAFeatureFlags.NRFeatureFlag_NewEventSystem
            )
        }

        if loggingEnabled {
            NRLogger.setLogLevels(logLevel)
        }

        if let configCollectorAddress = args?["collectorAddress"] as? String,
            !configCollectorAddress.isEmpty
        {
            collectorAddress = configCollectorAddress
        }

        if let configCrashCollectorAddress = args?["crashCollectorAddress"]
            as? String, !configCrashCollectorAddress.isEmpty
        {
            crashCollectorAddress = configCrashCollectorAddress
        }

        NewRelic.setPlatform(NRMAApplicationPlatform.platform_Flutter)
        let selector = NSSelectorFromString("setPlatformVersion:")
        NewRelic.perform(selector, with: "1.1.12")

        if collectorAddress == nil && crashCollectorAddress == nil {
            NewRelic.start(withApplicationToken: applicationToken)
        } else {
            NewRelic.start(
                withApplicationToken: applicationToken,
                andCollectorAddress: collectorAddress ?? "mobile-collector.newrelic.com",
                andCrashCollectorAddress: crashCollectorAddress ?? "mobile-crash.newrelic.com"
            )
        }
        NewRelic.setAttribute("DartVersion", value: dartVersion)

        return "Agent Started"
    }

    private func getPlatformVersion() throws -> String {
        return "iOS " + UIDevice.current.systemVersion
    }

    private func setUserId(args: [String: Any?]?) throws -> Bool {
        guard let userId = args?["userId"] as? String, !userId.isEmpty else {
            throw NewRelicPluginError.invalidArgument(
                message: "userId is required and cannot be empty"
            )
        }
        return NewRelic.setUserId(userId)
    }

    private func setAttribute(args: [String: Any?]?) throws -> Bool {
        guard let name = args?["name"] as? String, !name.isEmpty else {
            throw NewRelicPluginError.invalidArgument(
                message: "name is required and cannot be empty"
            )
        }
        let value = args?["value"]
        return NewRelic.setAttribute(name, value: value as Any)
    }

    private func removeAttribute(args: [String: Any?]?) throws -> Bool {
        guard let name = args?["name"] as? String, !name.isEmpty else {
            throw NewRelicPluginError.invalidArgument(
                message: "name is required and cannot be empty"
            )
        }
        return NewRelic.removeAttribute(name)
    }

    private func recordBreadcrumb(args: [String: Any?]?) throws -> Bool {
        guard let name = args?["name"] as? String, !name.isEmpty else {
            throw NewRelicPluginError.invalidArgument(
                message: "name is required and cannot be empty"
            )
        }
        let eventAttributes = args?["eventAttributes"] as? [String: Any]
        return NewRelic.recordBreadcrumb(name, attributes: eventAttributes)
    }

    private func recordCustomEvent(args: [String: Any?]?) throws -> Bool {
        guard let eventType = args?["eventType"] as? String, !eventType.isEmpty
        else {
            throw NewRelicPluginError.invalidArgument(
                message: "eventType is required and cannot be empty"
            )
        }
        let eventName = args?["eventName"] as? String ?? ""
        let eventAttributes = args?["eventAttributes"] as? [String: Any]
        return NewRelic.recordCustomEvent(
            eventType,
            name: eventName,
            attributes: eventAttributes
        )
    }

    private func startInteraction(args: [String: Any?]?) throws -> String? {
        guard let actionName = args?["actionName"] as? String,
            !actionName.isEmpty
        else {
            throw NewRelicPluginError.invalidArgument(
                message: "actionName is required and cannot be empty"
            )
        }
        let interactionId = NewRelic.startInteraction(withName: actionName)
        print("interactionId" + (interactionId ?? ""))
        return interactionId
    }

    private func endInteraction(args: [String: Any?]?) throws -> String {
        guard let interactionId = args?["interactionId"] as? String,
            !interactionId.isEmpty
        else {
            throw NewRelicPluginError.invalidArgument(
                message: "interactionId is required and cannot be empty"
            )
        }
        NewRelic.stopCurrentInteraction(interactionId)
        return "interaction Ended"
    }

    private func setMaxEventBufferTime(args: [String: Any?]?) throws -> String {
        let maxBufferTimeInSec = args?["maxBufferTimeInSec"] as? UInt32 ?? 60
        NewRelic.setMaxEventBufferTime(maxBufferTimeInSec)
        return "maxBufferTimeInSec set"
    }

    private func setMaxEventPoolSize(args: [String: Any?]?) throws -> String {
        let maxSize = args?["maxSize"] as? UInt32 ?? 1000
        NewRelic.setMaxEventPoolSize(maxSize)
        return "maxSize set"
    }

    private func setMaxOfflineStorageSize(args: [String: Any?]?) throws
        -> String
    {
        let megaBytes = args?["megaBytes"] as? UInt32 ?? 100
        NewRelic.setMaxOfflineStorageSize(megaBytes)
        return "megaBytes set"
    }

    private func recordError(args: [String: Any?]?) throws -> String {
        let exceptionMessage =
            args?["exception"] as? String ?? "Unknown exception"
        let reason = args?["reason"] as? String ?? "Unknown reason"
        let fatal = args?["fatal"] as? Bool ?? false
        let stackTraceElements =
            args?["stackTraceElements"] as? [[String: Any]] ?? [[String: Any]]()
        let eventAttributes = args?["attributes"] as? [String: Any]

        var attributes: [String: Any] = [
            "name": exceptionMessage,
            "reason": reason,
            "cause": reason,
            "fatal": fatal,
            "stackTraceElements": stackTraceElements,
        ]

        if let eventAttributes = eventAttributes {
            attributes.merge(eventAttributes) { (current, _) in current }
        }
        NewRelic.recordHandledException(withStackTrace: attributes)

        return "return"
    }

    private func noticeDistributedTrace() throws -> [String: String] {
        return NewRelic.generateDistributedTracingHeaders()
    }

    private func addHTTPHeadersTrackingFor(args: [String: Any?]?) throws -> String {
        guard let headers = args?["headers"] as? [String], !headers.isEmpty
        else {
            throw NewRelicPluginError.invalidArgument(
                message: "headers array is required and cannot be empty"
            )
        }
        NewRelic.addHTTPHeaderTracking(for: headers)
        return "headers added"
    }

    private func getHTTPHeadersTrackingFor() throws -> [String] {
        return NewRelic.httpHeadersAddedForTracking()
    }

    private func noticeHttpTransaction(args: [String: Any?]?) throws -> Bool {
        guard let url = args?["url"] as? String, !url.isEmpty,
            let httpMethod = args?["httpMethod"] as? String,
            !httpMethod.isEmpty,
            let statusCode = args?["statusCode"] as? Int,
            let startTime = args?["startTime"] as? NSNumber,
            let endTime = args?["endTime"] as? NSNumber,
            let bytesSent = args?["bytesSent"] as? NSNumber,
            let bytesReceived = args?["bytesReceived"] as? NSNumber
        else {
            throw NewRelicPluginError.missingRequiredParameter(
                message:
                    "Required parameters for noticeHttpTransaction are missing or invalid"
            )
        }

        let responseBody = args?["responseBody"] as? String ?? ""
        let traceHeaders = args?["traceAttributes"] as? [String: Any] ?? [:]

        NewRelic.noticeNetworkRequest(
            for: URL.init(string: url),
            httpMethod: httpMethod,
            startTime: Double(truncating: startTime),
            endTime: Double(truncating: endTime),
            responseHeaders: nil,
            statusCode: statusCode,
            bytesSent: UInt(truncating: bytesSent),
            bytesReceived: UInt(truncating: bytesReceived),
            responseData: responseBody.data(using: .utf8),
            traceHeaders: traceHeaders,
            andParams: nil
        )

        return true
    }

    private func noticeNetworkFailure(args: [String: Any?]?) throws -> Bool {
        guard let url = args?["url"] as? String, !url.isEmpty,
            let httpMethod = args?["httpMethod"] as? String,
            !httpMethod.isEmpty,
            let startTime = args?["startTime"] as? NSNumber,
            let endTime = args?["endTime"] as? NSNumber,
            let errorCode = args?["errorCode"] as? NSNumber
        else {
            throw NewRelicPluginError.missingRequiredParameter(
                message:
                    "Required parameters for noticeNetworkFailure are missing or invalid"
            )
        }

        NewRelic.noticeNetworkFailure(
            for: URL.init(string: url),
            httpMethod: httpMethod,
            startTime: Double(truncating: startTime),
            endTime: Double(truncating: endTime),
            andFailureCode: Int(truncating: errorCode)
        )
        return true
    }

    private func shutDown() throws -> String {
        NewRelic.shutdown()
        return "agent is shutDown"
    }

    private func currentSessionId() throws -> String {
        return NewRelic.currentSessionId()
    }

    private func incrementAttribute(args: [String: Any?]?) throws -> Bool {
        guard let name = args?["name"] as? String, !name.isEmpty else {
            throw NewRelicPluginError.invalidArgument(
                message: "name is required and cannot be empty"
            )
        }
        let value = args?["value"] as? NSNumber

        if value == nil {
            return NewRelic.incrementAttribute(name)
        } else {
            return NewRelic.incrementAttribute(name, value: value!)
        }
    }

    private func recordMetric(args: [String: Any?]?) throws -> String {
        guard let name = args?["name"] as? String, !name.isEmpty,
            let category = args?["category"] as? String, !category.isEmpty
        else {
            throw NewRelicPluginError.invalidArgument(
                message: "name and category are required and cannot be empty"
            )
        }

        let value = args?["value"] as? NSNumber
        let countUnit = args?["countUnit"] as? String
        let valueUnit = args?["valueUnit"] as? String

        if let value = value, let countUnit = countUnit,
            let valueUnit = valueUnit
        {
            NewRelic.recordMetric(
                withName: name,
                category: category,
                value: value,
                valueUnits: valueUnit,
                countUnits: countUnit
            )
        } else if let value = value, let valueUnit = valueUnit {
            NewRelic.recordMetric(
                withName: name,
                category: category,
                value: value,
                valueUnits: valueUnit
            )
        } else if let value = value {
            NewRelic.recordMetric(
                withName: name,
                category: category,
                value: value
            )
        } else {
            NewRelic.recordMetric(withName: name, category: category)
        }

        return "Recorded Metrics"
    }

    private func logAttributes(args: [String: Any?]?) throws -> String {
        let attributes = args?["attributes"] as? [String: Any] ?? [:]
        NewRelic.logAttributes(attributes)
        return "log recorded"
    }

    private func crashNow(args: [String: Any?]?) throws -> String {
        let name = args?["name"] as? String
        NewRelic.crashNow(name)
        return "Crash triggered"
    }
}

enum NewRelicPluginError: Error {
    case invalidArgument(message: String)
    case missingRequiredParameter(message: String)
    case unknownError(message: String)

    var flutterError: FlutterError {
        switch self {
        case .invalidArgument(let message):
            return FlutterError(
                code: "INVALID_ARGUMENT",
                message: message,
                details: nil
            )
        case .missingRequiredParameter(let message):
            return FlutterError(
                code: "INVALID_ARGUMENT",
                message: message,
                details: nil
            )
        case .unknownError(let message):
            return FlutterError(
                code: "UNKNOWN_ERROR",
                message: message,
                details: nil
            )
        }
    }
}
