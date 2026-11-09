import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/news_repository.dart';
import 'package:onda/domain/news.dart';

// Shapes copied from real Supabase responses (eventos and noticias).
Map<String, dynamic> topicRow({String url = 'https://www.bbc.com/mundo/a', List<Map<String, dynamic>>? headlines}) => {
      'key': 'tema-120',
      'rank': 1,
      'headline': 'Nvidia abre una investigación',
      'summary': 'Una entradilla.',
      'url': url,
      'outlet_name': 'BBC Mundo',
      'outlets': 2,
      'headlines': headlines ??
          [
            {'outlet': 'ABC', 'side': 'derecha', 'title': 'Titular de ABC', 'url': 'https://abc.es/1'},
            {'outlet': 'BBC Mundo', 'side': 'internacional', 'title': 'Titular de BBC', 'url': 'https://www.bbc.com/mundo/a'},
          ],
    };

Map<String, dynamic> newsRow(int id, String url) => {
      'id': id,
      'outlet_name': 'RTVE',
      'title': 'Una noticia',
      'summary': null,
      'url': url,
      'published_at': '2026-11-09T09:00:00+00:00',
    };

void main() {
  test('builds a topic with each outlet\'s headline', () {
    final t = topicFromRow(topicRow());
    expect(t.id, 'tema-120');
    expect(t.outletName, 'BBC Mundo');
    expect(t.headlines.map((h) => h.side), [NewsSide.derecha, NewsSide.internacional]);
    expect(t.bothSides, isFalse);
  });

  test('both sides only when the left and the right cover it', () {
    final t = topicFromRow(topicRow(headlines: [
      {'outlet': 'ABC', 'side': 'derecha', 'title': 'A', 'url': 'https://abc.es/1'},
      {'outlet': 'elDiario.es', 'side': 'izquierda', 'title': 'B', 'url': 'https://eldiario.es/1'},
    ]));
    expect(t.bothSides, isTrue);
    expect(t.bySide.keys, [NewsSide.izquierda, NewsSide.derecha]);
  });

  test('an unknown side falls back to centre instead of failing', () {
    final t = topicFromRow(topicRow(headlines: [
      {'outlet': 'X', 'side': 'nuevo', 'title': 'A', 'url': 'https://x.es/1'},
    ]));
    expect(t.headlines.single.side, NewsSide.centro);
  });

  test('topics follow their rank, whatever order the database returns', () {
    final today = todayNewsFromRows(
      [
        {...topicRow(), 'key': 'tema-menos-medios', 'rank': 8},
        {...topicRow(), 'key': 'tema-mas-medios', 'rank': 1},
      ],
      const [],
    );
    expect(today.topics.map((t) => t.id), ['tema-mas-medios', 'tema-menos-medios']);
  });

  test('headlines inside a topic are not repeated in Descubre', () {
    final today = todayNewsFromRows([topicRow()], [newsRow(1, 'https://abc.es/1'), newsRow(2, 'https://rtve.es/2')]);
    expect(today.latest.map((n) => n.url), ['https://rtve.es/2']);
    expect(today.latest.single.id, 'noticia-2');
    expect(today.latest.single.topic, 'RTVE');
    expect(today.isSample, isFalse);
  });

  test('links that are not web links are dropped: feeds are third-party data', () {
    final today = todayNewsFromRows(
      [topicRow(url: 'javascript:alert(1)')],
      [newsRow(1, 'intent://evil'), newsRow(2, 'https://rtve.es/2')],
    );
    expect(today.topics, isEmpty);
    expect(today.latest.map((n) => n.url), ['https://rtve.es/2']);
  });

  test('isWebLink accepts only http and https', () {
    expect(isWebLink('https://a.es/x'), isTrue);
    expect(isWebLink('http://a.es/x'), isTrue);
    expect(isWebLink('javascript:alert(1)'), isFalse);
    expect(isWebLink('file:///etc/passwd'), isFalse);
    expect(isWebLink(''), isFalse);
  });

  test('timeAgo in Spanish', () {
    final now = DateTime(2026, 11, 9, 12);
    expect(timeAgo(null, now), isNull);
    expect(timeAgo(now, now), 'ahora');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), 'hace 5 min');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now), 'hace 3 h');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now), 'hace 1 día');
    expect(timeAgo(now.subtract(const Duration(days: 4)), now), 'hace 4 días');
  });

  test('without Supabase the feed uses content flagged as sample', () async {
    final today = await SampleNewsRepository().load();
    expect(today.isSample, isTrue);
    expect(today.topics, isNotEmpty);
  });
}
