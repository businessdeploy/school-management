class DiscountSelectionResult {
  final List<String> selectedDiscountIds;
  // Original amounts from API (getBalanceFee response)
  // balance_amount (after auto discount, BEFORE extra discount)
  final double originalBaseAmount;
  // fine_amount from API
  final double originalFineAmount;
  // Extra discount amount selected via checkboxes (TYPE 2)
  final double extraDiscountAmount;

  // Computed payable (due) amount BEFORE processing fee:
  // due_amount = balance_amount + fine_amount - selected_extra_discount
  final double dueAmount;
  
  // CRITICAL: fee_discount_group in format: [{ "id": amount }, { "id": amount }]
  // Per spec: fee_discount_group = [{ "369": 500 }, { "370": 100 }]
  final List<Map<String, dynamic>> feeDiscountGroup;

  DiscountSelectionResult({
    required this.selectedDiscountIds,
    required this.originalBaseAmount,
    required this.originalFineAmount,
    required this.extraDiscountAmount,
    required this.dueAmount,
    this.feeDiscountGroup = const [],
  });

  // Convenience getters
  double get baseBalanceAmount => originalBaseAmount;
  double get fineAmount => originalFineAmount;
  double get selectedExtraDiscount => extraDiscountAmount;
}
