import 'package:newrelic_mobile/utils/platform_manager.dart';

enum MetricUnit {
  PERCENT,
  BYTES,
  SECONDS,
  BYTES_PER_SECOND,
  OPERATIONS,
}

extension MetricUnitExtension on MetricUnit {
  String get label {
    switch (this) {
      case MetricUnit.PERCENT:
        if (PlatformManager.instance.isIOS()) {
          return "%";
        } else {
          return "PERCENT";
        }
      case MetricUnit.BYTES:
        if (PlatformManager.instance.isIOS()) {
          return "bytes";
        } else {
          return "BYTES";
        }
      case MetricUnit.SECONDS:
        if (PlatformManager.instance.isIOS()) {
          return "sec";
        } else {
          return "SECONDS";
        }
      case MetricUnit.BYTES_PER_SECOND:
        if (PlatformManager.instance.isIOS()) {
          return "bytes/second";
        } else {
          return "BYTES_PER_SECOND";
        }
      case MetricUnit.OPERATIONS:
        if (PlatformManager.instance.isIOS()) {
          return "op";
        } else {
          return "OPERATIONS";
        }
      default:
        return "";
    }
  }
}
