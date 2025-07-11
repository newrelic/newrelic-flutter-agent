/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:newrelic_mobile/loglevel.dart';
import 'package:newrelic_mobile/metricunit.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/network_failure.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/newrelic_navigation_observer.dart';
import 'package:newrelic_mobile_example/app_config.dart';
import 'package:http/http.dart' as http;

const String readCounters = """
   query (\$id: Int) { # Define which variables will be used in the query (id)
  Media (id: \$id, type: ANIME) { # Insert our variables into the query arguments (id) (type: ANIME is hard-coded in the query)
    id
    title {
      romaji
      english
      native
    }
  }
}
""";

void main() {
  var appToken = "";

  if (Platform.isAndroid) {
    appToken = AppConfig.androidToken;
  } else if (Platform.isIOS) {
    appToken = AppConfig.iOSToken;
  }

  Config config = Config(
      accessToken: appToken,
      analyticsEventEnabled: true,
      networkErrorRequestEnabled: true,
      networkRequestEnabled: true,
      crashReportingEnabled: true,
      interactionTracingEnabled: true,
      httpResponseBodyCaptureEnabled: true,
      loggingEnabled: true,
      webViewInstrumentation: true,
      printStatementAsEventsEnabled: true,
      httpInstrumentationEnabled: true,
      distributedTracingEnabled: true,
      logLevel: LogLevel.VERBOSE,
      collectorAddress: "",
      crashCollectorAddress: "",
      newEventSystemEnabled: true,
      fedRampEnabled: false,
      );

  NewrelicMobile.instance.start(config, () {
    runApp(const MyApp());
  });
  NewrelicMobile.instance.setMaxEventPoolSize(3000);
  NewrelicMobile.instance.setMaxEventBufferTime(200);
  NewrelicMobile.instance.setMaxOfflineStorageSize(200);
  NewrelicMobile.instance.addHTTPHeadersTrackingFor(["Car", "Music"]);
}

/// The main app.
class MyApp extends StatelessWidget {
  /// Creates an [App].
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [NewRelicNavigationObserver()],
      routes: {
        'pageone': (context) => const Page1Screen(),
        'pagetwo': (context) => Page2Screen(),
        'pagethree': (context) => const Page3Screen(),
        'pagefour': (context) => const Page4Screen()
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: 'pageone',
    );
  }
}

