class Product {
  final String id;
  final String name;
  final double price;
  final List<String> searchKeywords;
  final String? category;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.searchKeywords,
    this.category,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) => Product(
    id: id,
    name: data['name'],
    price: (data['price'] as num).toDouble(),
    searchKeywords: List<String>.from(data['search_keywords'] ?? []),
    category: data['category'],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'search_keywords': searchKeywords,
    if (category != null) 'category': category,
  };
}
