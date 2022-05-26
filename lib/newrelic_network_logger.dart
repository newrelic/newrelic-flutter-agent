class NewRelicNetworkLogger {
  NewRelicNetworkLogger({
    this.url,
    this.httpMethod,
    this.statusCode,
    this.startTime,
    this.endTime,
    this.bytesSent,
    this.bytesReceived,
    this.responseBody
  });

  String? url;
  String? httpMethod;
  int? statusCode;
  int? startTime;
  int? endTime;
  int? bytesSent;
  int? bytesReceived;
  String? responseBody;

}