/// The screen of the first page.
class Page1Screen extends StatelessWidget {
  /// Creates a [Page1Screen].
  const Page1Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => GraphQLProvider(
        client: client,
        child: Scaffold(
          appBar: AppBar(title: const Text("Http Demo")),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                    onPressed: () async {
                      debugPrint(null);
                      NewrelicMobile.instance.recordMetric(
                          "Button Clicks",
                          "Test Champ",
                          );
                      NewrelicMobile.instance
                          .recordBreadcrumb("Button Got Pressed on Screen 3");
                      NewrelicMobile.instance.logInfo("testing logs");
                      NewrelicMobile.instance.logDebug("testing logs debug");
                      NewrelicMobile.instance
                          .logWarning("testing logs warning");
                      NewrelicMobile.instance
                          .logVerbose("testing logs verbose");
                      NewrelicMobile.instance
                          .log(LogLevel.ERROR, "testing logs");
                      NewrelicMobile.instance.logInfo("testing logs");
                      NewrelicMobile.instance.logInfo("testing logs");

                      // NewrelicMobile.instance.crashNow();

                      var map = {};
                      map["test12"] = "value";
                      map["test23"] = "value1";
                      map["logLevel"] = "INFO";
                      map["message"] = "testing logs with attributes";

                      NewrelicMobile.instance
                          .logAttributes(map.cast<String, dynamic>());

                      NewrelicMobile.instance
                          .logAll(Exception("This is an exception"), {
                        "BreadNumValue": 12.3,
                        "BreadStrValue": "FlutterBread",
                        "BreadBoolValue": true,
                        "message": "This is a message with attributes"
                      });

                      NewrelicMobile.instance.logAttributes({
                        "BreadNumValue": 12.3,
                        "BreadStrValue": "FlutterBread",
                        "BreadBoolValue": true,
                        "message": "This is a message with attributes"
                      });

                      if (kDebugMode) {
                        print(await NewrelicMobile.instance.currentSessionId());
                      }
                      // showDialog<String>(
                      //   barrierDismissible: false,
                      //   context: context,
                      //   builder: (BuildContext context) => const PopPopPop(),
                      // );
                      if (kDebugMode) {
                        print(NewrelicMobile.instance.currentSessionId());
                      }
                      NewrelicMobile.instance.incrementAttribute(
                          "FlutterCustomAttrNumber",
                          value: 5.0);
                      // NewrelicMobile.instance.recordMetric("testMetric", "Test Champ",value: 12.0);
                      NewrelicMobile.instance.recordMetric(
                          "testMetric1", "TestChamp12",
                          value: 10,
                          valueUnit: MetricUnit.BYTES,
                          countUnit: MetricUnit.PERCENT);
                    },
                    child: const Text('Test New Static Methods',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      final client = HttpClient();
                      // Here can be any non-existing URL.
                      final request = await client
                          .postUrl(Uri.parse("https://localhost:8080"));
                      request.headers.set(HttpHeaders.contentTypeHeader,
                          "application/json; charset=UTF-8");
                      request.headers.set("ngrok-skip-browser-warning", 69420);
                      request.write(
                          '{"title": "Foo","body": "Bar", "userId": 99}');

                      final response = await request.close();

                      response.transform(utf8.decoder).listen((contents) {
                        if (kDebugMode) {
                          print(contents);
                        }
                      });
                    },
                    child: const Text('Http call to non-existing URL',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      final client = HttpClient();
                      final request = await client.postUrl(Uri.parse(
                          "https://8f1d-2600-1006-b003-7627-ca1-491c-9b0-25ff.ngrok.io/notice_error"));
                      request.headers.set(HttpHeaders.contentTypeHeader,
                          "application/json; charset=UTF-8");
                      request.headers.set("Car", "Honda");
                      request.headers.set("ngrok-skip-browser-warning", 69420);
                      request.write(
                          '{"title": "Foo","body": "Bar", "userId": 99}');

                      final response = await request.close();

                      response.transform(utf8.decoder).listen((contents) {
                        if (kDebugMode) {
                          print(contents);
                        }
                      });
                    },
                    child: const Text('Http Default Client',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      // final client = HttpClient();
                      // var uri = Uri.parse("https://reactnative.dev/movies.json");
                      var response = await http.get(
                          Uri.parse("https://reactnative.dev/movies.json"));
                      // request.followRedirects = false;

                      // var url = Uri.parse(
                      //     'http://graph.facebook.com/');
                      // var response = await http.get(url);
                      // print('Response status: ${await response.stream.bytesToString()}');
                      if (kDebugMode) {
                        print('Response body: ${response.statusCode}');
                      }
                    },
                    child: const Text('Http Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        var dio = Dio();
                        dio.options.headers['Car'] = 'Toyota';
                        dio.options.followRedirects = false;
                        var response =
                            await dio.get('http://graph.facebook.com/');
                        if (kDebugMode) {
                          print(response);
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print(e);
                        }
                      }
                    },
                    child: const Text('Http Dio Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        var dio = Dio();
                        var response = await dio
                            .get('https://reactnative.dev/movies.json');
                        if (kDebugMode) {
                          print(response);
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print(e);
                        }
                      }
                    },
                    child: const Text('OOM Issue Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      NewrelicMobile.instance.noticeNetworkFailure(
                          "https://cb6b02be-a319-4de5-a3b1-361de2564493.mock.pstmn.io/searchpage",
                          "GET",
                          1000,
                          2000,
                          NetworkFailure.dnsLookupFailed);
                    },
                    child: const Text('NetWork Failure',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        var dio = Dio();
                        var response = await dio.post(
                            'https://reqres.in/api/register',
                            data: "{ 'email': 'sydney@fife'}");
                        if (kDebugMode) {
                          print(response.data);
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print(e);
                        }
                      }
                    },
                    child: const Text('Http Dio Post Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                Query(
                    options: QueryOptions(document: gql(readCounters)),
                    builder: (result, {fetchMore, refetch}) {
                      if (kDebugMode) {
                        print(result.data.toString());
                      }
                      // If stements here to check handle different states;
                      if (result.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return Text(result.data.toString());
                    }),
                Image.network('https://picsum.photos/250?image=9'),
                ElevatedButton(
                  onPressed: () async {
                    var id = await NewrelicMobile.instance
                        .startInteraction("Going to Page 2");
                    Future.delayed(const Duration(milliseconds: 100), () {
                      Navigator.pushNamed(context, 'pagetwo',
                          arguments: {'id': id});
                    });
                  },
                  child: const Text('Go to page 2'),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The screen of the second page.
//ignore: must_be_immutable
class Page2Screen extends StatelessWidget {
  /// Creates a [Page2Screen].

  dynamic interActionId;

  Page2Screen({Key? key, this.interActionId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;

    NewrelicMobile.instance.endInteraction(args['id']);

    return Scaffold(
      appBar: AppBar(title: const Text("Error Demo")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                bar();
              },
              child: const Text('Async Error'),
            ),
            ElevatedButton(
              onPressed: () {
                foo();
              },
              child: const Text('Record Error with Attributes'),
            ),
            ElevatedButton(
              onPressed: () {
                throw StateError("State Error");
              },
              child: const Text('State Error'),
            ),
            const Row(
              children: [
                Text(
                  "ErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorErrorError",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                )
              ],
            ),
            ElevatedButton(
              onPressed: () {
                if (kDebugMode) {
                  print("test");
                }
                debugPrint("test");
                throw TypeError();
              },
              child: const Text('NullThrownError'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, 'pagethree'),
              child: const Text('Go to home page'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> foo() async {
    var bar = {};
    try {
      throw bar['name'];
    } catch (error) {
      Map<String, dynamic> attributes = {
        "error attribute": "12344",
        "error test attribute": 1234
      };
      NewrelicMobile.instance
          .recordError(error, StackTrace.current, attributes: attributes);
    }
  }

  bar() {
    Future(() {
      throw "asynchronous error";
    });
  }
}

class Page3Screen extends StatelessWidget {
  /// Creates a [Page2Screen].
  const Page3Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Page 3")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  for (var i = 0; i < 100; i++) {
                    NewrelicMobile.instance.recordCustomEvent(
                        "Test Custom Event",
                        eventName: "User Purchase",
                        eventAttributes: {
                          "item1": "Clothes",
                          "price": 34.00,
                          "loop test": i
                        });
                  }
                },
                child: const Text('Record Custom Event'),
              ),
              ElevatedButton(
                onPressed: () => NewrelicMobile.instance
                    .recordBreadcrumb("Button Got Pressed on Screen 3"),
                child: const Text('Record BreadCrumb Event'),
              ),
              ElevatedButton(
                onPressed: () async {
                  var id = await NewrelicMobile.instance
                      .startInteraction("Getting Data from Service");
                  try {
                    var dio = Dio();
                    var response =
                        await dio.get('https://reqres.in/api/users?delay=15');
                    if (kDebugMode) {
                      print(response);
                    }
                    NewrelicMobile.instance.endInteraction(id);
                  } catch (e) {
                    if (kDebugMode) {
                      print(e);
                    }
                  }
                },
                child: const Text('Interaction Example'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, 'pagefour'),
                child: const Text('Go to Isolate page'),
              ),
            ],
          ),
        ),
      );
}

