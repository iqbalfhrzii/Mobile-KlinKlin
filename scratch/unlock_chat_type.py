with open('lib/features/orders/screens/create_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = '// Section 3: Sumber Chat & Tipe Customer'
end_marker = '// Section 4: Jadwal Pengerjaan'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print('Markers not found!')
    exit(1)

new_section3 = '''// Section 3: Sumber Chat & Tipe Customer
          _buildSectionHeader(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Sumber Chat & Tipe Customer',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUMBER CHAT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ChatSource.values.map((e) {
                    final isSelected = widget.draft.chatDari == e;

                    IconData icon;
                    String label;
                    switch (e) {
                      case ChatSource.organik:
                        icon = Icons.eco_rounded;
                        label = 'ORGANIK';
                        break;
                      case ChatSource.ads:
                        icon = Icons.campaign_rounded;
                        label = 'IKLAN (ADS)';
                        break;
                      case ChatSource.lama:
                        icon = Icons.history_rounded;
                        label = 'LAMA';
                        break;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.draft.chatDari = e;
                          widget.onChanged();
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                            right: e == ChatSource.values.last ? 0 : 8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isSelected ? AppColors.primary : AppColors.textMuted,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                Text(
                  'TIPE CUSTOMER',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: CustomerType.values.map((e) {
                    final isSelected = widget.draft.tipeCustomer == e;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.draft.tipeCustomer = e;
                          widget.onChanged();
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                            right: e == CustomerType.values.last ? 0 : 10,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              e == CustomerType.baru ? 'BARU' : 'LAMA',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          '''

new_content = content[:start_idx] + new_section3 + content[end_idx:]

with open('lib/features/orders/screens/create_order_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print('Updated Section 3 successfully')
