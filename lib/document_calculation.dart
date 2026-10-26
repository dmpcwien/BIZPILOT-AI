/// Monetary calculations for internal drafts only, not tax or legal advice.
class DraftLine {
  const DraftLine({required this.description, required this.quantity,
    required this.unitPriceCents});
  final String description;
  final int quantity;
  final int unitPriceCents;

  int get totalCents => quantity * unitPriceCents;

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unitPriceCents': unitPriceCents,
  };

  factory DraftLine.fromJson(Map<String, dynamic> data) => DraftLine(
    description: data['description'] as String,
    quantity: (data['quantity'] as num).toInt(),
    unitPriceCents: (data['unitPriceCents'] as num).toInt(),
  );
}

class DraftTotals {
  static int subtotalCents(Iterable<DraftLine> lines) {
    var total = 0;
    for (final line in lines) {
      if (line.quantity <= 0 || line.unitPriceCents < 0) {
        throw ArgumentError('Menge und Einzelpreis sind ungültig.');
      }
      total += line.totalCents;
    }
    return total;
  }

  /// Basis-point discount (10000 = 100%). Round half up to nearest cent.
  static int afterDiscountCents(Iterable<DraftLine> lines, int discountBasisPoints) {
    if (discountBasisPoints < 0 || discountBasisPoints > 10000) {
      throw ArgumentError.value(discountBasisPoints, 'discountBasisPoints');
    }
    final subtotal = subtotalCents(lines);
    return (subtotal * (10000 - discountBasisPoints) + 5000) ~/ 10000;
  }

  static String euro(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
}
