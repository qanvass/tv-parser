import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/cinematic/cinematic_artwork.dart';
import 'package:mbark_iptv/presentation/tv/cinematic/cinematic_title_placeholder.dart';
import 'package:mbark_iptv/presentation/tv/widgets/tv_channel_grid.dart';
import 'package:mbark_iptv/repository/provider/unified_media_metadata.dart';

void main() {
  group('CinematicTitlePlaceholder', () {
    test('hue is stable per title and differs across titles', () {
      expect(
        CinematicTitlePlaceholder.hueFor('Deb Is Boss'),
        CinematicTitlePlaceholder.hueFor('Deb Is Boss'),
      );
      expect(
        CinematicTitlePlaceholder.hueFor('Deb Is Boss'),
        isNot(CinematicTitlePlaceholder.hueFor('Resident Evil')),
      );
    });
  });

  group('CinematicArtwork.fromRecord', () {
    test('prefers cached/TMDB poster over provider imageUrl', () {
      const stream = TvStreamRecord(
        title: 'Deb Is Boss',
        subtitle: 'Movies',
        streamUrl: 'https://example.invalid/movie/1',
        imageUrl: 'https://cdn.example/provider.jpg',
        posterStyle: TvPosterStyle.vodPortrait,
      );
      const extra = UnifiedMediaMetadata(
        posterUrl: 'https://image.tmdb.org/t/p/w500/abc.jpg',
        backdropUrl: 'https://image.tmdb.org/t/p/w1280/bd.jpg',
      );
      final art = CinematicArtwork.fromRecord(stream, extra: extra);
      expect(art.poster, 'https://image.tmdb.org/t/p/w500/abc.jpg');
      expect(art.backdrop, 'https://image.tmdb.org/t/p/w1280/bd.jpg');
      expect(art.hasBackdrop, isTrue);
    });

    test('provider imageUrl is used when enrichment is empty', () {
      const stream = TvStreamRecord(
        title: 'Deb Is Boss',
        subtitle: 'Movies',
        streamUrl: 'https://example.invalid/movie/1',
        imageUrl: 'https://cdn.example/provider.jpg',
        posterStyle: TvPosterStyle.vodPortrait,
      );
      final art = CinematicArtwork.fromRecord(stream);
      expect(art.poster, 'https://cdn.example/provider.jpg');
      expect(art.isPortraitOnly, isTrue);
    });

    test('missing art stays null so the emergency placeholder can paint', () {
      const stream = TvStreamRecord(
        title: 'Deb Is Boss',
        subtitle: 'Movies',
        streamUrl: 'https://example.invalid/movie/1',
        posterStyle: TvPosterStyle.vodPortrait,
      );
      final art = CinematicArtwork.fromRecord(stream);
      expect(art.poster, isNull);
      expect(art.backdrop, isNull);
      expect(art.hasAnyStill, isFalse);
      expect(
        CinematicSelectedMovie(stream: stream, art: art).visualLabel(
          trailerVisible: false,
        ),
        'POSTER CINEMATIC FALLBACK',
      );
    });
  });
}
