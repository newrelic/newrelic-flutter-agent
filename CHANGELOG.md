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
