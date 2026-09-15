import 'package:flutter/foundation.dart';
import '../models/notification_settings_models.dart';
import '../mock/mock_data.dart';
import 'notifications_settings_service.dart';

enum SettingsLoadState { initial, loading, loaded, error }
enum SettingsSaveState { idle, saving, saved, error }

class AccountSettingsProvider extends ChangeNotifier {
  AccountProfile? _profile;
  SettingsLoadState _loadState = SettingsLoadState.initial;
  SettingsSaveState _saveState = SettingsSaveState.idle;
  SettingsSaveState _pwSaveState = SettingsSaveState.idle;
  String? _loadError;
  String? _saveError;
  String? _pwError;

  AccountProfile? get profile => _profile;
  SettingsLoadState get loadState => _loadState;
  SettingsSaveState get saveState => _saveState;
  SettingsSaveState get pwSaveState => _pwSaveState;
  String? get loadError => _loadError;
  String? get saveError => _saveError;
  String? get pwError => _pwError;
  bool get isLoaded => _loadState == SettingsLoadState.loaded;

  Future<void> loadProfile() async {
    if (_loadState == SettingsLoadState.loading) return;
    _loadState = SettingsLoadState.loading;
    _loadError = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 500));
        _profile = AccountProfile.fromJson(kMockAccountProfile);
      } else {
        _profile =
        await NotificationsSettingsService.instance.fetchProfile();
      }
      _loadState = SettingsLoadState.loaded;
    } on SettingsApiException catch (e) {
      _loadError = e.message;
      _loadState = SettingsLoadState.error;
    } catch (_) {
      _loadError = 'Could not load profile.';
      _loadState = SettingsLoadState.error;
    }
    notifyListeners();
  }

  Future<bool> updateProfile(UpdateProfileRequest req) async {
    _saveState = SettingsSaveState.saving;
    _saveError = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 800));
        // Optimistically update local model
        _profile = AccountProfile(
          id: _profile!.id,
          email: _profile!.email,
          firstName: req.firstName,
          lastName: req.lastName,
          mobileNumber: req.mobileNumber ?? _profile!.mobileNumber,
          address: req.address ?? _profile!.address,
          profileCompleted: true,
          hasSavedPayment: _profile!.hasSavedPayment,
          savedPaymentLast4: _profile!.savedPaymentLast4,
          savedPaymentType: _profile!.savedPaymentType,
        );
      } else {
        _profile =
        await NotificationsSettingsService.instance.updateProfile(req);
      }
      _saveState = SettingsSaveState.saved;
      notifyListeners();
      // Reset saved state after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      _saveState = SettingsSaveState.idle;
      notifyListeners();
      return true;
    } on SettingsApiException catch (e) {
      _saveError = e.message;
      _saveState = SettingsSaveState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(ChangePasswordRequest req) async {
    _pwSaveState = SettingsSaveState.saving;
    _pwError = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 800));
        // Mock: "wrong current password" simulation
        if (req.currentPassword != 'Test1234') {
          throw const SettingsApiException(
              'Current password is incorrect.', statusCode: 401);
        }
      } else {
        await NotificationsSettingsService.instance.changePassword(req);
      }
      _pwSaveState = SettingsSaveState.saved;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      _pwSaveState = SettingsSaveState.idle;
      notifyListeners();
      return true;
    } on SettingsApiException catch (e) {
      _pwError = e.message;
      _pwSaveState = SettingsSaveState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeSavedPayment() async {
    try {
      if (!kUseMock) {
        await NotificationsSettingsService.instance.removeSavedPayment();
      }
      _profile = AccountProfile(
        id: _profile!.id,
        email: _profile!.email,
        firstName: _profile!.firstName,
        lastName: _profile!.lastName,
        mobileNumber: _profile!.mobileNumber,
        address: _profile!.address,
        profileCompleted: _profile!.profileCompleted,
        hasSavedPayment: false,
        savedPaymentLast4: null,
        savedPaymentType: null,
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void resetSaveStates() {
    _saveState = SettingsSaveState.idle;
    _pwSaveState = SettingsSaveState.idle;
    _saveError = null;
    _pwError = null;
    notifyListeners();
  }
}