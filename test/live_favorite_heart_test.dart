import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/widgets/tv_epg_peek.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';

void main() {
  test('the live heart uses the catalog row for a playlist link', () {
    const link = 'https://example.test/api/stream/live.m3u8';
    final channel = resolveLiveFavoriteChannel(
      link: link,
      title: 'Live channel',
      catalog: [
        const ChannelLive(
          streamId: 'm3u_stream_4',
          name: 'Live channel',
          directSource: link,
        ),
      ],
    );
    expect(channel.streamId, 'm3u_stream_4');
    expect(
      sameLiveFavorite(
        const ChannelLive(streamId: 'm3u_stream_4'),
        channel,
      ),
      isTrue,
    );
  });

  test('a link with no catalog row still has an id the heart can save', () {
    const link = 'https://example.test/api/stream/other.m3u8';
    final channel = resolveLiveFavoriteChannel(
      link: link,
      title: 'Other',
      catalog: const [],
    );
    expect(channel.streamId, link);
    expect(
      sameLiveFavorite(
        ChannelLive(streamId: link, directSource: link),
        channel,
      ),
      isTrue,
    );
  });
}
