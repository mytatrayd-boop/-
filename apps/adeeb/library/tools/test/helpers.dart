import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';

final fixtures = Directory('test/fixtures');

Recipe fixtureRecipe() => Recipe.load(File('${fixtures.path}/recipe.json'));

Map<int, String> fixtureTexts() => loadCache(fixtureRecipe(), Directory('${fixtures.path}/cache'));

Map<String, Object?> validBook() => {
      'schema': 1,
      'id': 'kalila',
      'version': 1,
      'title': {'ar': 'عنوان', 'en': 'Title'},
      'author': {'ar': 'مؤلف', 'en': 'Author'},
      'author_death_hijri': 142,
      'source': {'name': 'ويكي مصدر', 'url': 'https://ar.wikisource.org/wiki/x', 'retrieved': '2026-10-11'},
      'license': 'public-domain',
      'removed': 'لا شيء',
      'chapters': [
        {
          'id': 'kalila-b01',
          'title': 'باب',
          'level': 1,
          'paragraphs': [
            {'id': 'kalila-b01-p0001', 'text': 'فقرة أولى.'},
            {'id': 'kalila-b01-p0002', 'kind': 'verse', 'text': 'صدر\tعجز\nصدر\tعجز'},
          ],
        },
      ],
      'redirects': <String, String>{},
    };
