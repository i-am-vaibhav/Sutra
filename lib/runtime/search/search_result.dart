/// A single search result from the web search engine.
class SearchResult {
  final String title;
  final String url;
  final String snippet;
  final DateTime? publishedDate;

  const SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.publishedDate,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'snippet': snippet,
        if (publishedDate != null) 'publishedDate': publishedDate!.toIso8601String(),
      };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
        publishedDate: json['publishedDate'] != null
            ? DateTime.tryParse(json['publishedDate'] as String)
            : null,
      );

  @override
  String toString() => 'SearchResult(title: $title, url: $url)';
}
