import 'package:string_similarity/string_similarity.dart';
import '../models/product.dart';

class SearchService {
  // Fuzzy search with autocomplete
  List<Product> searchProducts(String query, List<Product> products) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Autocomplete: match search_keywords
    final autoResults = products
        .where((p) => p.searchKeywords.any((k) => k.startsWith(q)))
        .toList();

    // Fuzzy: use string similarity
    final fuzzyResults =
        products
            .map(
              (p) => MapEntry(p, StringSimilarity.compareTwoStrings(p.name, q)),
            )
            .where((entry) => entry.value > 0.4) // threshold
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Merge, prioritize autocomplete, then fuzzy, remove duplicates
    final seen = <String>{};
    final results = <Product>[];
    for (final p in autoResults + fuzzyResults.map((e) => e.key).toList()) {
      if (!seen.contains(p.id)) {
        results.add(p);
        seen.add(p.id);
      }
    }
    return results;
  }
}
