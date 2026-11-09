import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/news_repository.dart';
import '../../domain/discover.dart';
import '../../domain/rewards.dart';
import '../../state/rewards_state.dart';
import '../discover/discover_pages.dart';
import '../shared/celebration.dart';
import '../shared/top_bar.dart';
import 'milestone_page.dart';
import 'topic_page.dart';

/// The feed: the day's topics first, then a milestone, then "Descubre" with no end.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _pages = PageController();
  int _current = 0;
  double _overscroll = 0;

  /// How far past the end of a long page you must drag to change page.
  static const _overscrollToTurn = 48.0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, int topicCount) {
    setState(() => _current = index);
    if (topicCount > 0 && index == topicCount && mounted) {
      final now = DateTime.now();
      final day = '${now.year}-${now.month}-${now.day}';
      if (ref.read(rewardsProvider.notifier).claim('milestone:$day', PointsRules.dailyMilestone)) {
        celebrate(context, PointsRules.dailyMilestone, label: 'Día completado');
      }
    }
  }

  /// A page taller than the screen scrolls on its own and would keep the swipe
  /// forever: dragging past its end turns the feed's page instead.
  bool _onNotification(ScrollNotification n) {
    if (n.depth == 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollEndNotification) {
      _overscroll = 0;
    } else if (n is OverscrollNotification && n.dragDetails != null) {
      _overscroll += n.overscroll;
      if (_overscroll.abs() >= _overscrollToTurn) {
        final forward = _overscroll > 0;
        _overscroll = 0;
        const duration = Duration(milliseconds: 320);
        forward
            ? _pages.nextPage(duration: duration, curve: Curves.easeOutCubic)
            : _pages.previousPage(duration: duration, curve: Curves.easeOutCubic);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(todayNewsProvider)) {
      AsyncData(:final value) => _feed(value),
      AsyncError() => SafeArea(child: _LoadError(onRetry: () => ref.invalidate(todayNewsProvider))),
      _ => const SafeArea(child: Center(child: CircularProgressIndicator(color: Palette.lime))),
    };
  }

  Widget _feed(TodayNews today) {
    final topics = today.topics;
    final pool = ref.watch(discoverPoolProvider);
    // With no topics there is no milestone either: straight to Descubre.
    final discoverStart = topics.isEmpty ? 0 : topics.length + 1;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          TopBar(trailing: _SectionLabel(index: _current, topicCount: topics.length)),
          if (today.isSample)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('CONTENIDO DE EJEMPLO', style: OndaText.etiqueta(size: 10, color: Palette.textFaint)),
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onNotification,
              child: PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                // No itemCount: after the day's topics the feed keeps going.
                onPageChanged: (i) => _onPageChanged(i, topics.length),
                itemBuilder: (context, i) {
                  if (i < topics.length) return TopicPage(key: ValueKey(topics[i].id), topic: topics[i]);
                  if (i < discoverStart) return MilestonePage(topicsRead: topics.length);
                  final next = discoverAt(pool, i - discoverStart);
                  return DiscoverPage(key: ValueKey(next.key), item: next.item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NO HEMOS PODIDO CARGAR LAS NOTICIAS', style: OndaText.impacto(30)),
          const SizedBox(height: 10),
          Text('Comprueba tu conexión e inténtalo de nuevo.', style: OndaText.cuerpo(15, color: Palette.textSoft)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: Palette.lime, foregroundColor: Palette.night, shape: const StadiumBorder()),
            child: Text('REINTENTAR', style: OndaText.etiqueta(color: Palette.night, size: 13)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.index, required this.topicCount});
  final int index;
  final int topicCount;

  @override
  Widget build(BuildContext context) {
    final today = index < topicCount;
    return Text(today ? 'HOY ${index + 1}/$topicCount' : 'DESCUBRE',
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: OndaText.etiqueta(color: today ? Palette.text : Palette.descubre, size: 12));
  }
}
