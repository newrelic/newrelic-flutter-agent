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
          let eventAttributes = args?["eventAttributes"] as! [String : Any]

           let eventRecorded = NewRelic.recordBreadcrumb(name!, attributes: eventAttributes)
           result(eventRecorded)
          case "recordCustomEvent":
           let eventType = args!["eventType"] as? String
           let eventName = args!["eventName"] as? String
           let eventAttributes = args!["eventAttributes"] as! [String : Any]
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
          let stackTrace = args!["stackTrace"] as? String
          
          let attributes: [String:Any] = ["exceptionMessage":exceptionMessage!,"stackTrace":stackTrace!]
          NewRelic.recordCustomEvent("Dart Errors", attributes:attributes)
          result("return");
      case "noticeHttpTransaction":
          
          let url = args!["url"] as! String
          let httpMethod = args!["httpMethod"] as! String
          let statusCode = args!["statusCode"] as! Int
          let startTime = args!["startTime"] as! NSNumber
          let endTime = args!["endTime"] as! NSNumber
          let bytesSent = args!["bytesSent"] as! NSNumber
          let bytesReceived = args!["bytesReceived"] as! NSNumber
          let responseBody = args!["responseBody"] as! NSString
          
          
          NewRelic.noticeNetworkRequest(for: URL.init(string: url), httpMethod: httpMethod, startTime: Double(truncating: startTime), endTime: Double(truncating: endTime), responseHeaders: nil, statusCode: statusCode, bytesSent: UInt(truncating: bytesSent), bytesReceived: UInt(truncating: bytesReceived), responseData: responseBody.data(using: String.Encoding.utf8.rawValue), andParams: nil)

//          NewRelic.noticeNetworkRequest(for: URL.init(string: url), httpMethod: httpMethod,with:nil,responseHeaders:nil, statusCode: statusCode, bytesSent: bytesSent, bytesReceived: bytesReceived,responseData:NSKeyedArchiver.archivedData(withRootObject: responseBody),andParams:nil)
          result(true)
        

           default:
             result(FlutterMethodNotImplemented)
          
          
          
      }

      


    
    
  }
}
