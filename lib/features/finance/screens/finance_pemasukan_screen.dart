import 'package:flutter/material.dart';
import 'finance_cashflow_cabang_screen.dart';

/// Screen ini telah dialihkan sepenuhnya ke [FinanceCashflowCabangScreen]
/// karena fungsi pencatatan dan pemantauan pemasukan sudah terintegrasi di Cashflow.
class FinancePemasukanScreen extends StatelessWidget {
  const FinancePemasukanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinanceCashflowCabangScreen();
  }
}
