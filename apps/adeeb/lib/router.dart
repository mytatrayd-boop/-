import 'package:go_router/go_router.dart';

import 'library/book_page.dart';
import 'library/library_screen.dart';

GoRouter createRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LibraryScreen(),
          routes: [
            GoRoute(
              path: 'book/:bookId',
              builder: (context, state) => BookPage(bookId: state.pathParameters['bookId']!),
            ),
          ],
        ),
      ],
    );
