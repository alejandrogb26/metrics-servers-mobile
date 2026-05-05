class PagedResponse<T> {
  final List<T> data;
  final int page;
  final int size;
  final int total;
  final int totalPages;
  final bool hasNext;

  const PagedResponse({
    required this.data,
    required this.page,
    required this.size,
    required this.total,
    required this.totalPages,
    required this.hasNext,
  });

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromItem,
  ) {
    final items = json['data'] as List<dynamic>? ?? [];
    return PagedResponse(
      data: items.map(fromItem).toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}