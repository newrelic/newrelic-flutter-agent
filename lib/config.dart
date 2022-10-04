class Config {
   final String accessToken;
   final bool analyticsEventEnabled ;
   final bool crashReportingEnabled ;
   final bool interactionTracingEnabled ;
   final bool networkRequestEnabled ;
   final bool networkErrorRequestEnabled ;
   final bool httpRequestBodyCaptureEnabled;
   final bool loggingEnabled ;
   final bool webViewInstrumentation ;


   Config({ required this.accessToken,
          this.analyticsEventEnabled = true,
          this.crashReportingEnabled = true,
          this.httpRequestBodyCaptureEnabled = true,
          this.interactionTracingEnabled = true,
          this.loggingEnabled = true,
          this.networkErrorRequestEnabled = true,
          this.networkRequestEnabled = true,
          this.webViewInstrumentation = true
       });


}
