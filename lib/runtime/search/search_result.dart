/// A single search result from the web search engine.
class SearchResult {
  final String title;
  final String url;
  final String snippet;

  const SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'snippet': snippet,
      };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
      );

  @override
  String toString() => 'SearchResult(title: $title, url: $url)';
}
