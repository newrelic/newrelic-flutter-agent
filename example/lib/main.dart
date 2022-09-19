import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/newrelic_navigation_observer.dart';

void main() {
  var appToken = "";

  if (Platform.isAndroid) {
    appToken = "<android app token>";
  } else if (Platform.isIOS) {
    appToken = "<ios app token>";
  }

  Config config = Config(accessToken: appToken);

  NewrelicMobile.instance.start(config, () {
    runApp(MyApp());
  });
}

/// The main app.
class MyApp extends StatelessWidget {
  /// Creates an [App].
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [NewRelicNavigationObserver()],
      routes: {
        'pageone': (context) => Page1Screen(),
        'pagetwo': (context) => Page2Screen(),
        'pagethree': (context) => Page3Screen(),
        'pagefour': (context) => Page4Screen()
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
                      final client = HttpClient();
                      final request = await client.postUrl(Uri.parse(
                          "https://jsonplaceholder.typicode.com/posts"));
                      request.headers.set(HttpHeaders.contentTypeHeader,
                          "application/json; charset=UTF-8");
                      request.write(
                          '{"title": "Foo","body": "Bar", "userId": 99}');

                      final response = await request.close();

                      response.transform(utf8.decoder).listen((contents) {
                        print(contents);
                      });
                    },
                    child: const Text('Http Default Client',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      var url = Uri.parse(
                          'https://754e-2600-1700-1118-20d0-b1f5-5075-cd0-e03a.ngrok.io/hello-world');
                      var response = await http.get(url);
                      print('Response status: ${response.statusCode}');
                      print('Response body: ${response.body}');
                    },
                    child: const Text('Http Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        var dio = Dio();
                        var response = await dio
                            .get('https://reactnative.dev/movies.json');
                        print(response);
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: const Text('Http Dio Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        var dio = Dio();
                        var response = await dio.get(
                            'https://cb6b02be-a319-4de5-a3b1-361de2564493.mock.pstmn.io/searchpage');
                        print(response);
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: const Text('OOM Issue Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                ElevatedButton(
                    onPressed: () async {
                      try {
                        var dio = Dio();
                        var response = await dio.post(
                            'https://reqres.in/api/register',
                            data: "{ 'email': 'sydney@fife'}");
                        print(response.data);
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: const Text('Http Dio Post Library ',
                        maxLines: 1, textDirection: TextDirection.ltr)),
                Query(
                    options: QueryOptions(document: gql(rickCharacters)),
                    builder: (result, {fetchMore, refetch}) {
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

                    var id = await NewrelicMobile.instance.startInteraction("Going to Page 2");
                    Future.delayed(const Duration(milliseconds: 10000), () {
                      Navigator.pushNamed(context, 'pagetwo',arguments: {'id':id});
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
class Page2Screen extends StatelessWidget {
  /// Creates a [Page2Screen].

  var interActionId;

   Page2Screen({Key? key,this.interActionId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute
        .of(context)!
        .settings
        .arguments as Map;

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
              child: const Text('Async Error'),
            ),
            ElevatedButton(
              onPressed: () {
                throw StateError("State Error");
              },
              child: const Text('State Error'),
            ),
            ElevatedButton(
              onPressed: () {
                print("test");
                debugPrint("test");
                throw NullThrownError();
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
    try {
      throw 42;
    } catch (error) {
      Map<String, dynamic> attributes = {
        "error attribute": "12344",
        "error attribute": 1234
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
                onPressed: () => NewrelicMobile.instance.recordCustomEvent(
                    "Test Custom Event",
                    eventName: "User Purchase",
                    eventAttributes: {"item1": "Clothes", "price": 34.00}),
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
                    print(response);
                    NewrelicMobile.instance.endInteraction(id);
                  } catch (e) {
                    print(e);
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
                style: Theme.of(context).textTheme.headline6,
              ),
              ElevatedButton(
                onPressed: () {
                  computeService.fetchUser().then((value) {
                    setState(() {
                      person = value;
                    });
                  });
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
              )
            ],
          ),
        ),
      );
}

class ComputeService {
  Future<Person> fetchUser() async {
    String userData = await Api.getUser("Compute");
    return await compute(deserializeJson, userData);
  }

  Person deserializeJson(String data) {
    throw new Error();

    Map<String, dynamic> dataMap = jsonDecode(data);
    return Person(dataMap["name"]);
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
    print(response);
    SendPort sendPort = values[0];
    String data = values[1];
    Map<String, dynamic> dataMap = jsonDecode(data);
    throw new Exception("this is isplation error");
    sendPort.send(Person(dataMap["name"]));
  }
}

final HttpLink rickAndMortyHttpLink =
    HttpLink('https://countries.trevorblades.com/');
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
