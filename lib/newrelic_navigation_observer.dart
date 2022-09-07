import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

const breadCrumbName = 'navigation';

class NewRelicNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute && previousRoute is PageRoute) {
      _addBreadcrumb('didPop', previousRoute.settings, route.settings);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _addBreadcrumb('didPush', previousRoute?.settings, route.settings);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute && oldRoute is PageRoute) {
      _addBreadcrumb('didReplace', oldRoute.settings, newRoute.settings);
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
}