class Page4Screen extends StatefulWidget {
  /// Creates a [Page2Screen].
  const Page4Screen({Key? key}) : super(key: key);

  @override
  State<Page4Screen> createState() => _Page4ScreenState();
}

class _Page4ScreenState extends State<Page4Screen> {
  Person? person;
  final computeService = ComputeService();
  final spawnService = SpawnService();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Page 3")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                person?.name ?? 'Hello World',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton(
                onPressed: () async {
                  ReceivePort port = ReceivePort();
                  var errorPort = ReceivePort();
                  errorPort.listen((message) {
                    if (kDebugMode) {
                      print('Error: $message');
                    }
                    NewrelicMobile.instance
                        .recordError(message, StackTrace.current);
                  });
                  await Isolate.spawn(_isolateFunction, port.sendPort,
                      onError: errorPort.sendPort);

                  // computeService.fetchUser().then((value) {
                  //   setState(() {
                  //     person = value;
                  //   });
                  // });
                },
                child: const Text('Isolate Compute Error'),
              ),
              ElevatedButton(
                onPressed: () {
                  spawnService.fetchUser().then((value) {
                    setState(() {
                      person = value;
                    });
                  });
                },
                child: const Text('Isolate Compute Error'),
              ),
              ElevatedButton(
                onPressed: () {
                  NewrelicMobile.instance.shutDown();
                },
                child: const Text('shutDown Agent'),
              )
            ],
          ),
        ),
      );
}

void _isolateFunction(_) {
  throw Exception('Uncaught error in isolate');
}

class ComputeService {
  Future<Person> fetchUser() async {
    String userData = await Api.getUser("Compute");
    return await compute(deserializeJson, userData);
  }

  Person deserializeJson(String data) {
    throw Error();
  }
}

class Person {
  final String name;

  Person(this.name);
}

class Api {
  static Future<String> getUser(String from) =>
      Future.value("{\"name\":\"John Smith ..via $from\"}");
}

class SpawnService {
  Future<Person?> fetchUser() async {
    ReceivePort port = ReceivePort();
    String userData = await Api.getUser("Spawn");
    var isolate = await Isolate.spawn<List<dynamic>>(
        deserializePerson, [port.sendPort, userData]);
    isolate.addErrorListener(port.sendPort);
    return await port.first;
  }

  void deserializePerson(List<dynamic> values) async {
    var dio = Dio();
    var response = await dio.get('https://reqres.in/api/users?delay=15');
    if (kDebugMode) {
      print(response);
    }
    throw Exception("this is isplation error");
  }
}

final HttpLink rickAndMortyHttpLink = HttpLink('https://graphql.anilist.co');
ValueNotifier<GraphQLClient> client = ValueNotifier(
  GraphQLClient(
    link: rickAndMortyHttpLink,
    cache: GraphQLCache(
      store: InMemoryStore(),
    ),
  ),
);

const rickCharacters = '''
 query country(\$code: IN) {
    name
    native
    capital
    emoji
    currency
    languages {
      code
      name
    }
  }
 ''';

class PopPopPop extends StatelessWidget {
  const PopPopPop({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('Here we go...'),
        icon: const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 18.0,
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Something went wrong but we\'re on it.'),
            ],
          ),
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, 'pagetwo',
                      arguments: {'id': ""});
                },
                child: const Text('OK'),
              ),
            ],
          )
        ]);
  }
}
