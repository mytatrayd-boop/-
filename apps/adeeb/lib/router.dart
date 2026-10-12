import 'package:go_router/go_router.dart';

import 'library/book_page.dart';
import 'library/library_screen.dart';
import 'reader/reader_screen.dart';
import 'search/search_screen.dart';

GoRouter createRouter() => GoRouter(
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
        // و`&q=<استعلام>` لتظليل كلمات البحث في الفقرة.
        GoRoute(
          path: 'read/:bookId',
          builder: (context, state) => ReaderScreen(
            bookId: state.pathParameters['bookId']!,
            paragraphId: state.uri.queryParameters['p'],
            chapterId: state.uri.queryParameters['c'],
            searchQuery: state.uri.queryParameters['q'],
          ),
        ),
        // `/search` (كل الكتب) أو `/search?book=<id>` (كتاب واحد).
        GoRoute(
          path: 'search',
          builder: (context, state) =>
              SearchScreen(initialBookId: state.uri.queryParameters['book']),
        ),
      ],
    ),
  ],
);
