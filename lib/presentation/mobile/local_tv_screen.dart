import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/local_market_profile.dart';
import '../../repository/api/local_market_service.dart';

class LocalTvScreen extends StatefulWidget {
  final List<ChannelLive> allLiveChannels;
  final void Function(ChannelLive) onPlayChannel;

  const LocalTvScreen({
    super.key,
    required this.allLiveChannels,
    required this.onPlayChannel,
  });

  @override
  State<LocalTvScreen> createState() => _LocalTvScreenState();
}

class _LocalTvScreenState extends State<LocalTvScreen> with SingleTickerProviderStateMixin {
  LocalMarketProfile? _activeMarket;
  TabController? _tabController;

  final List<Map<String, String>> _categories = [
    {"key": "all", "label": "All Matches"},
    {"key": "broadcast", "label": "Local Broadcast"},
    {"key": "news", "label": "Local News"},
    {"key": "sports", "label": "Local Sports"},
    {"key": "pbs", "label": "PBS / Public TV"},
    {"key": "spanish", "label": "Spanish Local"},
    {"key": "nearby", "label": "Nearby Markets"},
  ];

  @override
  void initState() {
    super.initState();
    _activeMarket = LocalMarketService.getActiveMarket();
    if (_activeMarket == null && LocalMarketService.supportedMarkets.isNotEmpty) {
      _activeMarket = LocalMarketService.supportedMarkets.first;
      LocalMarketService.setActiveMarket(_activeMarket!.id);
    }
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _changeMarket(LocalMarketProfile market) {
    setState(() {
      _activeMarket = market;
    });
    LocalMarketService.setActiveMarket(market.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Switched local TV market to ${market.displayName}"),
        backgroundColor: Colors.amber.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeMarket == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F10),
        appBar: AppBar(
          title: const Text("Local TV Near You"),
          backgroundColor: const Color(0xFF161618),
        ),
        body: const Center(
          child: Text("No local market detected. Please configure in settings.", style: TextStyle(color: Colors.white60)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: 130.0,
              backgroundColor: const Color(0xFF161618),
              title: const Text(
                "Local TV Near You",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.map_rounded, color: Colors.amber),
                  onPressed: _showMarketSelectionDialog,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.only(bottom: 54, left: 16, right: 16),
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Market: ${_activeMarket!.displayName}",
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _showMarketSelectionDialog,
                        child: const Text(
                          "(Change)",
                          style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: _categories.map((cat) => Tab(text: cat["label"])).toList(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((cat) {
            final key = cat["key"]!;
            if (key == "nearby") {
              return _buildNearbyMarketsView();
            }
            return _buildCategoryChannelsView(key);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryChannelsView(String categoryKey) {
    final channels = LocalMarketService.getLocalChannelsForCategory(
      categoryKey: categoryKey,
      market: _activeMarket!,
      playlist: widget.allLiveChannels,
    );

    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              "No matching local channels found",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Try updating your playlist or changing local market.",
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return Card(
          color: const Color(0xFF161618),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: channel.streamIcon != null && channel.streamIcon!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: channel.streamIcon!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Icon(Icons.live_tv_rounded, color: Colors.white24),
                      errorWidget: (_, __, ___) => const Icon(Icons.live_tv_rounded, color: Colors.white24),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: Colors.white12,
                      child: const Icon(Icons.live_tv_rounded, color: Colors.white30),
                    ),
            ),
            title: Text(
              channel.name ?? 'Broadcaster Feed',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                channel.categoryId ?? 'Live Channel',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.amber, size: 28),
            onTap: () => widget.onPlayChannel(channel),
          ),
        );
      },
    );
  }

  Widget _buildNearbyMarketsView() {
    final nearby = LocalMarketService.getNearbyMarkets(_activeMarket!.id);

    if (nearby.isEmpty) {
      return const Center(
        child: Text("No nearby markets registry configured.", style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: nearby.length,
      itemBuilder: (context, index) {
        final market = nearby[index];
        return Card(
          color: const Color(0xFF161618),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.location_city_rounded, color: Colors.amber),
            ),
            title: Text(
              market.displayName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Switch active local suggestions to this market", style: TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: const Icon(Icons.swap_horiz_rounded, color: Colors.white30),
            onTap: () => _changeMarket(market),
          ),
        );
      },
    );
  }

  void _showMarketSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Select Local TV Market", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: LocalMarketService.supportedMarkets.length,
              itemBuilder: (context, index) {
                final market = LocalMarketService.supportedMarkets[index];
                final isSelected = market.id == _activeMarket?.id;
                return ListTile(
                  title: Text(
                    market.displayName,
                    style: TextStyle(color: isSelected ? Colors.amber : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.amber) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMarket(market);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.amber)),
            )
          ],
        );
      },
    );
  }
}
