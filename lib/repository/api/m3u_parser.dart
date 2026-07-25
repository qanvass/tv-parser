import 'dart:convert';
import '../models/category.dart';
import '../models/channel_live.dart';

class M3uParser {
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
          String logo = _parseAttribute(currentExtInf, 'tvg-logo') ?? '';
          
          // Extract category (group-title)
          String groupTitle = _parseAttribute(currentExtInf, 'group-title') ?? 'Uncategorized';
          if (groupTitle.trim().isEmpty) {
            groupTitle = 'Uncategorized';
          }
          
          // Fallback name if parsing comma failed
          if (name.isEmpty) {
            name = _parseAttribute(currentExtInf, 'tvg-name') ?? 'Channel $channelIdCounter';
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
            epgChannelId: _parseAttribute(currentExtInf, 'tvg-id') ?? '',
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
  
  static String? _parseAttribute(String line, String attributeName) {
    // Look for attributeName="value"
    final regExp = RegExp('$attributeName="([^"]*)"', caseSensitive: false);
    final match = regExp.firstMatch(line);
    if (match != null) {
      return match.group(1);
    }
    
    // Try without quotes: attributeName=value
    final regExpNoQuotes = RegExp('$attributeName=([^\\s,]+)', caseSensitive: false);
    final matchNoQuotes = regExpNoQuotes.firstMatch(line);
    if (matchNoQuotes != null) {
      return matchNoQuotes.group(1);
    }
    
    return null;
  }
}
