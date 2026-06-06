import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/movie_detail.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:mbark_iptv/repository/api/trailer_lookup_service.dart';
import 'package:mbark_iptv/presentation/widgets/widgets.dart';
import 'package:mbark_iptv/repository/api/metadata_enrichment_service.dart';
import 'package:mbark_iptv/logic/cubits/favorites/favorites_cubit.dart';

class MobileDetailScreen extends StatefulWidget {
  final ChannelMovie movie;
  final VoidCallback onPlayTap;

  const MobileDetailScreen({
    super.key,
    required this.movie,
    required this.onPlayTap,
  });

  @override
  State<MobileDetailScreen> createState() => _MobileDetailScreenState();
}

class _MobileDetailScreenState extends State<MobileDetailScreen> {
  bool _isLoading = true;
  MovieDetail? _movieDetail;
  String? _youtubeTrailerId;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await IpTvApi.getMovieDetails(widget.movie.streamId.toString());
      if (mounted) {
        setState(() {
          _movieDetail = details;
          _isLoading = false;
          
          if (details != null) {
            // Asynchronously resolve trailer
            _youtubeTrailerId = TrailerLookupService.getYoutubeIdFromMetadata(details);
            
            // Synopsis audit & debug log
            final plot = details.info?.plot;
            if (plot != null && plot.isNotEmpty && !plot.toLowerCase().contains("iptv") && !plot.toLowerCase().contains("servicer")) {
              debugPrint("TV_PARSER_DETAILS_QA: Synopsis loaded from 'info.plot' field. Length: ${plot.length}");
            } else {
              debugPrint("TV_PARSER_DETAILS_QA: Synopsis empty, null, or generic IPTV text. Displaying fallback synopsis.");
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching movie details: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.movie.name ?? 'VOD Content';
    final imageUrl = widget.movie.streamIcon ?? '';
    final rating = _movieDetail?.info?.rating ?? widget.movie.rating ?? '8.5';
    final primaryColor = Theme.of(context).primaryColor;
    
    // Get synopsis
    String synopsis = "This item is loaded from your active IPTV servicer playlist. Stream details, health controls, and direct links are fully active. Press Play below to connect directly to the player buffer and stream the media files dynamically.";
    if (!_isLoading && _movieDetail != null) {
      final plot = _movieDetail!.info?.plot;
      synopsis = MetadataEnrichmentService.cleanPlot(plot);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: Stack(
        children: [
          // 1. Adaptive Widescreen Cover Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    placeholder: (context, url) => Container(color: const Color(0xFF141416)),
                    errorWidget: (context, url, error) => _buildFallbackCover(),
                  )
                : _buildFallbackCover(),
          ),

          // 2. Dark Overlay Fading out
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.6),
                    const Color(0xFF0F0F10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. Scrollable Widescreen Content Area
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 280), // Push below banner cover
                  
                  // Text & Info Block
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rating & Categories Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.white, size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "VOD Library",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Extension: ${widget.movie.containerExtension ?? 'mp4'}",
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Movie Title
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Rich specs row (Director, Genre, Release Date)
                        if (!_isLoading && _movieDetail != null) ...[
                          _buildDetailMetaRow(Icons.movie_creation_outlined, "Director", _movieDetail!.info?.director ?? "Unknown"),
                          const SizedBox(height: 8),
                          _buildDetailMetaRow(Icons.style_outlined, "Genre", _movieDetail!.info?.genre ?? "VOD Content"),
                          const SizedBox(height: 8),
                          _buildDetailMetaRow(Icons.calendar_today_outlined, "Release", _movieDetail!.info?.releasedate ?? "N/A"),
                          const SizedBox(height: 8),
                          _buildDetailMetaRow(Icons.hourglass_empty_outlined, "Duration", _movieDetail!.info?.duration ?? "N/A"),
                          const SizedBox(height: 20),
                        ],

                        // Synopsis Card Title
                        const Text(
                          "Synopsis",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Synopsis Description Text (Loading skeleton or content)
                        _isLoading
                            ? _buildSkeletonText()
                            : Text(
                                synopsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                        const SizedBox(height: 24),

                        // Cast details if available
                        if (!_isLoading && _movieDetail?.info?.cast != null && _movieDetail!.info!.cast!.isNotEmpty && _movieDetail!.info!.cast != "null") ...[
                          const Text(
                            "Casting",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _movieDetail!.info!.cast!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Streaming Specs Cards
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161618),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Column(
                            children: [
                              _buildSpecRow("Format Type", "H.264 Video Stream"),
                              const Divider(color: Colors.white10, height: 20),
                              _buildSpecRow("Decoder Settings", "Safe Software Decoding"),
                              const Divider(color: Colors.white10, height: 20),
                              _buildSpecRow("VOD Buffer Size", "VOD Cache Profile Ready"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120), // Leave room for bottom play bar
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Widescreen Bottom Play Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Circular Back Button
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Circular Favorites Button
                      BlocBuilder<FavoritesCubit, FavoritesState>(
                        builder: (context, favState) {
                          final isLiked = favState.movies.any(
                            (m) => m.streamId == widget.movie.streamId,
                          );
                          return GestureDetector(
                            onTap: () {
                              context.read<FavoritesCubit>().addMovie(
                                widget.movie,
                                isAdd: !isLiked,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isLiked ? "Removed from Favourites" : "Added to Favourites",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.amber.shade900,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLiked
                                    ? Colors.red.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.08),
                                border: Border.all(
                                  color: isLiked
                                      ? Colors.red.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.12),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isLiked ? Colors.red : Colors.white,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),

                      // Optional Trailer Button
                      if (!_isLoading && _youtubeTrailerId != null) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                              side: BorderSide(color: Colors.white.withOpacity(0.12)),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => DialogTrailerYoutube(
                                trailer: _youtubeTrailerId!,
                                thumb: _movieDetail?.info?.movieImage ?? imageUrl,
                                title: title,
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.red, size: 20),
                          label: const Text(
                            "TRAILER",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],

                      // Large Premium Solid Play Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: widget.onPlayTap,
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                          label: const Text(
                            "STREAM NOW",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.amber.shade700),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSkeletonText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 12,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1A2C), Color(0xFF0F0B18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_filter_rounded,
          color: Colors.white.withOpacity(0.05),
          size: 78,
        ),
      ),
    );
  }
}
