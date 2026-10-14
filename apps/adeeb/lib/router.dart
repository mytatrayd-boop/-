import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'ask/ask_screen.dart';
import 'library/book_page.dart';
import 'library/library_screen.dart';
import 'reader/reader_screen.dart';
import 'search/search_screen.dart';
import 'settings/about_screen.dart';
import 'settings/privacy_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/sources_screen.dart';

GoRouter createRouter({GlobalKey<NavigatorState>? navigatorKey}) => GoRouter(
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
      routes: [
        GoRoute(
          path: 'book/:bookId',
          builder: (context, state) =>
              BookPage(bookId: state.pathParameters['bookId']!),
        ),
        // `/read/<id>?p=<معرّف فقرة>` أو `?c=<معرّف باب>` (ARCHITECTURE §3)،
        // و`&q=<استعلام>` لتظليل كلمات البحث في الفقرة، أو `&quote=<نص>`
        // لتظليل اقتباس «اسأل الأديب».
        GoRoute(
          path: 'read/:bookId',
          builder: (context, state) => ReaderScreen(
            bookId: state.pathParameters['bookId']!,
            paragraphId: state.uri.queryParameters['p'],
            chapterId: state.uri.queryParameters['c'],
            searchQuery: state.uri.queryParameters['q'],
            quote: state.uri.queryParameters['quote'],
          ),
        ),
        // `/ask` أو `/ask?book=<id>` (نطاق كتاب واحد).
        GoRoute(
          path: 'ask',
          builder: (context, state) =>
              AskScreen(initialBookId: state.uri.queryParameters['book']),
        ),
        // `/search` (كل الكتب) أو `/search?book=<id>` (كتاب واحد).
        GoRoute(
          path: 'search',
          builder: (context, state) =>
              SearchScreen(initialBookId: state.uri.queryParameters['book']),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'sources',
              builder: (context, state) => const SourcesScreen(),
            ),
            GoRoute(
              path: 'privacy',
              builder: (context, state) => const PrivacyScreen(),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
