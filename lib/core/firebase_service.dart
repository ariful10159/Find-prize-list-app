import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class FirebaseService {
  final _db = FirebaseFirestore.instance;

  Future<void> addOrUpdateProduct(Product product) async {
    // Use product name (lowercase, trimmed) as unique key to avoid duplicates
    final query = await _db.collection('products')
      .where('name', isEqualTo: product.name.trim().toLowerCase())
      .get();

    if (query.docs.isNotEmpty) {
      // Update existing
      await _db.collection('products').doc(query.docs.first.id).update(product.toMap());
    } else {
      // Add new
      await _db.collection('products').add(product.toMap());
    }
  }

  Future<List<Product>> getAllProducts() async {
    final snapshot = await _db.collection('products').get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList();
  }

  Future<Product?> getProductByName(String name) async {
    final query = await _db.collection('products')
      .where('name', isEqualTo: name.trim().toLowerCase())
      .limit(1)
      .get();
    if (query.docs.isEmpty) return null;
    return Product.fromMap(query.docs.first.id, query.docs.first.data());
  }
}
