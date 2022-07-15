import Flutter
import UIKit
import NewRelic
public class SwiftNewrelicMobilePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "newrelic_mobile", binaryMessenger: registrar.messenger())
    let instance = SwiftNewrelicMobilePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String : Any?]
      
      switch call.method {
            case "startAgent":
              let applicationToken = args?["applicationToken"] as? String
              let dartVersion = args?["dartVersion"] as? String
              NewRelic.setPlatform(NRMAApplicationPlatform.platform_Flutter)
              NewRelic.start(withApplicationToken:applicationToken!)
              NewRelic.setAttribute("DartVersion", value:dartVersion!)
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
              result(interactionId)
          case "endInteraction":
              let interactionId = args!["interactionId"] as? String
              
              NewRelic.stopCurrentInteraction(interactionId)
              result("interaction Ended")
      case "recordError":
          let exceptionMessage = args!["exception"] as? String
          let reason = args!["reason"] as? String
          let fatal = args!["fatal"] as? Bool
          let stackTraceElements = args!["stackTraceElements"] as! [[String : Any?]]
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

           default:
             result(FlutterMethodNotImplemented)
          
          
          
      }

      


    
    
  }
}
