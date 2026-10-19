/**
 * gcash_receipt_service.dart  —  §1.5 GCash Receipt OCR
 * ───────────────────────────────────────────────────────
 * Calls POST /api/payments/extract-receipt
 * Returns temp Cloudinary URL + extracted GCash ref number + sent amount.
 *
 * Called BEFORE placing the order — customer must see and confirm
 * the extracted info before tapping "Confirm & Place Order".
 */

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

// ─── Result model ─────────────────────────────────────────────────────────────
class GcashExtractResult {
  final String  tempUrl;
  final String? gcashRefNumber; // null if OCR couldn't extract
  final double? gcashAmount;    // null if OCR couldn't extract
  final int     ocrConfidence;
  final bool    refFound;
  final bool    amountFound;

  const GcashExtractResult({
    required this.tempUrl,
    required this.gcashRefNumber,
    required this.gcashAmount,
    required this.ocrConfidence,
    required this.refFound,
    required this.amountFound,
  });

  factory GcashExtractResult.fromJson(Map<String, dynamic> json) {
    return GcashExtractResult(
      tempUrl:        json['temp_url']         as String,
      gcashRefNumber: json['gcash_ref_number'] as String?,
      gcashAmount:    (json['gcash_amount']    as num?)?.toDouble(),
      ocrConfidence:  (json['ocr_confidence']  as num?)?.toInt() ?? 0,
      refFound:       json['ref_found']        as bool? ?? false,
      amountFound:    json['amount_found']     as bool? ?? false,
    );
  }
}

class GcashExtractException implements Exception {
  final String message;
  const GcashExtractException(this.message);
  @override
  String toString() => message;
}

// ─── Service ──────────────────────────────────────────────────────────────────
class GcashReceiptService {
  GcashReceiptService._();
  static final GcashReceiptService instance = GcashReceiptService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Upload receipt screenshot and extract GCash ref + amount via backend OCR.
  /// Returns [GcashExtractResult] — caller decides whether to proceed or re-upload.
  Future<GcashExtractResult> extractReceipt({
    required File   imageFile,
    required String mimeType, // 'image/jpeg' | 'image/png' | 'image/webp'
  }) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final uri   = Uri.parse('$_baseUrl/api/payments/extract-receipt');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
          'receipt',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final body     = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return GcashExtractResult.fromJson(body);
      }

      final message = body['message'] as String? ?? 'Upload failed.';
      throw GcashExtractException(message);
    } on SocketException {
      throw const GcashExtractException('No internet connection.');
    } on GcashExtractException {
      rethrow;
    } catch (e) {
      throw GcashExtractException('Upload failed: ${e.toString()}');
    }
  }
}