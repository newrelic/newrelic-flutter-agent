enum NetworkFailure {
  unknown(-1),
  badURL(-1000),
  timedOut(-1001),
  cannotConnectToHost(-1004),
  dnsLookupFailed(-1006),
  badServerResponse(-1011),
  secureConnectionFailed(-1200);

  final int code;

  const NetworkFailure(this.code);
}
