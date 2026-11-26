import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/multiview/multiview_channel_picker.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';

ChannelLive _live(String id, String name, {String? categoryId}) {
  return ChannelLive(streamId: id, name: name, categoryId: categoryId);
}

void main() {
  test('the first picker list is the saved favorites, in that order', () {
    final catalog = [
      _live('a', 'Alpha'),
      _live('b', 'Beta'),
      _live('c', 'Gamma'),
    ];
    final slice = sliceMultiviewChannels(
      catalog: catalog,
      favoriteIdsInOrder: const ['c', 'a', 'missing', 'c'],
      listIndex: kMultiviewPickerFavorites,
      needle: '',
    );
    expect(kMultiviewPickerFavorites, 0);
    expect(slice.channels.map((channel) => channel.streamId).toList(), [
      'c',
      'a',
    ]);
    expect(slice.capped, isFalse);
  });

  test('a search on the first list filters favorites only', () {
    final catalog = [
      _live('a', 'Sports One'),
      _live('b', 'News One'),
      _live('c', 'Sports Two'),
    ];
    final slice = sliceMultiviewChannels(
      catalog: catalog,
      favoriteIdsInOrder: const ['b', 'a'],
      listIndex: kMultiviewPickerFavorites,
      needle: 'sports',
    );
    expect(slice.channels.map((channel) => channel.streamId).toList(), ['a']);
  });

  test('all and a later category do not walk the favorite list', () {
    final catalog = List.generate(
      5,
      (i) => _live('$i', 'Channel $i', categoryId: i.isEven ? 'news' : 'sport'),
    );
    final all = sliceMultiviewChannels(
      catalog: catalog,
      favoriteIdsInOrder: const ['4'],
      listIndex: kMultiviewPickerAll,
      needle: '',
      searchCap: 3,
    );
    expect(all.channels.map((channel) => channel.streamId).toList(), [
      '0',
      '1',
      '2',
    ]);
    expect(all.capped, isTrue);

    final news = sliceMultiviewChannels(
      catalog: catalog,
      favoriteIdsInOrder: const ['1'],
      listIndex: kMultiviewPickerAll + 1,
      categoryId: 'news',
      needle: '',
      searchCap: 2,
    );
    expect(news.channels.map((channel) => channel.streamId).toList(), [
      '0',
      '2',
    ]);
    expect(news.capped, isTrue);
    expect(multiviewPickerLastIndex(4), 5);
  });
}
