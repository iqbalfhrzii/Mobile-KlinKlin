import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\cleaner\tukar_libur\screens\tukar_libur_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_history = """
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_repeat_rounded, color: Color(0xFF8B5CF6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tukar dengan: ${target['nama']}', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: #${item['id']} • Diajukan oleh: ${pengaju['nama']}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      item['status'].toString().toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 14, color: Colors.red.shade400),
                              const SizedBox(width: 4),
                              Text('Libur Asal', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(item['tanggal_pengaju'], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 28),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('Libur Pengganti', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(item['tanggal_target'], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_quote_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Alasan Penukaran', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
"""

regex = re.compile(r'        return Container\([\s\S]*?        \);')
content = regex.sub(new_history, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated tukar_libur UI")
