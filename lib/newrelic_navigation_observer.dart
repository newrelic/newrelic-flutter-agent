/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter/material.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

const breadCrumbName = 'navigation';

class NewRelicNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute && previousRoute is PageRoute) {
      if (route.settings is MaterialPage) {
        var goRoute = route.settings as MaterialPage;

        var goPreviousRoute = previousRoute.settings as MaterialPage;

        _addGoRouterBreadcrumb('didReplace', goPreviousRoute, goRoute);
      } else {
        _addBreadcrumb('didReplace', previousRoute.settings, route.settings);
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (route is PageRoute) {
      if (route.settings is MaterialPage) {
        var goRoute = route.settings as MaterialPage;

        var goPreviousRoute;

        if (previousRoute != null) {
          goPreviousRoute = previousRoute.settings as MaterialPage;
        }

        _addGoRouterBreadcrumb('didPush', goPreviousRoute, goRoute);
      } else {
        _addBreadcrumb('didPush', previousRoute?.settings, route.settings);
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute && oldRoute is PageRoute) {
      if (newRoute.settings is MaterialPage) {
        var goRoute = newRoute.settings as MaterialPage;

        var goPreviousRoute = oldRoute.settings as MaterialPage;

        _addGoRouterBreadcrumb('didReplace', goPreviousRoute, goRoute);
      } else {
        _addBreadcrumb('didReplace', oldRoute.settings, newRoute.settings);
      }
    }
  }

  void _addBreadcrumb(
      String methodType, RouteSettings? fromRoute, RouteSettings? toRoute) {
    Map<String, String?> attributes = <String, String?>{
      'methodType': methodType,
      // ignore: prefer_if_null_operators
      'from': fromRoute?.name != null ? fromRoute?.name : '/',
      'to': toRoute?.name ?? '/'
    };
    NewrelicMobile.instance
        .recordBreadcrumb(breadCrumbName, eventAttributes: attributes);
  }

  void _addGoRouterBreadcrumb(
      String methodType, MaterialPage? fromRoute, MaterialPage? toRoute) {
    var fromKey = fromRoute?.key.toString();
    var toKey = toRoute?.key.toString();

    Map<String, String?> attributes = <String, String?>{
      'methodType': methodType,
      // ignore: prefer_if_null_operators
      'from': fromRoute?.child != null
          ? ((fromRoute?.child.toString())! + '(' + fromKey! + ')')
          : '/',
      'to': (toRoute?.child.toString())! + '(' + toKey! + ')' ?? '/'
    };
    NewrelicMobile.instance
        .recordBreadcrumb(breadCrumbName, eventAttributes: attributes);
  }
}
