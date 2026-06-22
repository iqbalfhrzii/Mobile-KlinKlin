import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class WeeklyDatePicker extends StatefulWidget {
  const WeeklyDatePicker({
    super.key,
    required this.onFilterChanged,
    this.onSearchChanged,
    this.onSearchSubmit,
    this.searchQuery,
    this.initialDate,
  });

  /// Called when the filter changes.
  /// If [start] and [end] are null, it means "All Time".
  /// If [start] == [end], it means a single day is selected.
  /// If [start] != [end], it means a whole week is selected.
  final void Function(DateTime? start, DateTime? end) onFilterChanged;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchSubmit;
  final String? searchQuery;
  final DateTime? initialDate;

  @override
  State<WeeklyDatePicker> createState() => _WeeklyDatePickerState();
}

class _WeeklyDatePickerState extends State<WeeklyDatePicker> {
  late DateTime _currentWeekStart;
  DateTime? _selectedDate;
  bool _isAllTime = false;
  final _searchCtrl = TextEditingController();

  static const _dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _currentWeekStart = _getStartOfWeek(widget.initialDate!);
      _selectedDate = DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day);
    } else {
      _currentWeekStart = _getStartOfWeek(DateTime.now());
    }
    if (widget.searchQuery != null) {
      _searchCtrl.text = widget.searchQuery!;
    }
    // Initial notification (Default is current week)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyParent();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime _getStartOfWeek(DateTime date) {
    final daysToSubtract = date.weekday - 1;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysToSubtract));
  }

  void _notifyParent() {
    if (_isAllTime) {
      final monthStart = DateTime(_currentWeekStart.year, _currentWeekStart.month, 1);
      final nextMonth = DateTime(_currentWeekStart.year, _currentWeekStart.month + 1, 1);
      final monthEnd = nextMonth.subtract(const Duration(seconds: 1));
      widget.onFilterChanged(monthStart, monthEnd);
    } else if (_selectedDate != null) {
      final endOfDay = _selectedDate!.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      widget.onFilterChanged(_selectedDate, endOfDay);
    } else {
      final weekEnd = _currentWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      widget.onFilterChanged(_currentWeekStart, weekEnd);
    }
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      _isAllTime = false;
      _selectedDate = null; // Clear single day selection when changing week
    });
    _notifyParent();
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      _isAllTime = false;
      _selectedDate = null;
    });
    _notifyParent();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _currentWeekStart = _getStartOfWeek(picked);
        _isAllTime = false;
        _selectedDate = null;
      });
      _notifyParent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _monthNames[_currentWeekStart.month - 1];
    final year = _currentWeekStart.year;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.primary),
              onPressed: _previousWeek,
            ),
            GestureDetector(
              onTap: _pickMonth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$monthName $year',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.primary),
              onPressed: _nextWeek,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Days Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(7, (index) {
              final date = _currentWeekStart.add(Duration(days: index));
              final isSelected = !_isAllTime && _selectedDate != null &&
                  date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isAllTime = false;
                    if (isSelected) {
                      _selectedDate = null; // Unselect single day -> reverts to week filter
                    } else {
                      _selectedDate = date; // Select single day
                    }
                  });
                  _notifyParent();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  margin: EdgeInsets.only(right: index == 6 ? 0 : 10),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (_isAllTime ? AppColors.border.withOpacity(0.5) : AppColors.border),
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      else if (!_isAllTime)
                        AppColors.cardShadow,
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dayNames[date.weekday - 1], // 1 = MON
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white.withOpacity(0.8) : (_isAllTime ? AppColors.textMuted.withOpacity(0.5) : AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${date.day}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (_isAllTime ? AppColors.textMuted.withOpacity(0.5) : AppColors.textDark),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        // Baris Pencarian dan Tombol Semua Tanggal
        Row(
          children: [
            if (widget.onSearchChanged != null) ...[
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: widget.onSearchChanged,
                    onSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                      widget.onSearchSubmit?.call();
                    },
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Tombol Semua Tanggal
            if (!_isAllTime)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isAllTime = true;
                    _selectedDate = null;
                  });
                  _notifyParent();
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Lihat per bulan',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isAllTime = false;
                    _selectedDate = null;
                  });
                  _notifyParent();
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Lihat per bulan (Batal)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
