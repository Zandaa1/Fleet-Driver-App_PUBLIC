import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../main.dart' show apiService;

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _storageKey = 'pending_expenses_queue';
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  bool _isSyncing = false;

  Future<void> initialize() async {
    final expenses = await _loadFromStorage();
    pendingCount.value = expenses.length;
  }

  Future<void> savePendingExpense(String tripId, AddTripExpenseRequest request) async {
    final pending = PendingExpenseDto(
      tripId: tripId,
      request: request,
      timestamp: DateTime.now(),
    );

    final expenses = await _loadFromStorage();
    expenses.add(pending);
    await _saveToStorage(expenses);
    pendingCount.value = expenses.length;
  }

  Future<List<PendingExpenseDto>> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey);
    if (jsonList == null) return [];

    return jsonList
        .map((e) => PendingExpenseDto.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> _saveToStorage(List<PendingExpenseDto> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  Future<void> syncPendingExpenses() async {
    if (_isSyncing || pendingCount.value == 0) return;
    _isSyncing = true;

    try {
      final expenses = await _loadFromStorage();
      final List<PendingExpenseDto> remaining = [];

      for (final item in expenses) {
        try {
          await apiService.addExpense(item.tripId, item.request);
          // Successfully synced
        } catch (e) {
          // Still failing (likely still no internet), keep in queue
          remaining.add(item);
        }
      }

      await _saveToStorage(remaining);
      pendingCount.value = remaining.length;
    } finally {
      _isSyncing = false;
    }
  }
}

final offlineSyncService = OfflineSyncService();
