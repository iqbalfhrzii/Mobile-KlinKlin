import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../app/app.dart';
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
  static final ValueNotifier<bool> impersonationNotifier = ValueNotifier(false);
  static final ValueNotifier<Map<String, String>> impersonationInfoNotifier =
      ValueNotifier({});

  /// Inisialisasi status impersonasi dari local storage saat app dibuka
  static Future<void> initStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isImpersonating = prefs.getBool('is_impersonating') ?? false;
    impersonationNotifier.value = isImpersonating;
    if (isImpersonating) {
      impersonationInfoNotifier.value = {
        'name': prefs.getString('impersonated_user_name') ?? '',
        'role': prefs.getString('impersonated_user_role') ?? '',
        'branch': prefs.getString('impersonated_user_branch') ?? '',
      };
    } else {
      impersonationInfoNotifier.value = {};
    }
  }

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

  /// Impersonate target karyawan:
  /// 1. Backup session superadmin saat ini
  /// 2. Ganti token dan session aktif dengan user target
  /// 3. Update notifiers
  /// 4. Return role target
  static Future<String> impersonate(int karyawanId) async {
    try {
      final response = await _dio.post(
        '/superadmin/impersonate',
        data: {'karyawan_id': karyawanId},
      );

      final data = response.data;
      if (data == null || data['status'] != true) {
        throw Exception(data?['message'] ?? 'Gagal impersonasi akun');
      }

      final prefs = await SharedPreferences.getInstance();

      // Hanya simpan backup jika sebelumnya BELUM dalam mode impersonasi
      final alreadyImpersonating = prefs.getBool('is_impersonating') ?? false;
      if (!alreadyImpersonating) {
        await prefs.setString(
          'superadmin_saved_token',
          prefs.getString('auth_token') ?? '',
        );
        await prefs.setString(
          'superadmin_saved_name',
          prefs.getString('user_name') ?? 'Superadmin',
        );
        await prefs.setString(
          'superadmin_saved_email',
          prefs.getString('user_email') ?? '',
        );
        await prefs.setString(
          'superadmin_saved_role',
          prefs.getString('user_role') ?? 'Superadmin',
        );
        await prefs.setString(
          'superadmin_saved_branch',
          prefs.getString('user_branch') ?? '-',
        );
        await prefs.setString(
          'superadmin_saved_id',
          prefs.getString('user_id') ?? '',
        );
        await prefs.setString(
          'superadmin_saved_karyawan_id',
          prefs.getString('karyawan_id') ?? '',
        );
        final cabangId = prefs.getInt('user_cabang_id');
        if (cabangId != null) {
          await prefs.setInt('superadmin_saved_cabang_id', cabangId);
        }
        final photo = prefs.getString('user_photo');
        if (photo != null) {
          await prefs.setString('superadmin_saved_photo', photo);
        }
      }

      // Pasang session target
      final targetToken = data['token']?.toString() ?? '';
      final targetUser = data['data'] as Map<String, dynamic>;

      await prefs.setString('auth_token', targetToken);
      await prefs.remove('user_custom_name');

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

      // Tandai mode impersonasi
      await prefs.setBool('is_impersonating', true);
      await prefs.setString('impersonated_user_name', targetName);
      await prefs.setString('impersonated_user_role', targetRole);
      await prefs.setString('impersonated_user_branch', targetBranch);

      impersonationNotifier.value = true;
      impersonationInfoNotifier.value = {
        'name': targetName,
        'role': targetRole,
        'branch': targetBranch,
      };

      return targetRole;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? 'Gagal impersonasi akun',
      );
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Revert impersonation:
  /// Kembalikan token & identitas asli superadmin
  static Future<void> revertImpersonation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final savedToken = prefs.getString('superadmin_saved_token');
    if (savedToken == null || savedToken.isEmpty) {
      // Jika backup tidak ditemukan, jangan tinggalkan user terdampar
      await prefs.setBool('is_impersonating', false);
      impersonationNotifier.value = false;
      impersonationInfoNotifier.value = {};
      return;
    }

    // Kembalikan token superadmin
    await prefs.setString('auth_token', savedToken);
    await prefs.setString(
      'user_name',
      prefs.getString('superadmin_saved_name') ?? 'Superadmin',
    );
    await prefs.setString(
      'user_email',
      prefs.getString('superadmin_saved_email') ?? '',
    );
    await prefs.setString(
      'user_role',
      prefs.getString('superadmin_saved_role') ?? 'Superadmin',
    );
    await prefs.setString(
      'user_branch',
      prefs.getString('superadmin_saved_branch') ?? '-',
    );
    await prefs.setString(
      'user_cabang_name',
      prefs.getString('superadmin_saved_branch') ?? '-',
    );
    await prefs.setString(
      'user_id',
      prefs.getString('superadmin_saved_id') ?? 'KLK-SA-01',
    );
    await prefs.setString(
      'karyawan_id',
      prefs.getString('superadmin_saved_karyawan_id') ?? '',
    );

    final savedCabangId = prefs.getInt('superadmin_saved_cabang_id');
    if (savedCabangId != null) {
      await prefs.setInt('user_cabang_id', savedCabangId);
    } else {
      await prefs.remove('user_cabang_id');
    }

    final savedPhoto = prefs.getString('superadmin_saved_photo');
    if (savedPhoto != null) {
      await prefs.setString('user_photo', savedPhoto);
    } else {
      await prefs.remove('user_photo');
    }

    // Bersihkan data backup & flag impersonasi
    await prefs.remove('superadmin_saved_token');
    await prefs.remove('superadmin_saved_name');
    await prefs.remove('superadmin_saved_email');
    await prefs.remove('superadmin_saved_role');
    await prefs.remove('superadmin_saved_branch');
    await prefs.remove('superadmin_saved_id');
    await prefs.remove('superadmin_saved_karyawan_id');
    await prefs.remove('superadmin_saved_cabang_id');
    await prefs.remove('superadmin_saved_photo');

    await prefs.setBool('is_impersonating', false);
    await prefs.remove('impersonated_user_name');
    await prefs.remove('impersonated_user_role');
    await prefs.remove('impersonated_user_branch');

    impersonationNotifier.value = false;
    impersonationInfoNotifier.value = {};

    // Navigasi kembali ke SuperadminMainShell
    globalNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SuperadminMainShell()),
      (route) => false,
    );
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
