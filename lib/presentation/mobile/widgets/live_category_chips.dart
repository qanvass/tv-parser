import 'package:flutter/material.dart';
import '../../../repository/models/category.dart';

class LiveCategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final ValueChanged<CategoryModel> onCategorySelected;

  const LiveCategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Construct ordered list of categories + virtual categories
    final List<CategoryModel> sortedCategories = [];

    // Add For You virtual category at first position
    sortedCategories.add(CategoryModel(
      categoryId: "virtual_for_you",
      categoryName: "For You",
    ));

    // Sort already loaded provider categories
    final List<CategoryModel> loadedList = List.from(categories);
    loadedList.sort((a, b) {
      final nameA = (a.categoryName ?? '').toLowerCase();
      final nameB = (b.categoryName ?? '').toLowerCase();

      int scoreA = _getCategoryPriority(nameA);
      int scoreB = _getCategoryPriority(nameB);

      return scoreB.compareTo(scoreA); // High priority scores first
    });

    sortedCategories.addAll(loadedList);

    // Add All Channels virtual category at the end
    sortedCategories.add(CategoryModel(
      categoryId: "virtual_all",
      categoryName: "All Channels",
    ));

    if (sortedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(Icons.category_rounded, color: Colors.white60, size: 16),
              SizedBox(width: 8),
              Text(
                "Live TV Categories",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44, // Larger, more reachable height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: sortedCategories.length,
            itemBuilder: (context, index) {
              final cat = sortedCategories[index];
              final isSelected = cat.categoryId == selectedCategoryId;
              final primaryColor = Theme.of(context).primaryColor;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Focus(
                  // Ensure Remote Control D-pad focus friendly
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      onCategorySelected(cat);
                    }
                  },
                  child: GestureDetector(
                    onTap: () => onCategorySelected(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withOpacity(0.18)
                            : const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor.withOpacity(0.6)
                              : Colors.white.withOpacity(0.04),
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat.categoryName ?? 'Category',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Calculates ordering priority matching user's requested layout:
  /// For You, Local, USA, News, Sports, Movies, Kids, Entertainment, English, All Countries, All Channels
  int _getCategoryPriority(String name) {
    if (name.contains("local")) return 100;
    if (name.contains("usa") || name.contains("us")) return 90;
    if (name.contains("news")) return 80;
    if (name.contains("sports") || name.contains("sport") || name.contains("racing") || name.contains("f1")) return 70;
    if (name.contains("movies") || name.contains("cinema")) return 60;
    if (name.contains("kids") || name.contains("cartoons") || name.contains("kids")) return 50;
    if (name.contains("entertainment")) return 40;
    if (name.contains("english") || name.contains("en") || name.contains("uk")) return 30;
    
    // Remaining categories
    return 10;
  }
}
