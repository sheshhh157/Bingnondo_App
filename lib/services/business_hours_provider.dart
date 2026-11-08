import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/business_hours_models.dart';
import 'business_hours_service.dart';

/// Keeps the cafe's open/closed state fresh for the whole app.
///
/// The backend computes the status from the `business_hours` table using
/// Asia/Manila time. We refresh once a minute so the home pill flips to
/// "Closed" automatically at closing time.
class BusinessHoursProvider extends ChangeNotifier {
  BusinessHoursStatus? _status;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _timer;
  bool _started = false;

  BusinessHoursStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasStatus => _status != null;

  /// True only when we positively know the cafe is closed. When the status
  /// hasn't loaded yet we don't block the UI — the backend still enforces the
  /// order window on POST /api/orders.
  bool get isKnownClosed => _status != null && !_status!.isOpen;

  bool get isOpen => _status?.isOpen ?? true;

  String get message => _status?.message ?? '';

  /// Start the initial fetch + minute-by-minute refresh. Safe to call twice.
  void start() {
    if (_started) return;
    _started = true;
    load();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => load(silent: true),
    );
  }

  Future<void> load({bool silent = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    if (!silent) notifyListeners();

    try {
      _status = await BusinessHoursService.instance.fetchStatus();
      _errorMessage = null;
    } on BusinessHoursApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Could not check business hours.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
