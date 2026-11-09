import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../domain/news.dart';

/// Opens a link in the device's browser. An interface so tests don't launch anything.
abstract class LinkOpener {
  Future<bool> open(String url);
}

class DeviceLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

final linkOpenerProvider = Provider<LinkOpener>((ref) => DeviceLinkOpener());

/// Opens [url] if it is a web link and tells the user when it can't be opened.
/// Returns true when the browser opened.
Future<bool> openLink(BuildContext context, WidgetRef ref, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  if (isWebLink(url)) {
    try {
      opened = await ref.read(linkOpenerProvider).open(url);
    } catch (e) {
      debugPrint('Link failed: $e');
    }
  }
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(content: Text('No hemos podido abrir la noticia.')));
  }
  return opened;
}

/// Main action of a news item: read it at the source.
class ReadAtSourceButton extends ConsumerWidget {
  const ReadAtSourceButton({super.key, required this.outlet, required this.url, this.onOpened});
  final String outlet;
  final String url;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () async {
        if (await openLink(context, ref, url)) onOpened?.call();
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: Text('LEER EN ${outlet.toUpperCase()}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: OndaText.etiqueta(color: Palette.night, size: 13)),
      style: FilledButton.styleFrom(
        backgroundColor: Palette.lime,
        foregroundColor: Palette.night,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

/// Small coloured label ("TEMA DEL DÍA", "DESCUBRE · CIENCIA").
class LabelPill extends StatelessWidget {
  const LabelPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(label.toUpperCase(), style: OndaText.etiqueta(color: color)),
    );
  }
}
