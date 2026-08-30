import 'package:flutter/material.dart';
import 'finance_audit_screen.dart';

/// Screen ini telah dialihkan sepenuhnya ke [FinanceAuditScreen]
/// karena fungsi audit, verifikasi pembayaran, approval, penolakan,
/// dan edit order telah disatukan di Audit Order.
class FinanceApprovalListScreen extends StatelessWidget {
  const FinanceApprovalListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinanceAuditScreen();
  }
}
