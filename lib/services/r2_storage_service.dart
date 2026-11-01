import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:chatty/services/image_compressor.dart';
import 'package:chatty/services/r2_credentials.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Cloudflare R2 configuration & high-speed media storage service.
///
/// Cloudflare R2 provides zero-egress fee object storage compatible with S3 API.
class R2StorageService {
  // ─── CONFIGURATION ──────────────────────────────────────────────────────────
  static const String accountId = R2Credentials.accountId;
  static const String bucketName = R2Credentials.bucketName;
  static const String accessKeyId = R2Credentials.accessKeyId;
  static const String secretAccessKey = R2Credentials.secretAccessKey;

  /// Public bucket URL connected to this R2 bucket.
  static const String publicDomain = R2Credentials.publicDomain;

  /// Whether Cloudflare R2 is configured and ready to be used.
  static bool get isConfigured =>
      accountId.isNotEmpty &&
      accountId != 'YOUR_CLOUDFLARE_ACCOUNT_ID' &&
      accessKeyId.isNotEmpty &&
      accessKeyId != 'YOUR_R2_ACCESS_KEY_ID' &&
      secretAccessKey.isNotEmpty &&
      secretAccessKey != 'YOUR_R2_SECRET_ACCESS_KEY';

  // ─── MEDIA UPLOAD APIS ──────────────────────────────────────────────────────

  /// Uploads a profile picture to R2 under `profile_pictures/<userId>.<ext>`.
  /// Automatically compresses the image to under 100 KB prior to uploading.
  static Future<String?> uploadProfilePicture(
      File rawFile, String userId) async {
    try {
      // 1. Compress image to under 100 KB
      final compressedFile =
          await ImageCompressor.compressUnder100Kb(rawFile);
      final bytes = await compressedFile.readAsBytes();

      final key = 'profile_pictures/$userId.jpg';
      return await _putObject(key: key, bytes: bytes, contentType: 'image/jpeg');
    } catch (e) {
      log('[R2StorageService] Error uploading profile picture: $e');
      return null;
    }
  }

  /// Uploads a chat image to R2 under `images/<conversationId>/<timestamp>.jpg`.
  /// Automatically compresses the image to strictly under 100 KB.
  static Future<String?> uploadChatImage(
      File rawFile, String conversationId) async {
    try {
      // 1. Compress image to under 100 KB
      final compressedFile =
          await ImageCompressor.compressUnder100Kb(rawFile);
      final bytes = await compressedFile.readAsBytes();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final key = 'images/$conversationId/$timestamp.jpg';
      return await _putObject(key: key, bytes: bytes, contentType: 'image/jpeg');
    } catch (e) {
      log('[R2StorageService] Error uploading chat image: $e');
      return null;
    }
  }

  /// Uploads a voice note to R2 under `audio/<conversationId>/<timestamp>.<ext>`.
  static Future<String?> uploadVoiceNote(
      File audioFile, String conversationId) async {
    try {
      final ext = audioFile.path.split('.').last.toLowerCase();
      final bytes = await audioFile.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final key = 'audio/$conversationId/$timestamp.$ext';

      final contentType = ext == 'm4a'
          ? 'audio/m4a'
          : (ext == 'mp3' ? 'audio/mpeg' : 'audio/aac');

      return await _putObject(key: key, bytes: bytes, contentType: contentType);
    } catch (e) {
      log('[R2StorageService] Error uploading voice note: $e');
      return null;
    }
  }

  /// Deletes an object from Cloudflare R2 given its full URL.
  static Future<bool> deleteObject(String publicUrl) async {
    if (!isConfigured) return false;
    try {
      final uri = Uri.parse(publicUrl);
      final key = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

      final now = DateTime.now().toUtc();
      final dateStamp = _formatDateStamp(now);
      final amzDate = _formatAmzDate(now);

      const host = '$accountId.r2.cloudflarestorage.com';
      final canonicalUri = '/$bucketName/$key';
      final url = Uri.parse('https://$host$canonicalUri');

      final payloadHash = sha256.convert(const []).toString();

      final canonicalHeaders = 'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
      const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

      final canonicalRequest =
          'DELETE\n$canonicalUri\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

      final authHeader = _buildAuthHeader(
        method: 'DELETE',
        canonicalRequest: canonicalRequest,
        dateStamp: dateStamp,
        amzDate: amzDate,
        signedHeaders: signedHeaders,
      );

      final response = await http.delete(
        url,
        headers: {
          'Host': host,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'Authorization': authHeader,
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      log('[R2StorageService] Error deleting object: $e');
      return false;
    }
  }

  // ─── INTERNAL S3 / SIGV4 ENGINE ─────────────────────────────────────────────

  /// Uploads bytes directly to Cloudflare R2 via S3-compatible SigV4 PUT.
  static Future<String?> _putObject({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!isConfigured) {
      log('[R2StorageService] WARNING: R2 credentials are not set in R2StorageService.');
      return null;
    }

    final now = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(now);
    final amzDate = _formatAmzDate(now);

    const host = '$accountId.r2.cloudflarestorage.com';
    final canonicalUri = '/$bucketName/$key';
    final url = Uri.parse('https://$host$canonicalUri');

    final payloadHash = sha256.convert(bytes).toString();

    final canonicalHeaders =
        'content-type:$contentType\nhost:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        'PUT\n$canonicalUri\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    final authHeader = _buildAuthHeader(
      method: 'PUT',
      canonicalRequest: canonicalRequest,
      dateStamp: dateStamp,
      amzDate: amzDate,
      signedHeaders: signedHeaders,
    );

    final response = await http.put(
      url,
      headers: {
        'Host': host,
        'Content-Type': contentType,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': payloadHash,
        'Authorization': authHeader,
      },
      body: bytes,
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      final cleanBase = publicDomain.endsWith('/')
          ? publicDomain.substring(0, publicDomain.length - 1)
          : publicDomain;
      final publicUrl = '$cleanBase/$key';
      log('[R2StorageService] Upload success! Public URL: $publicUrl');
      return publicUrl;
    } else {
      log('[R2StorageService] Upload failed (${response.statusCode}): ${response.body}');
      return null;
    }
  }

  static String _buildAuthHeader({
    required String method,
    required String canonicalRequest,
    required String dateStamp,
    required String amzDate,
    required String signedHeaders,
  }) {
    const region = 'auto';
    const service = 's3';

    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    final signingKey = _getSigningKey(secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    return 'AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';
  }

  static List<int> _getSigningKey(
      String key, String dateStamp, String region, String service) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }

  static String _formatDateStamp(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatAmzDate(DateTime dt) {
    return '${_formatDateStamp(dt)}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }
}
