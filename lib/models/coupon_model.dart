class Coupon {
  final String code;
  final String name;
  final String discountType; // 'Flat' or 'Percentage'
  final String amount;
  final String minAmount;
  final String expiryDate;
  final String description;

  Coupon({
    required this.code,
    required this.name,
    required this.discountType,
    required this.amount,
    required this.minAmount,
    required this.expiryDate,
    required this.description,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      code: json['M1_CODE'] ?? '',
      name: json['M1_NAME'] ?? '',
      discountType: json['M1_DC'] ?? 'Flat',
      amount: json['M1_AMT1'] ?? '0',
      minAmount: json['M1_MIN'] ?? '0',
      expiryDate: json['M1_DT2'] ?? '',
      description: json['M1_TXT1'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'M1_CODE': code,
      'M1_NAME': name,
      'M1_DC': discountType,
      'M1_AMT1': amount,
      'M1_MIN': minAmount,
      'M1_DT2': expiryDate,
      'M1_TXT1': description,
    };
  }
}
