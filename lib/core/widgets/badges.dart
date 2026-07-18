import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../data/order_model.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.order});
  final OrderStatus status;
  final OrderModel? order;

  @override
  Widget build(BuildContext context) {
    if (order != null) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          WorkStatusBadge(status: status),
          PaymentStatusBadge(order: order),
        ],
      );
    }
    return WorkStatusBadge(status: status);
  }
}

class WorkStatusBadge extends StatelessWidget {
  const WorkStatusBadge({super.key, required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    Color bg;

    switch (status) {
      case OrderStatus.draft:
        label = 'Draf';
        color = AppColors.textMuted;
        bg = const Color(0xFFF3F4F6);
        break;
      case OrderStatus.assigned:
        label = 'Ditugaskan';
        color = AppColors.primary;
        bg = AppColors.surfaceBlue;
        break;
      case OrderStatus.inProgress:
        label = 'Dikerjakan';
        color = const Color(0xFF0284C7);
        bg = const Color(0xFFE0F2FE);
        break;
      case OrderStatus.finishedByCleaner:
        label = 'Selesai Cleaner';
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        break;
      case OrderStatus.completed:
        label = 'Selesai';
        color = AppColors.statusDone;
        bg = AppColors.statusDoneBg;
        break;
      case OrderStatus.waitingPaymentApproval:
        label = 'Dikerjakan';
        color = const Color(0xFF0284C7);
        bg = const Color(0xFFE0F2FE);
        break;
      case OrderStatus.waitingCancelApproval:
        label = 'Menunggu Batal';
        color = Colors.orange;
        bg = const Color(0xFFFFF3E0);
        break;
      case OrderStatus.cancelled:
        label = 'Dibatalkan';
        color = AppColors.error;
        bg = const Color(0xFFFEF2F2);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({
    super.key,
    this.paymentStatus,
    this.orderStatus,
    this.order,
  });

  final String? paymentStatus;
  final OrderStatus? orderStatus;
  final OrderModel? order;

  @override
  Widget build(BuildContext context) {
    final String statusStr = (order?.paymentStatus ?? paymentStatus ?? 'unpaid').toLowerCase();
    final OrderStatus oStatus = order?.status ?? orderStatus ?? OrderStatus.draft;

    String label;
    Color color;
    Color bg;

    if (statusStr == 'paid' || statusStr == 'approved' || statusStr == 'disetujui' || statusStr == 'lunas') {
      label = 'Disetujui';
      color = const Color(0xFF16A34A);
      bg = const Color(0xFFDCFCE7);
    } else if (statusStr == 'pending' || statusStr == 'waiting_payment_approval' || oStatus == OrderStatus.waitingPaymentApproval) {
      label = 'Pending';
      color = const Color(0xFFD97706);
      bg = const Color(0xFFFEF3C7);
    } else if (statusStr == 'rejected' || statusStr == 'ditolak') {
      label = 'Ditolak';
      color = AppColors.error;
      bg = const Color(0xFFFEF2F2);
    } else {
      label = 'Belum Dibayar';
      color = const Color(0xFFDC2626);
      bg = const Color(0xFFFEE2E2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Avatar inisial (tanpa foto)
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.backgroundColor = AppColors.surfaceBlue,
    this.textColor = AppColors.primary,
    this.borderColor,
  });

  final String name;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: GoogleFonts.inter(
          fontSize: size * 0.32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

