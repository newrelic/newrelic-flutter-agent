### 1.1.13

## Enhancements

- Updated the native Android agent to version 7.6.8.
- Updated the native iOS agent to version 7.5.8.

## Bug Fixes
- Resolved an issue where network requests would fail where `noticeDistributedTrace` returns an empty Map

### 1.1.12

## Enhancements

- Updated the native Android agent to version 7.6.7.
- Updated the native iOS agent to version 7.5.6.
- Resolved an issue for Android where the agent did not handle null values correctly in the `recordMetric` method.

### 1.1.11

## Enhancements

- Upgraded native Android agent to version 7.6.6
- Upgraded native iOS agent to version 7.5.5

### 1.1.10

## Enhancements

- Upgraded native Android agent to version 7.6.5

### 1.1.9

## Enhancements

- Upgraded native iOS agent to version 7.5.4
- Added Tracing flag for start interaction method

### 1.1.8

## Enhancements

- Upgraded native Android agent to version 7.6.4

### 1.1.7

## Updates
- Added CrashNow Method for testing crash reporting.

### 1.1.6

## Enhancements

- Upgraded native Android agent to version 7.6.2
- Upgraded native iOS agent to version 7.5.3


### 1.1.5

## Updates
- Updated the underlying native Android agent to version 7.6.1 for improved performance and compatibility.


### 1.1.4

## Updates
- Updated the underlying native iOS agent to version 7.5.2 for improved performance and compatibility.

### 1.1.3

## Bug Fixes
- Added null check for debugPrint Message to prevent potential crashes.
- Fixed an issue where record metrics were incorrectly sending a count of 0.

## Updates
- Updated the underlying native Android agent to version 7.6.0 for improved performance and compatibility.


### 1.1.2

## Improvements

1. **Agent LogLevel Configuration**
    - Implemented the capability to define the agent log level as `verbose`, `info`, `warn`, `debug`, or `error` through the `loglevel` configuration.
    - The default log level is set to `debug`.

2. **Added CollectorAddress and CrashCollectorAddress Configuration**
    - Introduced functionality to specify the collector address and crash collector address by utilizing the `collectorAddress` and `crashCollectorAddress` configuration options.

3. **Added Support For Applying Gradle Plugin Using Plugins DSL**
    - Added support for applying the New Relic Gradle plugin using the plugins DSL in the `build.gradle` file.

## Bug Fixes
- Resolved an issue where the interactionTracing Feature Flag failed to prevent the collection of auto interaction metrics.

## 1.1.1

## Bug Fixes

1. iOS Platform Version Reporting
    - Resolved an issue where the platform version was not being set correctly for iOS applications.

2. HTTP Instrumentation in RunZoneGuarded Context
    - Fixed a problem where HTTP instrumentation was not functioning when the app and agent were started from within RunZoneGuarded.

## 1.1.0
## New Features

1. Application Exit Reporting
    - Introduced ApplicationExitInfo in data reports
    - Feature is enabled by default

2. Log Forwarding
    - Added static API for sending logs to New Relic
    - Toggle feature in mobile application's entity settings

3. Distributed Tracing Control
    - Introduced new feature flag: distributedTracingEnabled
    - Allows enabling/disabling of distributed tracing functionality

## Enhancements

- Upgraded native Android agent to version 7.5.0
- Upgraded native iOS agent to version 7.5.0

## 1.0.9
* Improvements

The native iOS Agent has been updated to version 7.4.12, bringing performance enhancements and bug fixes.


* New Features

A new backgroundReportingEnabled feature flag has been introduced to enable background reporting functionality.
A new newEventSystemEnabled feature flag has been added to enable the new event system.

## 1.0.8
* Updated the native iOS agent to version 7.4.10.


## 1.0.7

* Added the ability to store harvest data that previously would be lost if the application doesn't have internet connection. 
 These harvest are then sent after an internet connection is established and the next harvest successfully uploads. This feature is enabled by default.
* Updated the native Android agent to version 7.3.0.
* Updated the native iOS agent to version 7.4.9.


## 1.0.6

* Adds configurable request header instrumentation to network events
  The agent will now produce network event attributes for select header values if the headers are detected on the request. The header names to instrument are passed into the agent when started.
* Updated the native Android agent to version 7.2.0.
* Updated the native iOS agent to version 7.4.8.

## 1.0.5

* Fixed issue in Flutter agent causing appbuild and appversion fields to overwrite for iOS mobile-handled exceptions.

## 1.0.4

* Upgraded native Android agent to v7.1.0
* Upgraded native iOS agent to v7.4.7
* Added Support for AGP 8 for Android

## 1.0.3

* Upgraded native Android agent to v7.0.0
* Upgraded native iOS agent to v7.4.6
* Resolved CustomTransitionPage issue for Go Router instrumentation
* Fixed issue where HTTP error stack traces were not displayed in the IDE

## 1.0.2

## 1.0.1

* Upgrade native iOS agent to v7.4.5
* Added FedRAMP configuration flag on agent start.

## 1.0.0

The native Android Agent has been upgraded to version 6.11.1.
The native iOS agent has been upgraded to version 7.4.4.
A new "shutdown" method has been added, allowing the agent to be shut down within the current application lifecycle during runtime.
Two new static methods, "recordMetric" and "incrementAttribute", have been added.

## 0.0.1

This is GA Release.

## 0.0.1-dev.11

This is Pre GA Release.

The Native iOS Agent has been updated to version 7.4.3.
The Native Android Agent has been updated to version 6.10.0.


## 0.0.1-dev.10

The Native iOS Agent has been updated to version 7.4.2.

## 0.0.1-dev.9

The following updates have been made for this release:

* A new static method, 'RecordNetworkFailure,' has been added to specifically track network failure errors.
* A previously identified issue with the agent not handling 'followRedirect' for HTTP requests has been resolved.
* Enhanced error handling has been added around the HTTP Instrumentation to improve overall stability.

These changes have been made to improve the overall performance and reliability of the product. We hope you find these updates valuable and welcome any feedback you may have.

## 0.0.1-dev.8

Bug fixes and Update Native Android SDK version

## 0.0.1-dev.7

Feat: Added Instrumentation for Go Router Package
Feat: Added Flag to disable Print Statement as Analytics Events.

## 0.0.1-dev.6

Feat: Update Native SDKs to their latest versions

## 0.0.1-dev.5

Added support for Native Agent's Features Configuration.
Added Static Methods for MaxPoolSize and MaxBufferTime. 


## 0.0.1-dev.4

Fixed Crashes Where App is crashing from flutter android plugin.

## 0.0.1-dev.3

Added Singleton Instance for Agent to support Unit testing.

Fixed Crash Where App is crashing from flutter android plugin.

## 0.0.1-dev.2

Added Functionality to Capture Print Statement as Custom Events Bug fix for Error Stacktrace

## 0.0.1-dev.1

Bug fixes

## 0.0.1-dev.0

🎉🎊 Presenting the new NewRelic SDK for Flutter:

Allows instrumenting Flutter apps and getting valuable insights in the NewRelic UI. Features:
request tracking, error/crash reporting,distributed tracing, info points, and many more. Thoroughly
maintained and ready for production.
