import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthState {
  final String? token;
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.token, this.user, this.isLoading = false, this.error});

  AuthState copyWith({
    String? token,
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');
    if (token != null && userJson != null) {
      state = AuthState(
        token: token,
        user: User.fromJson(jsonDecode(userJson)),
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _authService.login(email, password);
      final token = data['accessToken'];
      final user = User.fromJson(data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_user', jsonEncode(data['user']));

      state = AuthState(token: token, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> loginOperator(String operatorId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _authService.loginOperator(operatorId);
      final token = data['accessToken'];
      final user = User.fromJson(data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_user', jsonEncode(data['user']));

      state = AuthState(token: token, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401) return 'Credenciales inválidas';
      if (e.response?.statusCode == 403) return 'Acceso denegado';
      if (e.response != null && e.response!.statusCode != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) return data['message'].toString();
        return 'Error del servidor (${e.response!.statusCode})';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Tiempo de espera agotado. Intenta de nuevo.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Sin conexión a internet';
      }
    }
    if (e is SocketException) return 'Sin conexión a internet';
    return 'Error de conexión. Intenta de nuevo.';
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
