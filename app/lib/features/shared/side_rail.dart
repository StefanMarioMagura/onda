import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/speech.dart';

/// Saved item ids (in memory for the prototype).
class SavedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
}

final savedProvider = NotifierProvider<SavedNotifier, Set<String>>(SavedNotifier.new);

/// Vertical action rail on the right, TikTok style: listen and save.
/// No public counters: they would have to be real, and the prototype has no users.
class SideRail extends ConsumerWidget {
  const SideRail({super.key, required this.id, required this.narration, this.showListen = true});
  final String id;
  final String narration;
  final bool showListen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider).contains(id);
    return Column(
      children: [
        if (showListen) ...[
          ListenButton(text: narration, compact: true),
          const SizedBox(height: 18),
        ],
        _RailButton(
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: saved ? 'Guardado' : 'Guardar',
          active: saved,
          onTap: () => ref.read(savedProvider.notifier).toggle(id),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Palette.surfaceHigh, shape: BoxShape.circle),
            child: Icon(icon, color: active ? Palette.lime : Palette.text, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: OndaText.etiqueta(size: 9, color: active ? Palette.lime : Palette.textSoft)),
        ],
      ),
    );
  }
}

/// Reads [text] aloud. Compact = round rail button; otherwise a wide pill with duration.
class ListenButton extends ConsumerStatefulWidget {
  const ListenButton({super.key, required this.text, this.compact = false});
  final String text;
  final bool compact;

  @override
  ConsumerState<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends ConsumerState<ListenButton> with SingleTickerProviderStateMixin {
  late final _bars = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _playing = false;

  /// About 2.5 words per second at the speech rate we use.
  String get _duration {
    final seconds = (widget.text.split(RegExp(r'\s+')).length / 2.5).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _toggle() async {
    final speech = ref.read(speechProvider);
    if (_playing) {
      await speech.stop();
      _stopped();
      return;
    }
    setState(() => _playing = true);
    _bars.repeat(reverse: true);
    try {
      await speech.speak(widget.text, onDone: _stopped);
    } catch (e) {
      debugPrint('Speech failed: $e');
      _stopped();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La lectura en voz alta no está disponible en este dispositivo.')),
        );
      }
    }
  }

  void _stopped() {
    if (!mounted) return;
    _bars.stop();
    setState(() => _playing = false);
  }

  @override
  void dispose() {
    if (_playing) ref.read(speechProvider).stop();
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = _playing ? _Bars(animation: _bars) : const Icon(Icons.headphones_rounded, size: 22);
    if (widget.compact) {
      return GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _playing ? Palette.lime : Palette.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: IconTheme(
                data: IconThemeData(color: _playing ? Palette.night : Palette.text),
                child: icon,
              ),
            ),
            const SizedBox(height: 4),
            Text(_playing ? 'Parar' : 'Escuchar',
                style: OndaText.etiqueta(size: 9, color: _playing ? Palette.lime : Palette.textSoft)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(color: Palette.lime, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: const IconThemeData(color: Palette.night),
              child: _playing ? _Bars(animation: _bars, color: Palette.night) : const Icon(Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 8),
            Text(_playing ? 'PARAR' : 'ESCUCHAR · $_duration',
                style: OndaText.etiqueta(color: Palette.night, size: 13)),
          ],
        ),
      ),
    );
  }
}

/// Little equaliser shown while audio plays.
class _Bars extends StatelessWidget {
  const _Bars({required this.animation, this.color});
  final Animation<double> animation;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Palette.night;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final phase in [0.0, 0.5, 0.25])
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              height: 6 + 12 * ((animation.value + phase) % 1),
              color: c,
            ),
        ],
      ),
    );
  }
}
