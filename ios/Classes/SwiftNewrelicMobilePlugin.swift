/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Flutter
import UIKit
import NewRelic
import NewRelic.NRLogger
public class SwiftNewrelicMobilePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "newrelic_mobile", binaryMessenger: registrar.messenger())
        let instance = SwiftNewrelicMobilePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)  {
        let args = call.arguments as? [String : Any?]

        switch call.method {
        case "startAgent":
            let applicationToken = args?["applicationToken"] as? String
            let dartVersion = args?["dartVersion"] as? String

            if(args?["crashReportingEnabled"] as! Bool == false) {
                NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_CrashReporting)
            }
            if(args?["networkRequestEnabled"] as! Bool == false) {
                NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_NetworkRequestEvents)
            }
            if(args?["networkErrorRequestEnabled"] as! Bool == false) {
                NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_RequestErrorEvents)
            }
            if(args?["httpResponseBodyCaptureEnabled"] as! Bool == false) {
                NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_HttpResponseBodyCapture)
            }
            if(args?["webViewInstrumentation"] as! Bool == false) {
                NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_WebViewInstrumentation)
            }
            if(args?["interactionTracingEnabled"] as! Bool == false) {
                NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_InteractionTracing)
            }

            if(args?["loggingEnabled"] as! Bool == true) {
                NRLogger.setLogLevels(NRLogLevelALL.rawValue)
            }


            NewRelic.setPlatform(NRMAApplicationPlatform.platform_Flutter)
            NewRelic.start(withApplicationToken:applicationToken!)
                          NewRelic.setAttribute("DartVersion", value:dartVersion!)
                          NewRelic.recordMetric(withName: "Mobile/iOS/Flutter/Agent/0.0.1-dev.7", category: "Supportability", value: 1)


            result("Agent Started")
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "setUserId":
            let userId = args?["userId"] as? String
            let userIsSet = NewRelic.setUserId(userId!)
            result(userIsSet)
        case "setAttribute":
            let name = args?["name"] as? String
            let value = args?["value"]

            let attributeIsSet = NewRelic.setAttribute(name!, value: value as Any)
            result(attributeIsSet)
        case "removeAttribute":
            let name = args?["name"] as? String

            let attributeIsRemoved = NewRelic.removeAttribute(name!)
            result(attributeIsRemoved)
        case "recordBreadcrumb":
            let name = args!["name"] as? String
            let eventAttributes = args?["eventAttributes"] as?[String : Any]

            let eventRecorded = NewRelic.recordBreadcrumb(name!, attributes: eventAttributes)
            result(eventRecorded)
        case "recordCustomEvent":
            let eventType = args!["eventType"] as? String
            let eventName = args!["eventName"] as? String
            let eventAttributes = args?["eventAttributes"] as? [String : Any]
            let eventRecorded = NewRelic.recordCustomEvent(eventType!, name: eventName!, attributes: eventAttributes)
            result(eventRecorded)
        case "startInteraction":
            let actionName = args!["actionName"] as? String

            let interactionId = NewRelic.startInteraction(withName: actionName)
            print("interactionId" + (interactionId ?? ""))
            result(interactionId)
        case "endInteraction":
            let interactionId = args!["interactionId"] as? String

            NewRelic.stopCurrentInteraction(interactionId)
            result("interaction Ended")
        case "setMaxEventBufferTime":
            let maxBufferTimeInSec = args!["maxBufferTimeInSec"] as? UInt32

            NewRelic.setMaxEventBufferTime(maxBufferTimeInSec ?? 60)
            result("maxBufferTimeInSec set")
        case "setMaxEventPoolSize":
            let maxSize = args!["maxSize"] as? UInt32

            NewRelic.setMaxEventPoolSize(maxSize ?? 4000)
            result("maxSize set")
        case "recordError":
            let exceptionMessage = args!["exception"] as? String
            let reason = args!["reason"] as? String
            let fatal = args!["fatal"] as? Bool
            let stackTraceElements = args!["stackTraceElements"] as? [[String : Any]] ?? [[String : Any]]()
            let version = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "1.0.0"

            let attributes: [String:Any] = [
                "name": exceptionMessage ?? "Exception name not found",
                "reason": reason ?? "Reason not found",
                "cause": reason ?? "Reason not found",
                "fatal": fatal ?? false,
                "stackTraceElements": stackTraceElements,
                "appBuild": version,
                "appVersion": version
            ]

            NewRelic.recordHandledException(withStackTrace: attributes)

            result("return")

        case "noticeDistributedTrace":

            result(NewRelic.generateDistributedTracingHeaders())

        case "noticeHttpTransaction":

            let url = args!["url"] as! String
            let httpMethod = args!["httpMethod"] as! String
            let statusCode = args!["statusCode"] as! Int
            let startTime = args!["startTime"] as! NSNumber
            let endTime = args!["endTime"] as! NSNumber
            let bytesSent = args!["bytesSent"] as! NSNumber
            let bytesReceived = args!["bytesReceived"] as! NSNumber
            let responseBody = args!["responseBody"] as! NSString
            let traceHeaders = args?["traceAttributes"] as! [String : Any]

            NewRelic.noticeNetworkRequest(for: URL.init(string: url), httpMethod: httpMethod, startTime: Double(truncating: startTime), endTime: Double(truncating: endTime), responseHeaders: nil, statusCode: statusCode, bytesSent: UInt(truncating: bytesSent), bytesReceived: UInt(truncating: bytesReceived), responseData: responseBody.data(using: String.Encoding.utf8.rawValue), traceHeaders: traceHeaders, andParams: nil)
            result(true)

        case "noticeNetworkFailure":

            let url = args!["url"] as! String
            let httpMethod = args!["httpMethod"] as! String
            let startTime = args!["startTime"] as! NSNumber
            let endTime = args!["endTime"] as! NSNumber
            let errorCode = args!["errorCode"] as! NSNumber



            NewRelic.noticeNetworkFailure(for: URL.init(string: url), httpMethod: httpMethod, startTime: Double(truncating: startTime), endTime: Double(truncating: endTime), andFailureCode: Int(truncating: errorCode))
            result(true)
    
        case "shutDown":
            
            NewRelic.shutdown();
            result("agent is shutDown")
        case "currentSessionId":
            
            result(NewRelic.currentSessionId())
        case "incrementAttribute":
            
            let name = args!["name"] as! String
            let value = args!["value"] as? NSNumber
            
            var isIncreased = false
            
            if(value == nil) {
                isIncreased = NewRelic.incrementAttribute(name)
            } else {
                isIncreased = NewRelic.incrementAttribute(name,value: value!)
            }
        
            result(isIncreased)
            
        case "recordMetric":
            
            let name = args!["name"] as! String
            let category = args!["category"] as! String
            let value = args!["value"] as! NSNumber?
            let countUnit = args!["countUnit"] as! String?
            let valueUnit = args!["valueUnit"] as! String?
            
            if(value != nil  && countUnit != nil && valueUnit != nil) {
                NewRelic.recordMetric(withName: name, category: category, value: value!, valueUnits: valueUnit,countUnits: countUnit)
            } else if (value != nil  && valueUnit != nil ) {
                NewRelic.recordMetric(withName: name, category: category, value: value!,valueUnits: valueUnit)
            }else if (value != nil  ) {
                NewRelic.recordMetric(withName: name, category: category, value: value!)
            } else {
                NewRelic.recordMetric(withName: name, category: category)
            }
                        
            result("Recorded Metrics")
            


        default:
            result(FlutterMethodNotImplemented)



        }






    }
}
