/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

package com.newrelic.newrelic_mobile

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.newrelic.agent.android.ApplicationFramework
import com.newrelic.agent.android.FeatureFlag
import com.newrelic.agent.android.HttpHeaders
import com.newrelic.agent.android.NewRelic
import com.newrelic.agent.android.logging.AgentLog
import com.newrelic.agent.android.logging.LogLevel
import com.newrelic.agent.android.metric.MetricUnit
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

    companion object {
        private const val AGENT_VERSION = "1.1.12"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "newrelic_mobile")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        try {
            when (call.method) {
                "getPlatformVersion" -> {
                    val response = getPlatformVersion()
                    result.success(response)
                }

                "startAgent" -> {
                    val response = startAgent(call)
                    result.success(response)
                }

                "setUserId" -> {
                    val response = setUserId(call)
                    result.success(response)
                }

                "setAttribute" -> {
                    val response = setAttribute(call)
                    result.success(response)
                }

                "removeAttribute" -> {
                    val response = removeAttribute(call)
                    result.success(response)
                }

                "recordBreadcrumb" -> {
                    val response = recordBreadcrumb(call)
                    result.success(response)
                }

                "recordCustomEvent" -> {
                    val response = recordCustomEvent(call)
                    result.success(response)
                }

                "startInteraction" -> {
                    val response = startInteraction(call)
                    result.success(response)
                }

                "endInteraction" -> {
                    val response = endInteraction(call)
                    result.success(response)
                }

                "setInteractionName" -> {
                    val response = setInteractionName(call)
                    result.success(response)
                }

                "recordError" -> {
                    val response = recordError(call)
                    result.success(response)
                }

                "noticeHttpTransaction" -> {
                    val response = noticeHttpTransaction(call)
                    result.success(response)
                }

                "noticeNetworkFailure" -> {
                    val response = noticeNetworkFailure(call)
                    result.success(response)
                }

                "noticeDistributedTrace" -> {
                    val response = noticeDistributedTrace()
                    result.success(response)
                }

                "setMaxEventBufferTime" -> {
                    val response = setMaxEventBufferTime(call)
                    result.success(response)
                }

                "setMaxEventPoolSize" -> {
                    val response = setMaxEventPoolSize(call)
                    result.success(response)
                }

                "setMaxOfflineStorageSize" -> {
                    val response = setMaxOfflineStorageSize(call)
                    result.success(response)
                }

                "incrementAttribute" -> {
                    val response = incrementAttribute(call)
                    result.success(response)
                }

                "recordMetric" -> {
                    val response = recordMetric(call)
                    result.success(response)
                }

                "shutDown" -> {
                    val response = shutDown()
                    result.success(response)
                }

                "currentSessionId" -> {
                    val response = currentSessionId()
                    result.success(response)
                }

                "addHTTPHeadersTrackingFor" -> {
                    val response = addHTTPHeadersTrackingFor(call)
                    result.success(response)
                }

                "getHTTPHeadersTrackingFor" -> {
                    val response = getHTTPHeadersTrackingFor()
                    result.success(response)
                }

                "logAttributes" -> {
                    val response = logAttributes(call)
                    result.success(response)
                }

                "crashNow" -> {
                    val response = crashNow(call)
                    result.success(response)
                }

                else -> result.notImplemented()
            }
        } catch (e: NewRelicPluginError) {
            result.error(e.code, e.message, null)
        } catch (e: Exception) {
            result.error("UNKNOWN_ERROR", "An unexpected error occurred: ${e.message}", null)
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

    private fun getPlatformVersion(): String {
        return "Android ${Build.VERSION.RELEASE}"
    }

    private fun startAgent(call: MethodCall): String {
        val applicationToken: String? = call.argument("applicationToken")
        if (applicationToken.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("applicationToken is required and cannot be empty")
        }

        val dartVersion: String? = call.argument("dartVersion") ?: "Unknown"
        val loggingEnabled: Boolean? = call.argument("loggingEnabled") ?: false
        val logLevel: String? = call.argument("logLevel") ?: "DEBUG"

        // Safely handle boolean flags with default values
        val analyticsEventEnabled = call.argument<Boolean>("analyticsEventEnabled") ?: true
        val networkRequestEnabled = call.argument<Boolean>("networkRequestEnabled") ?: true
        val networkErrorRequestEnabled =
            call.argument<Boolean>("networkErrorRequestEnabled") ?: true
        val httpResponseBodyCaptureEnabled =
            call.argument<Boolean>("httpResponseBodyCaptureEnabled") ?: true
        val crashReportingEnabled = call.argument<Boolean>("crashReportingEnabled") ?: true
        val interactionTracingEnabled = call.argument<Boolean>("interactionTracingEnabled") ?: true
        val fedRampEnabled = call.argument<Boolean>("fedRampEnabled") ?: false
        val backgroundReportingEnabled =
            call.argument<Boolean>("backgroundReportingEnabled") ?: false
        val offlineStorageEnabled = call.argument<Boolean>("offlineStorageEnabled") ?: false

        if (analyticsEventEnabled) {
            NewRelic.enableFeature(FeatureFlag.AnalyticsEvents)
        } else {
            NewRelic.disableFeature(FeatureFlag.AnalyticsEvents)
        }

        if (networkRequestEnabled) {
            NewRelic.enableFeature(FeatureFlag.NetworkRequests)
        } else {
            NewRelic.disableFeature(FeatureFlag.NetworkRequests)
        }
        if (networkErrorRequestEnabled) {
            NewRelic.enableFeature(FeatureFlag.NetworkErrorRequests)
        } else {
            NewRelic.disableFeature(FeatureFlag.NetworkErrorRequests)
        }

        if (httpResponseBodyCaptureEnabled) {
            NewRelic.enableFeature(FeatureFlag.HttpResponseBodyCapture)
        } else {
            NewRelic.disableFeature(FeatureFlag.HttpResponseBodyCapture)
        }

        if (crashReportingEnabled) {
            NewRelic.enableFeature(FeatureFlag.CrashReporting)
        } else {
            NewRelic.disableFeature(FeatureFlag.CrashReporting)
        }

        if (interactionTracingEnabled) {
            NewRelic.enableFeature(FeatureFlag.InteractionTracing)
            NewRelic.enableFeature(FeatureFlag.DefaultInteractions)
        } else {
            NewRelic.disableFeature(FeatureFlag.InteractionTracing)
            NewRelic.disableFeature(FeatureFlag.DefaultInteractions)
        }

        if (fedRampEnabled) {
            NewRelic.enableFeature(FeatureFlag.FedRampEnabled)
        } else {
            NewRelic.disableFeature(FeatureFlag.FedRampEnabled)
        }

        if (backgroundReportingEnabled) {
            NewRelic.enableFeature(FeatureFlag.BackgroundReporting)
        } else {
            NewRelic.disableFeature(FeatureFlag.BackgroundReporting)
        }

        if (offlineStorageEnabled) {
            NewRelic.enableFeature(FeatureFlag.OfflineStorage)
        } else {
            NewRelic.disableFeature(FeatureFlag.OfflineStorage)
        }

        val useDefaultCollectorAddress =
            call.argument<String>("collectorAddress") == null ||
                    call.argument<String>("collectorAddress")?.isEmpty() == true
        val useDefaultCrashCollectorAddress =
            call.argument<String>("crashCollectorAddress") == null ||
                    call.argument<String>("crashCollectorAddress")?.isEmpty() == true

        if (useDefaultCollectorAddress && useDefaultCrashCollectorAddress) {
            NewRelic.withApplicationToken(applicationToken)
                .withLoggingEnabled(loggingEnabled!!)
                .withLogLevel(AgentLog.VERBOSE)
                .withApplicationFramework(ApplicationFramework.Flutter, AGENT_VERSION)
                .start(context)
        } else {
            val collectorAddress =
                if (useDefaultCollectorAddress) "mobile-collector.newrelic.com" else call.argument<String>(
                    "collectorAddress"
                )!!
            val crashCollectorAddress =
                if (useDefaultCrashCollectorAddress) "mobile-crash.newrelic.com" else call.argument<String>(
                    "crashCollectorAddress"
                )!!
            NewRelic.withApplicationToken(applicationToken)
                .withApplicationFramework(ApplicationFramework.Flutter, AGENT_VERSION)
                .withLoggingEnabled(loggingEnabled!!)
                .withLogLevel(LogLevel.valueOf(logLevel!!).ordinal)
                .usingCollectorAddress(collectorAddress)
                .usingCrashCollectorAddress(crashCollectorAddress)
                .start(context)
        }

        NewRelic.setAttribute("DartVersion", dartVersion)
        StatsEngine.get().inc("Supportability/Mobile/Android/Flutter/Agent/$AGENT_VERSION")
        return "Agent Started"
    }

    private fun setUserId(call: MethodCall): Boolean {
        val userId: String? = call.argument("userId")
        if (userId.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("userId is required and cannot be empty")
        }
        return NewRelic.setUserId(userId)
    }

    private fun setAttribute(call: MethodCall): Boolean {
        val name: String? = call.argument("name")
        if (name.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("name is required and cannot be empty")
        }
        val value: Any? = call.argument("value")

        return when (value) {
            is String -> NewRelic.setAttribute(name, value)
            is Double -> NewRelic.setAttribute(name, value)
            is Boolean -> NewRelic.setAttribute(name, value)
            else -> false
        }
    }

    private fun removeAttribute(call: MethodCall): Boolean {
        val name: String? = call.argument("name")
        if (name.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("name is required and cannot be empty")
        }
        return NewRelic.removeAttribute(name)
    }

    private fun recordBreadcrumb(call: MethodCall): Boolean {
        val name: String? = call.argument("name")
        if (name.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("name is required and cannot be empty")
        }
        val eventAttributes: HashMap<String, Any>? = call.argument("eventAttributes")

        return NewRelic.recordBreadcrumb(name, eventAttributes)
    }

    private fun recordCustomEvent(call: MethodCall): Boolean {
        val eventType: String? = call.argument("eventType")
        if (eventType.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("eventType is required and cannot be empty")
        }
        val eventName: String? = call.argument("eventName") ?: ""
        val eventAttributes: HashMap<String, Any>? = call.argument("eventAttributes")

        return if (eventAttributes == null) {
            NewRelic.recordCustomEvent(eventType, eventName, null)
        } else {
            val copyOfEventAttributes = eventAttributes.clone() as HashMap<*, *>
            for (key in copyOfEventAttributes.keys) {
                val value = copyOfEventAttributes[key]
                if (value is HashMap<*, *>) {
                    for (k in value.keys) {
                        value[k]?.let { eventAttributes.put(k as String, it) }
                    }
                    eventAttributes.remove(key)
                }
            }
            NewRelic.recordCustomEvent(eventType, eventName, eventAttributes)
        }
    }

    private fun startInteraction(call: MethodCall): String? {
        val actionName: String? = call.argument("actionName")
        if (actionName.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("actionName is required and cannot be empty")
        }

        return NewRelic.startInteraction(actionName)
    }

    private fun endInteraction(call: MethodCall): String {
        val interactionId: String? = call.argument("interactionId")
        if (interactionId.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("interactionId is required and cannot be empty")
        }

        NewRelic.endInteraction(interactionId)
        return "interaction Ended"
    }

    private fun setInteractionName(call: MethodCall): String {
        val interactionName: String? = call.argument("interactionName")
        if (interactionName.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("interactionName is required and cannot be empty")
        }

        NewRelic.setInteractionName(interactionName)
        return "interaction Recorded"
    }

    private fun recordError(call: MethodCall): Boolean {
        val exceptionMessage: String? = call.argument("exception") ?: "Unknown exception"
        val reason: String? = call.argument("reason") ?: "Unknown reason"
        val fatal: Boolean? = call.argument("fatal") ?: false
        val attributes: HashMap<String, Any>? = call.argument("attributes")

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
        return NewRelic.recordHandledException(exception, exceptionAttributes)
    }

    private fun noticeHttpTransaction(call: MethodCall): String {
        val url: String? = call.argument("url")
        val httpMethod: String? = call.argument("httpMethod")
        val statusCode: Int? = call.argument("statusCode")
        val startTime: Long? = call.argument("startTime")
        val endTime: Long? = call.argument("endTime")
        val bytesSent: Long? = call.argument("bytesSent")
        val bytesReceived: Long? = call.argument("bytesReceived")

        if (url.isNullOrEmpty() || httpMethod.isNullOrEmpty() || statusCode == null || startTime == null || endTime == null || bytesSent == null || bytesReceived == null) {
            throw NewRelicPluginError.MissingRequiredParameter("Required parameters for noticeHttpTransaction are missing or invalid")
        }

        val responseBody: String? = call.argument("responseBody") ?: ""
        val traceAttributes: HashMap<String, Any>? = call.argument("traceAttributes")
        val params: HashMap<String, String>? = call.argument("params")

        NewRelic.noticeHttpTransaction(
            url,
            httpMethod,
            statusCode,
            startTime,
            endTime,
            bytesSent,
            bytesReceived,
            responseBody,
            params,
            null,
            traceAttributes
        )
        return "Http Transaction Recorded"
    }

    private fun noticeNetworkFailure(call: MethodCall): String {
        val url: String? = call.argument("url")
        val httpMethod: String? = call.argument("httpMethod")
        val startTime: Long? = call.argument("startTime")
        val endTime: Long? = call.argument("endTime")
        val errorCode: Int? = call.argument("errorCode")

        if (url.isNullOrEmpty() || httpMethod.isNullOrEmpty() || startTime == null || endTime == null || errorCode == null) {
            throw NewRelicPluginError.MissingRequiredParameter("Required parameters for noticeNetworkFailure are missing or invalid")
        }

        val nf = NetworkFailure.fromErrorCode(errorCode)

        NewRelic.noticeNetworkFailure(
            url,
            httpMethod,
            startTime,
            endTime,
            nf
        )
        return "Network Failure Recorded"
    }

    private fun noticeDistributedTrace(): HashMap<String, Any> {
        val traceContext = NewRelic.noticeDistributedTrace(null)

        val traceAttributes = HashMap<String, Any>()

        traceAttributes.putAll(traceContext.asTraceAttributes())

        for (header in traceContext.headers) {
            traceAttributes[header.headerName] = header.headerValue
        }
        return traceAttributes
    }

    private fun setMaxEventBufferTime(call: MethodCall): String {
        val maxBufferTimeInSec: Int? = call.argument("maxBufferTimeInSec") ?: 60

        NewRelic.setMaxEventBufferTime(maxBufferTimeInSec)
        return "MaxEvent BufferTime set"
    }

    private fun setMaxEventPoolSize(call: MethodCall): String {
        val maxSize: Int? = call.argument("maxSize") ?: 1000

        NewRelic.setMaxEventPoolSize(maxSize)
        return "maxSize set"
    }

    private fun setMaxOfflineStorageSize(call: MethodCall): String {
        val megaBytes: Int? = call.argument("megaBytes") ?: 100

        NewRelic.setMaxOfflineStorageSize(megaBytes)
        return "megaBytes set"
    }

    private fun incrementAttribute(call: MethodCall): Boolean {
        val name: String? = call.argument("name")
        if (name.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("name is required and cannot be empty")
        }
        val value: Double? = call.argument("value")

        return if (value != null) {
            NewRelic.incrementAttribute(name, value)
        } else {
            NewRelic.incrementAttribute(name)
        }
    }

    private fun recordMetric(call: MethodCall): String {
        val name: String? = call.argument("name")
        val category: String? = call.argument("category")

        if (name.isNullOrEmpty() || category.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("name and category are required and cannot be empty")
        }

        val value: Double? = call.argument("value") as Double?
        val countUnit: String? = call.argument("countUnit") as String?
        val valueUnit: String? = call.argument("valueUnit") as String?

        value?.let {
            NewRelic.recordMetric(
                name, category,
                1, it, 0.0,
                countUnit?.let { it2 -> MetricUnit.valueOf(it2) },
                valueUnit?.let { it3 -> MetricUnit.valueOf(it3) })
        } ?: run {
            NewRelic.recordMetric(name, category)
        }
        return "Recorded Metric"
    }

    private fun shutDown(): String {
        NewRelic.shutdown()
        return "agent is shutDown"
    }

    private fun currentSessionId(): String? {
        return NewRelic.currentSessionId()
    }

    private fun addHTTPHeadersTrackingFor(call: MethodCall): Boolean {
        val headers: ArrayList<String>? = call.argument("headers") as ArrayList<String>?
        if (headers.isNullOrEmpty()) {
            throw NewRelicPluginError.InvalidArgument("headers array is required and cannot be empty")
        }
        return NewRelic.addHTTPHeadersTrackingFor(headers)
    }

    private fun getHTTPHeadersTrackingFor(): List<String> {
        return HttpHeaders.getInstance().httpHeaders.toList()
    }

    private fun logAttributes(call: MethodCall): String {
        val attributes: HashMap<String, Any>? = call.argument("attributes") ?: HashMap()
        NewRelic.logAttributes(attributes)
        return "Recorded Log"
    }

    private fun crashNow(call: MethodCall): String {
        val name: String? = call.argument("name") ?: "NewRelic Demo Crash"
        Looper.myLooper()?.let {
            Handler(it).postDelayed({ throw RuntimeException(name) }, 50)
        }
        return "Crash Recorded"
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

sealed class NewRelicPluginError(val code: String, val message: String) : Exception(message) {
    class InvalidArgument(message: String) : NewRelicPluginError("INVALID_ARGUMENT", message)
    class MissingRequiredParameter(message: String) :
        NewRelicPluginError("INVALID_ARGUMENT", message)

    class UnknownError(message: String) : NewRelicPluginError("UNKNOWN_ERROR", message)
}
