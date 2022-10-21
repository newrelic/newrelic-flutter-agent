# New Relic Flutter Agent

This agent allows you to instrument Flutter apps with help of native New Relic Android and iOS
agents. The New Relic SDKs collect crashes, network traffic, and other information for hybrid apps
using native components.

**NOTE:** This agent SDK is not yet officially supported. If you’re interested in participating in
our Limited Preview, contact Support or your account representative.

## Features

* Capture Dart errors
* Network Request tracking
* Distributed Tracing
* Future errors tracking
* Capture interactions and the sequence in which they were created
* Pass user information to New Relic to track user sessions
* Screen tracking via NavigationObserver
* Capture print statement as CustomEvents

## Current Support:

- Android API 24+
- iOS 10
- Depends on New Relic iOS/XCFramework and Android agents

## Requirements

- Flutter ">= 2.5.0"
- Dart ">=2.16.2 <3.0.0"
- [IOS native requirements](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/get-started/new-relic-ios-compatibility-requirements)
- [Android native requirements](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/get-started/new-relic-android-compatibility-requirements)

## Installation

Install NewRelic plugin into your dart project by adding it to dependecies in your pubspec.yaml

```yaml

dependencies:
  newrelic_mobile: 0.0.1-dev.5
  
```

## Flutter Setup

Now open your `main.dart` and add the following code to launch NewRelic (don't forget to put proper
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
      httpRequestBodyCaptureEnabled: true,

      // Optional: Enable or disable agent logging.
      loggingEnabled: true,

      //iOS Specific
      // Optional:Enable/Disable automatic instrumentation of WebViews
      webViewInstrumentation: true));

  NewrelicMobile.instance.start(config, () {
    runApp(MyApp());
  });

  class MyApp extends StatelessWidget {
  ....

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
        classpath "com.newrelic.agent.android:agent-gradle-plugin:6.9.0"
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

### [startInteraction](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/start-interaction)(interactionName: string): Promise&lt;InteractionId&gt;;

> Track a method as an interaction.

`InteractionId` is string.

### [endInteraction](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/end-interaction)(id: InteractionId): void;

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

### [setAttribute] (https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/ios-sdk-api)(name: string, value: boolean | number | string): void;

> Creates a session-level attribute shared by multiple mobile event types. Overwrites its previous value and type each time it is called.

  ```
      NewrelicMobile.instance.setAttribute('RNCustomAttrNumber', 37);
  ```

### [setUserId](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-user-id)(userId: string): void;

> Set a custom user identifier value to associate user sessions with analytics events and attributes.

  ```
      NewrelicMobile.instance.setUserId("RN12934");
  ```

### [recordBreadcrumb](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/recordbreadcrumb)(name: string, attributes?: {[key: string]: boolean | number | string}): void;

> Track app activity/screen that may be helpful for troubleshooting crashes.

  ``` dart
      NewrelicMobile.instance.recordBreadcrumb("Button Got Pressed on Screen 3"),
  ```

### [recordCustomEvent](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/recordcustomevent-android-sdk-api)(eventType: string, eventName?: string, attributes?: {[key: string]: boolean | number | string}): void;

> Creates and records a custom event for use in New Relic Insights.

  ``` dart
      NewrelicMobile.instance.recordCustomEvent("Major",eventName: "User Purchase",eventAttributes: {"item1":"Clothes","price":34.00}),
            child: const Text('Record Custom Event'),
  ```
### [setMaxEventBufferTime](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-max-event-buffer-time)(maxBufferTimeInSec : int): void;

> Sets the event harvest cycle length.

  ``` dart
      NewrelicMobile.instance.setMaxEventBufferTime(200);
  ```
### [setMaxEventPoolSize](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-android/android-sdk-api/set-max-event-pool-size)(maxSize : int): void;

> Sets the maximum size of the event pool.

  ``` dart
      NewrelicMobile.instance.setMaxEventPoolSize(10000);
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
