import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../shell/superadmin_main_shell.dart';
import '../../cleaner/shell/cleaner_main_shell.dart';
import '../../finance/shell/finance_main_shell.dart';
import '../../hrd/shell/hrd_main_shell.dart';
import '../../operasional/shell/operasional_main_shell.dart';
import '../../designer/shell/designer_main_shell.dart';
import '../../marketing/shell/marketing_main_shell.dart';
import '../../ceo/shell/ceo_main_shell.dart';
import '../../shell/main_shell.dart';

class SuperadminService {
  static final Dio _dio = ApiClient.instance;

  /// Ambil grup karyawan (Kantor Pusat, CS, Cleaner per Cabang, Lainnya)
  static Future<List<Map<String, dynamic>>> getGroups() async {
    try {
      final response = await _dio.get('/superadmin/groups');
      final data = response.data;
      if (data != null && data['status'] == true && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal memuat grup karyawan',
      );
    } catch (e) {
      throw Exception('Gagal memuat data: $e');
    }
  }

  /// Ambil daftar karyawan dengan filter grup dan kata kunci pencarian
  static Future<List<Map<String, dynamic>>> getKaryawans({
    String? group,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (group != null && group.isNotEmpty && group != 'all') {
        queryParams['group'] = group;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        '/superadmin/karyawans',
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data != null && data['status'] == true && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal memuat daftar karyawan',
      );
    } catch (e) {
      throw Exception('Gagal memuat data: $e');
    }
  }

  /// Masuk langsung ke akun target karyawan seperti beneran login:
  /// Menyimpan token autentikasi & profil user target ke SharedPreferences
  static Future<String> loginAs(int karyawanId) async {
    try {
      final response = await _dio.post(
        '/superadmin/impersonate',
        data: {'karyawan_id': karyawanId},
      );

      final data = response.data;
      if (data == null || data['status'] != true) {
        throw Exception(data?['message'] ?? 'Gagal masuk ke akun');
      }

      final prefs = await SharedPreferences.getInstance();

      // Pasang session target persis seperti login biasa
      final targetToken = data['token']?.toString() ?? '';
      final targetUser = data['data'] as Map<String, dynamic>;

      await prefs.setString('auth_token', targetToken);
      await prefs.remove('user_custom_name');
      await prefs.remove('is_impersonating');
      await prefs.remove('impersonated_user_name');
      await prefs.remove('impersonated_user_role');
      await prefs.remove('impersonated_user_branch');

      final targetName = targetUser['nama']?.toString() ?? '';
      final targetEmail = targetUser['email']?.toString() ?? '';
      final targetRole =
          targetUser['jabatan'] is Map
              ? targetUser['jabatan']['nama_jabatan']?.toString() ?? 'Karyawan'
              : 'Karyawan';
      final targetBranch =
          targetUser['cabang'] is Map
              ? targetUser['cabang']['nama_cabang']?.toString() ?? '-'
              : '-';
      final targetId = targetUser['id']?.toString() ?? '0';

      await prefs.setString('user_name', targetName);
      await prefs.setString('user_email', targetEmail);
      await prefs.setString('user_role', targetRole);
      await prefs.setString('user_branch', targetBranch);
      await prefs.setString('user_cabang_name', targetBranch);
      await prefs.setString('user_id', 'KLK-${targetRole.toUpperCase()}-0$targetId');
      await prefs.setString('karyawan_id', targetId);

      int? parsedCabangId;
      if (targetUser['cabang_id'] != null) {
        parsedCabangId = int.tryParse(targetUser['cabang_id'].toString());
      } else if (targetUser['cabang'] is Map &&
          targetUser['cabang']['id'] != null) {
        parsedCabangId = int.tryParse(
          targetUser['cabang']['id'].toString(),
        );
      }
      if (parsedCabangId != null) {
        await prefs.setInt('user_cabang_id', parsedCabangId);
      } else {
        await prefs.remove('user_cabang_id');
      }

      if (targetUser['foto_profil'] != null) {
        await prefs.setString(
          'user_photo',
          targetUser['foto_profil'].toString(),
        );
      } else {
        await prefs.remove('user_photo');
      }

      return targetRole;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal masuk ke akun karyawan',
      );
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Helper untuk navigasi ke shell yang sesuai dengan target role
  static Widget getShellForRole(String role) {
    final r = role.toLowerCase().trim();
    if (r.contains('superadmin')) {
      return const SuperadminMainShell();
    } else if (r.contains('cleaner')) {
      return const CleanerMainShell();
    } else if (r.contains('finance') || r.contains('keuangan')) {
      return const FinanceMainShell();
    } else if (r.contains('hrd')) {
      return const HrdMainShell();
    } else if (r.contains('operasional')) {
      return const OperasionalMainShell();
    } else if (r.contains('designer') || r.contains('desain')) {
      return const DesignerMainShell();
    } else if (r.contains('marketing')) {
      return const MarketingMainShell();
    } else if (r.contains('ceo') || r.contains('owner')) {
      return const CeoMainShell();
    } else {
      return const MainShell(); // Customer Service / default
    }
  }
}
