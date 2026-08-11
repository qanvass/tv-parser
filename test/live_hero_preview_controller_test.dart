import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/live/live_hero_preview_controller.dart';
import 'package:mbark_iptv/presentation/tv/widgets/tv_channel_grid.dart';

TvStreamRecord _live(String title, String url) {
  return TvStreamRecord(
    title: title,
    subtitle: 'Live',
    streamUrl: url,
  );
}

void main() {
  group('LiveHeroPreviewPolicy', () {
    test('only live records with a streamUrl are preview sources', () {
      expect(
        LiveHeroPreviewPolicy.isLivePreviewSource(_live('A', 'https://x/a')),
        isTrue,
      );
      expect(
        LiveHeroPreviewPolicy.isLivePreviewSource(
          _live('A', '').copyWith(streamUrl: ''),
        ),
        isFalse,
      );
      expect(
        LiveHeroPreviewPolicy.isLivePreviewSource(
          _live('Movie', 'https://x/m').copyWith(
            posterStyle: TvPosterStyle.vodPortrait,
          ),
        ),
        isFalse,
      );
    });

    test('skips reconnect only when the same streamUrl is already live', () {
      expect(
        LiveHeroPreviewPolicy.shouldSkipReconnect(
          activeUrl: 'https://x/a',
          nextUrl: 'https://x/a',
          phase: LiveHeroPreviewPhase.playing,
        ),
        isTrue,
      );
      expect(
        LiveHeroPreviewPolicy.shouldSkipReconnect(
          activeUrl: 'https://x/a',
          nextUrl: 'https://x/b',
          phase: LiveHeroPreviewPhase.playing,
        ),
        isFalse,
      );
      expect(
        LiveHeroPreviewPolicy.shouldSkipReconnect(
          activeUrl: 'https://x/a',
          nextUrl: 'https://x/a',
          phase: LiveHeroPreviewPhase.failed,
        ),
        isFalse,
      );
    });

    test('focus debounce is 700ms', () {
      expect(
        LiveHeroPreviewPolicy.focusDebounce,
        const Duration(milliseconds: 700),
      );
    });
  });

  group('LiveHeroPreviewController debounce', () {
    test('cancels stale focus and opens only the last streamUrl', () async {
      final opened = <String>[];
      final ctrl = LiveHeroPreviewController(
        hooks: LiveHeroPreviewHooks(
          open: (url, title) async => opened.add('$title|$url'),
        ),
      );

      ctrl.request(_live('One', 'https://x/1'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      ctrl.request(_live('Two', 'https://x/2'));
      await Future<void>.delayed(const Duration(milliseconds: 699));
      expect(opened, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(opened, ['Two|https://x/2']);

      ctrl.request(_live('Two', 'https://x/2'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(opened, ['Two|https://x/2']);

      ctrl.dispose();
    });

    test('immediate request uses the record streamUrl without waiting', () async {
      final opened = <String>[];
      final ctrl = LiveHeroPreviewController(
        hooks: LiveHeroPreviewHooks(
          open: (url, title) async => opened.add(url),
        ),
      );
      ctrl.request(_live('Now', 'https://x/now'), immediate: true);
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['https://x/now']);
      ctrl.dispose();
    });
  });
}
