import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:notes/boxes/events_box_v1.dart';
import 'package:notes/boxes/servers_box_v1.dart';
import 'package:notes/screens/home_screen.dart';
import 'package:notes/screens/note_screen.dart';
import 'package:notes/screens/settings_screen.dart';

import 'boxes/notes_box_v1.dart';
import 'boxes/suggestions_box_v1.dart';
import 'isolates/server_isolate.dart';

late NotesBoxV1 notesBox;
late EventsBoxV1 eventsBox;
late ServersBoxV1 serversBox;
late SuggestionsBoxV1 suggestionsBox;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  notesBox = await NotesBoxV1.create();
  eventsBox = await EventsBoxV1.create();
  serversBox = await ServersBoxV1.create();
  suggestionsBox = await SuggestionsBoxV1.create();

  ServerIsolate serverIsolate = ServerIsolate();
  serverIsolate.start();

  runApp(const MyApp());
}

GoRouter router = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(
        path: "/",
        builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'note/:noteId',
          builder: (BuildContext context, GoRouterState state) {
            return NoteScreen(note: notesBox.getNote(state.pathParameters["noteId"]!)!);
          },
        ),
        GoRoute(
            path: "settings",
            builder: (BuildContext context, GoRouterState state) {
              return SettingsScreen();
            }
        )
      ]
    )
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent));

    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          ColorScheme lightColorScheme = lightDynamic?.harmonized() ??
              ColorScheme.fromSeed(seedColor: Colors.blue);
          ColorScheme darkColorScheme = darkDynamic?.harmonized() ??
              ColorScheme.fromSeed(
                  seedColor: Colors.blue, brightness: Brightness.dark);
          return MaterialApp.router(
            routerConfig: router,
            title: 'Gallery',
            theme: ThemeData(colorScheme: lightColorScheme),
            darkTheme: ThemeData(colorScheme: darkColorScheme),
            themeMode: ThemeMode.system,
          );
        });
  }
}
