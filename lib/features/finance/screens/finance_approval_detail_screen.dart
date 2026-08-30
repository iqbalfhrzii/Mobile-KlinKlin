import 'package:flutter/material.dart';
import '../../../core/data/order_model.dart';
import 'finance_audit_screen.dart';

/// Screen ini telah dialihkan sepenuhnya ke [FinanceAuditScreen]
/// karena fungsi audit, verifikasi pembayaran, approval, penolakan,
/// dan edit order telah disatukan di Audit Order.
class FinanceApprovalDetailScreen extends StatelessWidget {
  final OrderModel order;
  const FinanceApprovalDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return const FinanceAuditScreen();
  }
}
