class OrderPerCategoryModel {
  final String categoryId;
  final String categoryName;
  final List<OrderItemModel> orders;

  OrderPerCategoryModel({
    required this.categoryId,
    required this.categoryName,
    required this.orders,
  });

  factory OrderPerCategoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrderPerCategoryModel(
      categoryId: json['category_id']?.toString() ?? '',
      categoryName:
          json['category_name']?.toString() ?? '',
      orders: (json['orders'] as List? ?? [])
          .map(
            (e) => OrderItemModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'category_name': categoryName,
      'orders': orders.map((e) => e.toJson()).toList(),
    };
  }
}

class OrderItemModel {
  final String id;
  final int qty;
  final String productName;
  final String note;

  OrderItemModel({
    required this.id,
    required this.qty,
    required this.productName,
    required this.note,
  });

  factory OrderItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ??
          defaultValue;
    }

    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      qty: parseInt(json['qty']),
      productName:
          json['product_name']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'qty': qty,
      'product_name': productName,
      'note': note,
    };
  }
}