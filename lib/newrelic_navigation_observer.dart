/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

const breadCrumbName = 'navigation';

class NewRelicNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Only record if both routes are PageRoute
    if (route is PageRoute && previousRoute is PageRoute) {
      _recordNavigation('didPop', route, previousRoute);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Only record if the main route is PageRoute
    if (route is PageRoute) {
      _recordNavigation('didPush', previousRoute, route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // Only record if both routes are PageRoute
    if (newRoute is PageRoute && oldRoute is PageRoute) {
      _recordNavigation('didReplace', oldRoute, newRoute);
    }
  }

  /// Records navigation event
  void _recordNavigation(
    String methodType,
    Route<dynamic>? fromRoute,
    Route<dynamic>? toRoute,
  ) {
    NewrelicMobile.instance.recordBreadcrumb(
      breadCrumbName,
      eventAttributes: {
        'methodType': methodType,
        'from': _getRouteName(fromRoute?.settings),
        'to': _getRouteName(toRoute?.settings),
      },
    );
  }

  /// Extracts route name for all route types
  String _getRouteName(RouteSettings? settings) {
    if (settings == null) {
      return '/';
    }

    if (settings is MaterialPage) {
      return _formatPageName(settings.child, settings.key, settings.name);
    }

    if (settings is CupertinoPage) {
      return _formatPageName(settings.child, settings.key, settings.name);
    }

    if (settings is CustomTransitionPage) {
      return _formatPageName(settings.child, settings.key, settings.name);
    }

    if (settings is NoTransitionPage) {
      return _formatPageName(settings.child, settings.key, settings.name);
    }

    // Handle standard routes
    return settings.name ?? '/';
  }

  String _formatPageName(Widget child, LocalKey? key, String? fallbackName) {
    final childString = child.toString();

    if (childString.isEmpty) {
      return fallbackName ?? '/';
    }

    // When key is null, toString() returns "null" as a string
    return '$childString(${key.toString()})';
  }
}
