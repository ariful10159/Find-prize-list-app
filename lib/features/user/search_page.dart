import 'package:flutter/material.dart';
import '../../core/firebase_service.dart';
import '../../core/search_service.dart';
import '../../models/product.dart';
import 'product_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _firebaseService = FirebaseService();
  final _searchService = SearchService();
  List<Product> _allProducts = [];
  List<Product> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _controller.addListener(_onSearch);
  }

  Future<void> _loadProducts() async {
    final products = await _firebaseService.getAllProducts();
    setState(() {
      _allProducts = products;
      _loading = false;
    });
  }

  void _onSearch() {
    final query = _controller.text;
    final results = _searchService.searchProducts(query, _allProducts);
    setState(() => _results = results);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Products')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Search product',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final product = _results[i];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text('Price: ${product.price}'),
                        onTap: () async {
                          final latest = await _firebaseService
                              .getProductByName(product.name);
                          if (latest != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailPage(product: latest),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
