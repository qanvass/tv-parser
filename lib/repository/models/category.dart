class CategoryModel {
  final String? categoryId;
  final String? categoryName;
  final String? parentId;

  CategoryModel({
    this.categoryId,
    this.categoryName,
    this.parentId,
  });

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }

  CategoryModel.fromJson(Map<String, dynamic> json)
      : categoryId = _str(json['category_id']),
        categoryName = _str(json['category_name']),
        parentId = _str(json['parent_id']);

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'category_name': categoryName,
        'parent_id': parentId,
      };
}
