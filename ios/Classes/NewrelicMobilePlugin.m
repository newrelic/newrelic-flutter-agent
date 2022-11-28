/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#import "NewrelicMobilePlugin.h"
#if __has_include(<newrelic_mobile/newrelic_mobile-Swift.h>)
#import <newrelic_mobile/newrelic_mobile-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "newrelic_mobile-Swift.h"
#endif

@implementation NewrelicMobilePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftNewrelicMobilePlugin registerWithRegistrar:registrar];
}
@end
