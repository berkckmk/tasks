enum PurchaseResultStatus { success, cancelled, error, pending }

class PurchaseResult {
  const PurchaseResult({required this.status, this.message});

  final PurchaseResultStatus status;
  final String? message;

  bool get isSuccess => status == PurchaseResultStatus.success;
}
