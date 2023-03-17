/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

package com.newrelic.newrelic_mobile

import android.content.Context
import androidx.annotation.NonNull
import com.newrelic.agent.android.ApplicationFramework
import com.newrelic.agent.android.FeatureFlag
import com.newrelic.agent.android.NewRelic
import com.newrelic.agent.android.stats.StatsEngine
import com.newrelic.agent.android.util.NetworkFailure
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** NewrelicMobilePlugin */
class NewrelicMobilePlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

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
                val loggingEnabled: Boolean? = call.argument("loggingEnabled")


                if (call.argument<Boolean>("analyticsEventEnabled") as Boolean) {
                    NewRelic.enableFeature(FeatureFlag.AnalyticsEvents)
                } else {
                    NewRelic.disableFeature(FeatureFlag.AnalyticsEvents)
                }

                if (call.argument<Boolean>("networkRequestEnabled") as Boolean) {
                    NewRelic.enableFeature(FeatureFlag.NetworkRequests)
                } else {
                    NewRelic.disableFeature(FeatureFlag.NetworkRequests)
                }
                if (call.argument<Boolean>("networkErrorRequestEnabled") as Boolean) {
                    NewRelic.enableFeature(FeatureFlag.NetworkErrorRequests)
                } else {
                    NewRelic.disableFeature(FeatureFlag.NetworkErrorRequests)
                }

                if (call.argument<Boolean>("httpResponseBodyCaptureEnabled") as Boolean) {
                    NewRelic.enableFeature(FeatureFlag.HttpResponseBodyCapture)
                } else {
                    NewRelic.disableFeature(FeatureFlag.HttpResponseBodyCapture)
                }

                if (call.argument<Boolean>("crashReportingEnabled") as Boolean) {
                    NewRelic.enableFeature(FeatureFlag.CrashReporting)
                } else {
                    NewRelic.disableFeature(FeatureFlag.CrashReporting)
                }

                if (call.argument<Boolean>("interactionTracingEnabled") as Boolean) {
                    NewRelic.enableFeature(FeatureFlag.InteractionTracing)
                } else {
                    NewRelic.disableFeature(FeatureFlag.InteractionTracing)
                }

                NewRelic.withApplicationToken(
                    applicationToken
                ).withLoggingEnabled(loggingEnabled!!)
                    .withLogLevel(5)
                    .withApplicationFramework(ApplicationFramework.Flutter, "3.0.0").start(context)
                NewRelic.setAttribute("DartVersion", dartVersion)
                StatsEngine.get().inc("Supportability/Mobile/Android/Flutter/Agent/0.0.1-dev.11");
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
                val reason: String? = call.argument("reason")
                val fatal: Boolean? = call.argument("fatal")
                val attributes: Map<String, Any>? = call.argument("attributes")

                val exceptionAttributes: MutableMap<String, Any?> = mutableMapOf()
                exceptionAttributes["reason"] = reason
                exceptionAttributes["isFatal"] = fatal
                if (attributes != null) {
                    exceptionAttributes.putAll(attributes)
                }

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
                val bool = NewRelic.recordHandledException(exception, exceptionAttributes)
                result.success(bool)
            }
            "noticeHttpTransaction" -> {

                val url: String = call.argument("url")!!
                val httpMethod: String = call.argument("httpMethod")!!
                val statusCode: Int = call.argument("statusCode")!!
                val startTime: Long = call.argument("startTime")!!
                val endTime: Long = call.argument("endTime")!!
                val bytesSent: Long = call.argument("bytesSent")!!
                val bytesReceived: Long = call.argument("bytesReceived")!!
                val responseBody: String? = call.argument("responseBody")!!
                val traceAttributes: HashMap<String, Any>? = call.argument("traceAttributes")

                NewRelic.noticeHttpTransaction(
                    url,
                    httpMethod,
                    statusCode,
                    startTime,
                    endTime,
                    bytesSent,
                    bytesReceived,
                    responseBody,
                    null,
                    null,
                    traceAttributes
                )
                result.success("Http Transcation Recorded")

            }
            "noticeNetworkFailure" -> {

                val url: String = call.argument("url")!!
                val httpMethod: String = call.argument("httpMethod")!!
                val startTime: Long = call.argument("startTime")!!
                val endTime: Long = call.argument("endTime")!!
                val errorCode:Int = call.argument("errorCode")!!

                val nf = NetworkFailure.fromErrorCode(errorCode);

                NewRelic.noticeNetworkFailure(
                    url,
                    httpMethod,
                    startTime,
                    endTime,
                    nf)
                result.success("Network Failure Recorded")

            }
            "noticeDistributedTrace" -> {

                val traceContext = NewRelic.noticeDistributedTrace(null);

                val traceAttributes = HashMap<String, Any>();

                traceAttributes.putAll(traceContext.asTraceAttributes());

                for (header in traceContext.headers) {
                    traceAttributes[header.headerName] = header.headerValue;
                }
                result.success(traceAttributes);
            }
            "setMaxEventBufferTime" -> {
                val maxBufferTimeInSec: Int? = call.argument("maxBufferTimeInSec")

                if (maxBufferTimeInSec != null) {
                    NewRelic.setMaxEventBufferTime(maxBufferTimeInSec)
                }
                result.success("MaxEvent BufferTime set")
            }
            "setMaxEventPoolSize" -> {
                val maxSize: Int? = call.argument("maxSize")

                if (maxSize != null) {
                    NewRelic.setMaxEventPoolSize(maxSize)
                }
                result.success("maxSize set")

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


    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}


