import 'dart:convert';
import '../models/category.dart';
import '../models/channel_live.dart';

class M3uParser {
  static final RegExp _logoRegex = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false);
  static final RegExp _groupRegex = RegExp(r'group-title="([^"]*)"', caseSensitive: false);
  static final RegExp _nameRegex = RegExp(r'tvg-name="([^"]*)"', caseSensitive: false);
  static final RegExp _idRegex = RegExp(r'tvg-id="([^"]*)"', caseSensitive: false);

  static final RegExp _logoRegexNoQuotes = RegExp(r'tvg-logo=([^\s,]+)', caseSensitive: false);
  static final RegExp _groupRegexNoQuotes = RegExp(r'group-title=([^\s,]+)', caseSensitive: false);
  static final RegExp _nameRegexNoQuotes = RegExp(r'tvg-name=([^\s,]+)', caseSensitive: false);
  static final RegExp _idRegexNoQuotes = RegExp(r'tvg-id=([^\s,]+)', caseSensitive: false);

  static Map<String, dynamic> parse(String content) {
    final List<CategoryModel> categories = [];
    final List<ChannelLive> channels = [];
    
    final Map<String, String> categoryNameToId = {};
    int categoryIdCounter = 1;
    int channelIdCounter = 1;
    
    final lines = const LineSplitter().convert(content);
    
    String? currentExtInf;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
      } else if (!line.startsWith('#')) {
        if (currentExtInf != null) {
          final streamUrl = line;
          
          // Extract name: text after the last comma in the #EXTINF line
          String name = '';
          final commaIndex = currentExtInf.lastIndexOf(',');
          if (commaIndex != -1 && commaIndex < currentExtInf.length - 1) {
            name = currentExtInf.substring(commaIndex + 1).trim();
          }
          
          // Extract logo (tvg-logo)
          String logo = _extractAttr(currentExtInf, _logoRegex, _logoRegexNoQuotes) ?? '';
          
          // Extract category (group-title)
          String groupTitle = _extractAttr(currentExtInf, _groupRegex, _groupRegexNoQuotes) ?? 'Uncategorized';
          if (groupTitle.trim().isEmpty) {
            groupTitle = 'Uncategorized';
          }
          
          // Fallback name if parsing comma failed
          if (name.isEmpty) {
            name = _extractAttr(currentExtInf, _nameRegex, _nameRegexNoQuotes) ?? 'Channel $channelIdCounter';
          }
          
          // Manage categories
          var catId = categoryNameToId[groupTitle];
          if (catId == null) {
            catId = 'm3u_cat_$categoryIdCounter';
            categoryNameToId[groupTitle] = catId;
            categories.add(CategoryModel(
              categoryId: catId,
              categoryName: groupTitle,
              parentId: '0',
            ));
            categoryIdCounter++;
          }
          
          final streamId = 'm3u_stream_$channelIdCounter';
          
          channels.add(ChannelLive(
            num: channelIdCounter.toString(),
            name: name,
            streamType: 'live',
            streamId: streamId,
            streamIcon: logo,
            categoryId: catId,
            directSource: streamUrl,
            epgChannelId: _extractAttr(currentExtInf, _idRegex, _idRegexNoQuotes) ?? '',
          ));
          
          channelIdCounter++;
          currentExtInf = null;
        }
      }
    }
    
    return {
      'categories': categories,
      'channels': channels,
    };
  }

  static String? _extractAttr(String line, RegExp withQuotes, RegExp noQuotes) {
    final m1 = withQuotes.firstMatch(line);
    if (m1 != null) return m1.group(1);
    final m2 = noQuotes.firstMatch(line);
    if (m2 != null) return m2.group(1);
    return null;
  }
}
