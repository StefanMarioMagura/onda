import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/discover.dart';
import '../domain/news.dart';
import '../main.dart' show supabaseConfigured;
import 'discover_content.dart';
import 'sample_data.dart';

/// What the feed shows: the day's topics and the latest headlines for Descubre.
class TodayNews {
  const TodayNews({required this.topics, required this.latest, this.isSample = false});
  final List<NewsTopic> topics;
  final List<NewsItem> latest;
  final bool isSample;
}

abstract class NewsRepository {
  Future<TodayNews> load();
}

/// Without Supabase (tests, quick runs): fictional content, labelled in the UI.
class SampleNewsRepository implements NewsRepository {
  @override
  Future<TodayNews> load() async => const TodayNews(topics: sampleTopics, latest: sampleLatest, isSample: true);
}

class SupabaseNewsRepository implements NewsRepository {
  SupabaseNewsRepository(this.client);
  final SupabaseClient client;

  static const latestCount = 80;

  @override
  Future<TodayNews> load() async {
    final (topicRows, newsRows) = await (
      client
          .from('eventos')
          .select('key, rank, headline, summary, url, outlet_name, outlets, headlines')
          .not('rank', 'is', null)
          .order('rank', ascending: true),
      client
          .from('noticias')
          .select('id, outlet_name, title, summary, url, published_at')
          .order('published_at', ascending: false, nullsFirst: false)
          .limit(latestCount),
    ).wait;
    return todayNewsFromRows(topicRows, newsRows);
  }
}

/// Builds the feed's content from database rows. Pure, so it is unit-tested.
/// Headlines already inside a topic aren't repeated in Descubre, and rows
/// without a usable link are dropped (feeds are third-party data).
TodayNews todayNewsFromRows(List<Map<String, dynamic>> topicRows, List<Map<String, dynamic>> newsRows) {
  final ranked = [...topicRows]..sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));
  final topics = [
    for (final r in ranked)
      if (isWebLink(r['url'] as String? ?? '')) topicFromRow(r),
  ];
  final inTopics = {for (final t in topics) for (final h in t.headlines) h.url};
  return TodayNews(
    topics: topics,
    latest: [
      for (final r in newsRows)
        if (isWebLink(r['url'] as String? ?? '') && !inTopics.contains(r['url'])) newsItemFromRow(r),
    ],
  );
}

NewsTopic topicFromRow(Map<String, dynamic> r) => NewsTopic(
      id: r['key'] as String,
      headline: r['headline'] as String,
      summary: r['summary'] as String?,
      url: r['url'] as String,
      outletName: r['outlet_name'] as String? ?? '',
      outlets: (r['outlets'] as num).toInt(),
      headlines: [
        for (final h in (r['headlines'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (isWebLink(h['url'] as String? ?? ''))
            OutletHeadline(
              outlet: h['outlet'] as String,
              side: NewsSide.values.asNameMap()[h['side']] ?? NewsSide.centro,
              title: h['title'] as String,
              url: h['url'] as String,
            ),
      ],
    );

NewsItem newsItemFromRow(Map<String, dynamic> r) => NewsItem(
      id: 'noticia-${r['id']}',
      topic: r['outlet_name'] as String? ?? 'Noticia',
      title: r['title'] as String,
      summary: r['summary'] as String?,
      url: r['url'] as String,
      publishedAt: r['published_at'] == null ? null : DateTime.parse(r['published_at'] as String).toLocal(),
    );

final newsRepositoryProvider = Provider<NewsRepository>(
    (ref) => supabaseConfigured ? SupabaseNewsRepository(Supabase.instance.client) : SampleNewsRepository());

/// Same policy as the other data: two automatic retries, then "Reintentar".
Duration? newsRetry(int retryCount, Object error) => retryCount < 2 ? const Duration(seconds: 1) : null;

final todayNewsProvider = FutureProvider<TodayNews>((ref) => ref.watch(newsRepositoryProvider).load(), retry: newsRetry);

/// What Descubre mixes: the app's own stories, debates and quizzes plus the latest news.
final discoverPoolProvider = Provider<List<DiscoverItem>>((ref) => [
      ...discoverContent,
      ...?ref.watch(todayNewsProvider).value?.latest,
    ]);
