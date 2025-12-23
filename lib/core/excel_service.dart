import 'package:excel/excel.dart';
import '../models/product.dart';
import 'firebase_service.dart';

class ExcelService {
  final FirebaseService firebaseService;

  ExcelService(this.firebaseService);

  Future<void> processAndUploadExcel(List<int> fileBytes) async {
    final excel = Excel.decodeBytes(fileBytes);
    final Set<String> seenNames = {};
    final List<Product> products = [];

    for (final table in excel.tables.keys) {
      for (final row in excel.tables[table]!.rows.skip(1)) {
        // Skip header
        final nameCell = row[0]?.value?.toString().trim();
        final priceCell = row[1]?.value;
        final categoryCell = row.length > 2
            ? row[2]?.value?.toString().trim()
            : null;

        if (nameCell == null || nameCell.isEmpty) continue;
        if (priceCell == null) continue;

        final name = nameCell.toLowerCase();
        if (seenNames.contains(name)) continue; // Avoid duplicates
        seenNames.add(name);

        final price = double.tryParse(priceCell.toString());
        if (price == null) continue;

        final keywords = _generateKeywords(name);

        products.add(
          Product(
            id: '',
            name: name,
            price: price,
            searchKeywords: keywords,
            category: categoryCell,
          ),
        );
      }
    }

    // Upload to Firebase
    for (final product in products) {
      await firebaseService.addOrUpdateProduct(product);
    }
  }

  List<String> _generateKeywords(String name) {
    // Generate all substrings for autocomplete/fuzzy search
    final Set<String> keywords = {};
    final words = name.split(' ');
    for (final word in words) {
      for (int i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    keywords.add(name);
    return keywords.map((k) => k.toLowerCase()).toList();
  }
}
