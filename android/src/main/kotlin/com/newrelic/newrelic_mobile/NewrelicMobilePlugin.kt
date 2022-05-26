package com.newrelic.newrelic_mobile

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import androidx.annotation.NonNull
import com.newrelic.agent.android.ApplicationFramework
import com.newrelic.agent.android.NewRelic
import com.newrelic.agent.android.stats.StatsEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.ArrayList

/** NewrelicMobilePlugin */
class NewrelicMobilePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var activity: Activity

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "newrelic_mobile")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) =
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "startAgent" -> {

                val applicationToken: String? = call.argument("applicationToken")
                val dartVersion: String? = call.argument("dartVersion")
                NewRelic.withApplicationToken(
                    applicationToken
                ).withApplicationFramework(ApplicationFramework.Flutter,"2.0.3").start(context)

                NewRelic.setAttribute("DartVersion", dartVersion)
                StatsEngine.get().inc("Supportability/Mobile/Android/Flutter/Agent/0.0.1");
                result.success("Agent Started")
            }
            "setUserId" -> {
                val userId: String? = call.argument("userId")
                val userIsSet = NewRelic.setUserId(userId)
                result.success(userIsSet)
            }
            "setAttribute" -> {
                val name: String? = call.argument("name")
                val value: Any? = call.argument("value")

                var attributeIsSet = false
                when (value) {
                    is String -> {
                        attributeIsSet = NewRelic.setAttribute(name, value)
                    }
                    is Double -> {
                        attributeIsSet = NewRelic.setAttribute(name, value)
                    }
                    is Boolean -> {
                        attributeIsSet = NewRelic.setAttribute(name, value)
                    }
                }
                result.success(attributeIsSet)
            }
            "removeAttribute" -> {
                val name: String? = call.argument("name")
                val attributeIsRemoved = NewRelic.removeAttribute(name)
                result.success(attributeIsRemoved)
            }
            "recordBreadcrumb" -> {
                val name: String? = call.argument("name")
                val eventAttributes: Map<String, Any>? = call.argument("eventAttributes")

                val eventRecorded = NewRelic.recordBreadcrumb(name, eventAttributes);
                result.success(eventRecorded)
            }
            "recordCustomEvent" -> {
                val eventType: String? = call.argument("eventType")
                val eventName: String? = call.argument("eventName")
                val eventAttributes: Map<String, Any>? = call.argument("eventAttributes")

                val eventRecorded =
                    NewRelic.recordCustomEvent(eventType, eventName, eventAttributes);
                result.success(eventRecorded)
            }
            "startInteraction" -> {
                val actionName: String? = call.argument("actionName")

                val interactionId = NewRelic.startInteraction(actionName);
                result.success(interactionId)
            }
            "endInteraction" -> {
                val interactionId: String? = call.argument("interactionId")

                NewRelic.endInteraction(interactionId)
                result.success("interaction Ended")
            }
            "setInteractionName" -> {
                val interactionName: String? = call.argument("interactionName")

                NewRelic.setInteractionName(interactionName)
                result.success("interaction Recorded")
            }
            "recordError" -> {

              val exceptionMessage: String? = call.argument("exception")
              val reason:String? = call.argument("reason")
              val fatal:Boolean? = call.argument("fatal")

              val exceptionAttributes = mapOf("reason" to reason,"fatal" to fatal)

              val exception = FlutterError(exceptionMessage)

              val elements: MutableList<StackTraceElement> = ArrayList()
              val errorElements: List<Map<String, String>>? =
                call.argument("stackTraceElements")

              if (errorElements != null) {
                for (errorElement in errorElements) {
                  val stackTraceElement = generateStackTraceElement(errorElement)
                  if (stackTraceElement != null) {
                    elements.add(stackTraceElement)
                  }
                }
              }
              exception.stackTrace = elements.toTypedArray()
              val bool = NewRelic.recordHandledException(exception,exceptionAttributes)
              result.success(bool)
            } "noticeHttpTransaction" -> {

            val url: String = call.argument("url")!!
            val httpMethod: String = call.argument("httpMethod")!!
            val statusCode: Int = call.argument("statusCode")!!
            val startTime: Long = call.argument("startTime")!!
            val endTime: Long = call.argument("endTime")!!
            val bytesSent: Long = call.argument("bytesSent")!!
            val bytesReceived: Long = call.argument("bytesReceived")!!
            val responseBody: String? = call.argument("responseBody")!!

            NewRelic.noticeHttpTransaction(url, httpMethod, statusCode,startTime,endTime,bytesSent,bytesReceived,responseBody)
            result.success("Http Transcation Recorded")

            }
            else -> {
                result.notImplemented()
            }
        }

  private fun generateStackTraceElement(errorElement: Map<String, String>): StackTraceElement? {
    return try {
      val fileName = errorElement["file"]
      val lineNumber: String? = errorElement["line"]
      val className = errorElement["class"]
      val methodName = errorElement["method"]
      lineNumber?.let {
        StackTraceElement(
          className ?: "",
          methodName,
          fileName, it.toInt()
        )
      }
    } catch (e: Exception) {
      NewRelic.recordHandledException(e)
      null
    }
  }

    override fun onDetachedFromActivity() {
        TODO("Not yet implemented")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        TODO("Not yet implemented")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity;
    }

    override fun onDetachedFromActivityForConfigChanges() {
        TODO("Not yet implemented")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}


