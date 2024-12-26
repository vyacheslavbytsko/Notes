import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:notes/screens/home_screen.dart';
import 'package:notes/screens/note_screen.dart';

import 'boxes/notes_box.dart';

late NotesBox notesBox;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  notesBox = await NotesBox.create();

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
            return NoteScreen(note: notesBox.getLocalNote(state.pathParameters["noteId"]!));
          },
        ),
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
