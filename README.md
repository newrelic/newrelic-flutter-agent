[![Community Plus header](https://github.com/newrelic/opensource-website/raw/main/src/images/categories/Community_Plus.png)](https://opensource.newrelic.com/oss-category/#community-plus)

# New Relic Flutter Agent 
[![Pub](https://img.shields.io/pub/v/newrelic_mobile)](https://pub.dev/packages/newrelic_mobile)

This agent allows you to instrument Flutter apps with help of native New Relic Android and iOS
agents. The New Relic SDKs collect crashes, network traffic, and other information for hybrid apps
using native components.


## Features

* Capture Dart errors
* Network Request tracking
* Distributed Tracing
* Future errors tracking
* Capture interactions and the sequence in which they were created
* Pass user information to New Relic to track user sessions
* Screen tracking via NavigationObserver
* Capture print and debug print statement as CustomEvents

## Current Support:

- Android API 24+
- iOS 10
- Depends on New Relic iOS/XCFramework and Android agents

## Requirements

- Flutter ">= 2.5.0"
- Dart ">=2.16.2 <4.0.0"
- [IOS native requirements](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/get-started/new-relic-ios-compatibility-requirements)
- [Android native requirements](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/get-started/new-relic-android-compatibility-requirements)

## Installation

Install NewRelic plugin into your dart project by adding it to dependecies in your pubspec.yaml

```yaml

dependencies:
  newrelic_mobile: 1.0.3
  
```

## Flutter Setup

1. Now open your `main.dart` and add the following code to launch NewRelic (don't forget to put proper
application tokens):

```dart

import 'package:newrelic_mobile/newrelic_mobile.dart';


  var appToken = "";

  if (Platform.isAndroid) {
    appToken = "<android app token>";
  } else if (Platform.isIOS) {
    appToken = "<ios app token>";
  }

  Config config =
      Config(accessToken: appToken,

      //Android Specific
      // Optional:Enable or disable collection of event data.
      analyticsEventEnabled: true,

      // Optional:Enable or disable reporting successful HTTP requests to the MobileRequest event type.
      networkErrorRequestEnabled: true,

      // Optional:Enable or disable reporting network and HTTP request errors to the MobileRequestError event type.
      networkRequestEnabled: true,

      // Optional:Enable or disable crash reporting.
      crashReportingEnabled: true,

      // Optional:Enable or disable interaction tracing. Trace instrumentation still occurs, but no traces are harvested. This will disable default and custom interactions.
      interactionTracingEnabled: true,

      // Optional:Enable or disable capture of HTTP response bodies for HTTP error traces, and MobileRequestError events.
       httpResponseBodyCaptureEnabled: true,

      // Optional: Enable or disable agent logging.
      loggingEnabled: true,

      //iOS Specific
      // Optional:Enable/Disable automatic instrumentation of WebViews
      webViewInstrumentation: true,
      
      //Optional: Enable or Disable Print Statements as Analytics Events
      printStatementAsEventsEnabled : true,

       // Optional:Enable/Disable automatic instrumentation of Http Request
      httpInstrumentationEnabled:true,

      // Optional : Enable or disable reporting data using different endpoints for US government clients
      fedRampEnabled: false  
      );

  NewrelicMobile.instance.start(config, () {
    runApp(MyApp());
  });

  class MyApp extends StatelessWidget {
  ....


```
2. Alternatively, you can manually set up error tracking and resource tracking. Because NewRelic Mobile Start calls WidgetsFlutterBinding.ensureInitialized, if you are not using NewRelic Mobile Start, you need to call this method prior to calling NewrelicMobile.instance.startAgent.

```dart
if (Platform.isAndroid) {
  appToken = AppConfig.androidToken;
} else if (Platform.isIOS) {
  appToken = AppConfig.iOSToken;
}

Config config = Config(
    accessToken: appToken,
    analyticsEventEnabled: true,
    networkErrorRequestEnabled: true,
    networkRequestEnabled: true,
    crashReportingEnabled: true,
    interactionTracingEnabled: true,
    httpResponseBodyCaptureEnabled: true,
    loggingEnabled: true,
    webViewInstrumentation: true,
    printStatementAsEventsEnabled: true,
    httpInstrumentationEnabled:true);

// NewrelicMobile.instance.start(config, () {
//   runApp(MyApp());
// });

runZonedGuarded(() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = NewrelicMobile.onError;
  await NewrelicMobile.instance.startAgent(config);
  runApp(MyApp());
}, (Object error, StackTrace stackTrace) {
  NewrelicMobile.instance.recordError(error, stackTrace);
});
```

AppToken is platform-specific. You need to generate the seprate token for Android and iOS apps.

## Screen Tracking Events

In order to track navigation events you have to add the NewRelicNavigationObserver to your
MaterialApp, WidgetsApp or CupertinoApp.

You should provide a name to route settings: RouteSettings(name: 'Your Route Name'). The root route
name / will be replaced by root "/" for clarity's sake.

``` dart

import 'package:newrelic_mobile/newrelic_navigation_observer.dart';

//....

MaterialApp(
  navigatorObservers: [
    NewRelicNavigationObserver(),
  ],
  // other parameters
)


```

## GoRouter Instrumentation
When using the go_router[https://pub.dev/packages/go_router] library, the automatic routing instrumentation can be enabled by adding an instance of NewRelicNavigationObserver to your application's GoRouter.observers:

``` dart

//....

import 'package:go_router/go_router.dart';
import 'package:newrelic_mobile/newrelic_navigation_observer.dart';


final router = GoRouter(
  routes: ...,
    observers: [NewRelicNavigationObserver()],
);


```


### Android Setup

1. Add the following changes to android/build.gradle:

  ```groovy
    buildscript {
      ...
      repositories {
        ...
        mavenCentral()
      }
      dependencies {
        ...
        classpath "com.newrelic.agent.android:agent-gradle-plugin:7.0.0"
      }
    }
  ```

2. Apply the newrelic plugin to the top of the android/app/build.gradle file::

  ``` groovy
    apply plugin: "com.android.application"
    apply plugin: 'newrelic' // <-- add this
  
  ```

3. Make sure your app requests INTERNET and ACCESS_NETWORK_STATE permissions by adding these lines
   to your `AndroidManifest.xml`

  ``` xml
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  ```

## Usage

See the examples below, and for more detail,
see [New Relic IOS SDK doc](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/ios-sdk-api)
or [Android SDK](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api)
.

### [startInteraction](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/start-interaction)(String actionName) Future<String>;

> Track a method as an interaction.

`InteractionId` is string.

### [endInteraction](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/end-interaction)(String interactionId): void;

> End an interaction
> (Required). This uses the string ID for the interaction you want to end.
> This string is returned when you use startInteraction().

  ``` dart
            var id = await NewrelicMobile.instance.startInteraction("Getting Data from Service");
                try {
                  var dio = Dio();
                  var response = await dio.get(
                      'https://reqres.in/api/users?delay=15');
                     print(response);
                    NewrelicMobile.instance.endInteraction(id);
                    Timeline.finishSync();
                } catch (e) {
                  print(e);
                }
  
  ```

### [setAttribute] (https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/ios-sdk-api)(String name, dynamic value) : void;

> Creates a session-level attribute shared by multiple mobile event types. Overwrites its previous value and type each time it is called.

  ```
      NewrelicMobile.instance.setAttribute('RNCustomAttrNumber', 37);
  ```

### [setUserId](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-user-id)(String userId): void;

> Set a custom user identifier value to associate user sessions with analytics events and attributes.

  ```
      NewrelicMobile.instance.setUserId("RN12934");
  ```

### [recordBreadcrumb](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/recordbreadcrumb)(String name,{Map<String, dynamic>? eventAttributes}): void;

> Track app activity/screen that may be helpful for troubleshooting crashes.

  ``` dart
      NewrelicMobile.instance.recordBreadcrumb("Button Got Pressed on Screen 3"),
  ```

### [recordCustomEvent](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/recordcustomevent-android-sdk-api)(String eventType,{String eventName = "", Map<String, dynamic>? eventAttributes}): void;

> Creates and records a custom event for use in New Relic Insights.

  ``` dart
      NewrelicMobile.instance.recordCustomEvent("Major",eventName: "User Purchase",eventAttributes: {"item1":"Clothes","price":34.00}),
            child: const Text('Record Custom Event'),
  ```
### [setMaxEventBufferTime](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-max-event-buffer-time)(int maxBufferTimeInSec) void;

> Sets the event harvest cycle length.

  ``` dart
      NewrelicMobile.instance.setMaxEventBufferTime(200);
  ```
### [setMaxEventPoolSize](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-max-event-pool-size)(int maxSize): void;

> Sets the maximum size of the event pool.

  ``` dart
      NewrelicMobile.instance.setMaxEventPoolSize(10000);
  ```

### [noticeHttpTransaction](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/notice-http-transaction/)(String url,String httpMethod,int statusCode,int startTime,int endTime,int bytesSent,int bytesReceived,Map<String, dynamic>? traceData,{String responseBody = ""}): void;

> Tracks network requests manually. You can use this method to record HTTP transactions, with an option to also send a response body.
 
 ``` dart
     NewrelicMobile.instance.noticeNetworkFailure("https://cb6b02be-a319-4de5-a3b1-361de2564493.mock.pstmn.io/searchpage", "GET", 1000, 2000,'Test Network Failure', NetworkFailure.dnsLookupFailed);
  ```

### [noticeNetworkFailure](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/notice-network-failure/)(String url,String httpMethod,int startTime,int endTime,NetworkFailure errorCode): void;

> Records network failures. If a network request fails, use this method to record details about the failures. In most cases, place this call inside exception handlers, such as catch blocks. Supported failures are: Unknown, BadURL, TimedOut, CannotConnectToHost, DNSLookupFailed, BadServerResponse, SecureConnectionFailed.

  ``` dart
     NewrelicMobile.instance.noticeNetworkFailure("https://cb6b02be-a319-4de5-a3b1-361de2564493.mock.pstmn.io/searchpage", "GET", 1000, 2000,'Test Network Failure', NetworkFailure.dnsLookupFailed);
  ```

### [recordMetric](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/recordmetric-android-sdk-api)(name: string, category: string, value?: number, countUnit?: string, valueUnit?: string): void;
> Records custom metrics (arbitrary numerical data), where countUnit is the measurement unit of the metric count and valueUnit is the measurement unit for the metric value. If using countUnit or valueUnit, then all of value, countUnit, and valueUnit must all be set.
```dart
       NewrelicMobile.instance.recordMetric("testMetric", "Test Champ",value: 12.0);
       NewrelicMobile.instance.recordMetric("testMetric1", "TestChamp12",value: 10,valueUnit: MetricUnit.BYTES,countUnit: MetricUnit.PERCENT);
```


### [currentSessionId](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/currentsessionid-android-sdk-api)(): Promise;
> Returns the current session ID. This method is useful for consolidating monitoring of app data (not just New Relic data) based on a single session definition and identifier.
```dart
    var sessionId = await NewrelicMobile.instance.currentSessionId();
```
### [setAttribute](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-attribute)(name: string, value: boolean | number | string): void;
> Creates a session-level attribute shared by multiple mobile event types. Overwrites its previous value and type each time it is called.
  ```dart
     NewrelicMobile.instance.setAttribute("FlutterCustomAttrNumber",value :5.0);
  ```
### [removeAttribute](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/remove-attribute)(name: string, value: boolean | number | string): void;
> This method removes the attribute specified by the name string..
  ```dart
     NewrelicMobile.instance.removeAttribute("FlutterCustomAttrNumber");
  ```

### [incrementAttribute](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/increment-attribute)(name: string, value?: number): void;
> Increments the count of an attribute with a specified name. Overwrites its previous value and type each time it is called. If the attribute does not exists, it creates a new attribute. If no value is given, it increments the value by 1.
```dart
    NewrelicMobile.instance.incrementAttribute("FlutterCustomAttrNumber");
    NewrelicMobile.instance.incrementAttribute("FlutterCustomAttrNumber",value :5.0);
```

## Manual Error reporting

You can register non fatal exceptions using the following method with Custom Attributes:

```dart
try {
  some_code_that_throws_error();
} catch (ex) {
NewrelicMobile.instance
        .recordError(error, StackTrace.current, attributes: attributes);
}
```

## Troubleshoot

No Http data appears:

Problem
After installing the Flutter agent and waiting at least 5 minutes, no http data appears in New Relic UI.

Solution
If no http data appears after you wait at least five minutes, check you are not overriding HttpOverrides.global inside your flutter app.  

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees
as well as other customers to get help and share best practices. Like all official New Relic open
source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this
project's topic/threads here:

> https://discuss.newrelic.com/tags/mobile

## Contribute

We encourage your contributions to improve newrelic-flutter-agent! Keep in mind that when you submit your
pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have
to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution
is on behalf of a company), drop us an email at opensource@newrelic.com.

**A note about vulnerabilities**

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and
security of our customers and their data. We believe that providing coordinated disclosure by
security researchers and engaging with the security community are important means to achieve our
security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's
products or websites, we welcome and greatly appreciate you reporting it to New Relic
through [HackerOne](https://hackerone.com/newrelic).

If you would like to contribute to this project, review [these guidelines](./CONTRIBUTING.md).


## License

newrelic-flutter-agent is licensed under the [Apache 2.0](https://apache.org/licenses/LICENSE-2.0.txt)
License.
> newrelic-flutter-agent also uses source code from third-party libraries. Full details on which libraries are used and the terms under which they are licensed can be found in the third-party notices document.
