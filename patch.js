const fs = require('fs');
const file = 'c:/Users/HP VICTUS/Documents/Mobile/lib/features/orders/screens/order_detail_screen.dart';
let content = fs.readFileSync(file, 'utf8');

// Inject _formatDuration
if (!content.includes('_formatDuration')) {
    content = content.replace('}\n\nclass _AddBonusSheet extends StatefulWidget {', `  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    
    if (hours > 0 && minutes > 0) {
      return \`\${hours}j \${minutes}m\`;
    } else if (hours > 0) {
      return \`\${hours}j\`;
    } else {
      return \`\${minutes}m\`;
    }
  }
}

class _AddBonusSheet extends StatefulWidget {`);
}

// Inject UI Row
const regex = /(color:\s*cleaner\.statusPengerjaan ==\s*CleanerWorkStatus\.finished\s*\?\s*AppColors\.statusDone\s*:\s*AppColors\.primary,\s*\),\s*\),\s*\),)/;

if (!content.includes('Icons.timer_outlined')) {
    content = content.replace(regex, `$1
                          if (cleaner.statusPengerjaan == CleanerWorkStatus.finished && cleaner.startedAt != null && cleaner.finishedAt != null) ...[
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(cleaner.startedAt!, cleaner.finishedAt!),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],`);
}

fs.writeFileSync(file, content);
console.log('Done');
