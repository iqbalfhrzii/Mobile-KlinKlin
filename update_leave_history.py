import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\leave_history_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'app_constants.dart' not in content:
    content = content.replace("import '../../../core/theme/app_colors.dart';", "import '../../../core/theme/app_colors.dart';\nimport '../../../core/constants/app_constants.dart';")

helper = """
  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor"""
if '_showFullImage' not in content:
    content = content.replace("  Color _getStatusColor", helper)

photo_ui = """                                Text(item['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                if (item['bukti_foto'] != null && item['bukti_foto'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () {
                                      final url = item['bukti_foto'].toString().startsWith('http') 
                                          ? item['bukti_foto'] 
                                          : '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/${item['bukti_foto']}';
                                      _showFullImage(context, url);
                                    },
                                    child: Container(
                                      height: 100,
                                      width: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            item['bukti_foto'].toString().startsWith('http') 
                                                ? item['bukti_foto'] 
                                                : '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/${item['bukti_foto']}'
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ]"""
if "item['bukti_foto']" not in content:
    content = content.replace("                                Text(item['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),", photo_ui)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('UI riwayat dipercantik dengan foto')
