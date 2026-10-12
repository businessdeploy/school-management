import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';
import '../../models/fee_model.dart';
import '../../config/app_config.dart';
import '../../utils/fee_calculator.dart';

class FeesApi {
  // Get fees
  // API: https://demo.smart-school.in/api/webservice/fees
  // Body: {"student_id":"98"} (dynamic)
  // Headers: Authorization, Auth-Key, Client-Service, Content-Type, User-ID, Cookie (all dynamic)

  static Future<Map<String, dynamic>> getProcessingFees(String studentId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();

      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'Base URL not set', 'fees': <ProcessingFee>[]};
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('getProcessingfees'));
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'student_id': studentId,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        final jsonData = jsonDecode(response.body);
        
        final List<Map<String, dynamic>> rawFees = _extractFeesList(jsonData);
        final List<ProcessingFee> fees = rawFees.map((f) => ProcessingFee.fromJson(f)).toList();
        
        return {
          'status': 1,
          'message': 'Success',
          'fees': fees,
          'grand_fee': jsonData['grand_fee'],
          'raw_response': jsonData,
        };
      }
      return {'status': 0, 'message': 'Error loading processing fees', 'fees': <ProcessingFee>[]};
    } catch (e) {
      return {'status': 0, 'message': 'Error: $e', 'fees': <ProcessingFee>[]};
    }
  }

  static Future<Map<String, dynamic>> getOfflineBankPayments(String studentId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return {'status': 0, 'payments': <OfflinePayment>[]};

      final url = Uri.parse(await AppConfig.getApiEndpoint('getOfflineBankPayments'));
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'student_id': studentId,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        final jsonData = jsonDecode(response.body);
        
        List<dynamic> paymentsList = [];
        if (jsonData['result_array'] is List) {
           paymentsList = jsonData['result_array'];
        }
        
        
        final List<OfflinePayment> payments = paymentsList.map((e) => OfflinePayment.fromJson(e)).toList();
        
        // Log parsed attachments

        
        return {
          'status': 1,
          'payments': payments,
          'raw_response': jsonData,
        };
      }
      return {'status': 0, 'payments': <OfflinePayment>[]};
    } catch (e) {
      
      return {'status': 0, 'payments': <OfflinePayment>[]};
    }
  }

  // Get balance fees
  // API: https://demo.smart-school.in/api/webservice/getBalanceFee
  // Body: {"student_session_id":"226", "student_fees_master_id":"543", "trans_fee_id":"", "fee_category":"fees", "fee_groups_feetype_id":"517"} (all dynamic)
  // Headers: Authorization, Auth-Key, Client-Service, Content-Type, User-ID, Cookie (all dynamic)
  static Future<Map<String, dynamic>> getBalanceFee(
    String studentSessionId,
    String studentFeesMasterId,
    String feeCategory,
    String feeGroupsFeetypeId, {
    String? transFeeId,
    List<String>? feeDiscountGroup,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return {'status': 0, 'balance_fee': null};

      final url = Uri.parse(await AppConfig.getApiEndpoint('getBalanceFee'));
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final bodyMap = <String, dynamic>{
        'student_session_id': studentSessionId,
        'student_fees_master_id': studentFeesMasterId,
        'trans_fee_id': transFeeId ?? '',
        'fee_category': feeCategory,
        'fee_groups_feetype_id': feeGroupsFeetypeId,
      };
      
      if (feeDiscountGroup != null && feeDiscountGroup.isNotEmpty) {
        bodyMap['fee_discount_group'] = feeDiscountGroup;
      }
      
      final response = await http.post(url, headers: headers, body: jsonEncode(bodyMap));

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        final jsonData = jsonDecode(response.body);
        final balanceFee = BalanceFee.fromJson(jsonData);
        
        return {
          'status': 1,
          'message': 'Success',
          'balance_fee': balanceFee,
          // Compatibility fields
          'balance': balanceFee.balance,
          'remain_amount_fine': balanceFee.remainAmountFine,
          'student_fees': balanceFee.studentFees,
          'discount_fee': balanceFee.discountsApplied,
          'discount_not_applied': balanceFee.discountsNotApplied,
          'raw_response': jsonData,
        };
      }
      return {'status': 0, 'balance_fee': null};
    } catch (e) {
      return {'status': 0, 'balance_fee': null};
    }
  }

  // Pay fees
  // API: https://demo.smart-school.in/api/payment/paymentrequest
  // Method: POST
  // Headers: Auth-Key, Client-Service, Content-Type, User-ID, Authorization (all dynamic)
  // Body: {student_fees_master_id, fee_discount_group, student_transport_fee_id, student_id, fee_groups_feetype_id, amount, email, phone} (all dynamic)
  // Response: {redirect_url, key, api_publishable_key, total, ...}
  static Future<Map<String, dynamic>> payFees(
    String studentFeesMasterId,
    String studentId,
    String feeGroupsFeetypeId, {
    List<String>? discountIds, // Legacy format - array of IDs
    List<Map<String, dynamic>>? feeDiscountGroup, // NEW: Format [{ "id": amount }, { "id": amount }]
    String? paymentMode,
    String? amount,
    String? email,
    String? phone,
    String? feeCategory,
    String? studentSessionId,
    String? studentTransportFeeId,
    String? paymentDetail,
    String? processingChargeType,
    String? gatewayProcessingCharge,
    String? appliedFeeDiscount,
    String? guardianPhone,
    String? studentName,
    String? fineAmount, // Fine amount from API (only if > 0)
    String? baseAmount, // Base amount (balance) from API - for backend calculation
    String? currency, // NEW: Currency code (e.g., EUR)
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return {'status': 0, 'message': 'Base URL not set'};

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // CRITICAL: fee_discount_group format per spec: [{ "id": amount }]
      // If we already have the object format, use it as is.
      dynamic feeDiscountGroupValue;
      if (feeDiscountGroup != null && feeDiscountGroup.isNotEmpty) {
        feeDiscountGroupValue = feeDiscountGroup;
      } else {
        feeDiscountGroupValue = [];
      }

      // Use exact body format as per API spec - all values are dynamic
      final Map<String, dynamic> bodyMap = {
        'student_fees_master_id': studentFeesMasterId, // Dynamic parameter
        'fee_discount_group': feeDiscountGroupValue, // Format: [{ "id": amount }, { "id": amount }]
        'student_transport_fee_id':
            studentTransportFeeId ?? '', // Can be empty, should be dynamic if available
        'student_id': studentId, // Dynamic parameter
        'fee_groups_feetype_id': feeGroupsFeetypeId, // Dynamic parameter
      };

      // Add payment details if provided (amount, email, phone)
      if (amount != null && amount.isNotEmpty) {
        bodyMap['amount'] = amount;
      }
      if (email != null && email.isNotEmpty) {
        bodyMap['email'] = email;
      }
      if (phone != null && phone.isNotEmpty) {
        bodyMap['phone'] = phone;
      }
      
      // CRITICAL: Extract ALL discount IDs from either feeDiscountGroup or discountIds
      final List<String> allSelectedIds = [];
      if (feeDiscountGroup != null && feeDiscountGroup.isNotEmpty) {
        for (var item in feeDiscountGroup) {
          if (item is Map && item.isNotEmpty) {
            allSelectedIds.add(item.keys.first.toString());
          } else {
            allSelectedIds.add(item.toString());
          }
        }
      } else if (discountIds != null && discountIds.isNotEmpty) {
        allSelectedIds.addAll(discountIds);
      }
      
      if (allSelectedIds.isNotEmpty) {
        final joinIds = allSelectedIds.join(',');
        bodyMap['applied_discount_id'] = joinIds;
        bodyMap['fee_discount_id'] = joinIds;
        bodyMap['discount_id'] = joinIds;
        bodyMap['student_fee_discount_id'] = joinIds;
        
      }
      if (feeCategory != null && feeCategory.isNotEmpty) {
        bodyMap['fee_category'] = feeCategory;
      }
      if (studentSessionId != null && studentSessionId.isNotEmpty) {
        bodyMap['student_session_id'] = studentSessionId;
      }
      if (paymentDetail != null && paymentDetail.isNotEmpty) {
        bodyMap['payment_detail'] = paymentDetail;
      }
      if (processingChargeType != null && processingChargeType.isNotEmpty) {
        bodyMap['processing_charge_type'] = processingChargeType;
      }
      if (gatewayProcessingCharge != null &&
          gatewayProcessingCharge.isNotEmpty) {
        bodyMap['gateway_processing_charge'] = gatewayProcessingCharge;
      }
      if (appliedFeeDiscount != null && appliedFeeDiscount.isNotEmpty) {
        bodyMap['applied_fee_discount'] = appliedFeeDiscount;
        bodyMap['discount_amount'] = appliedFeeDiscount;
        bodyMap['amount_discount'] = appliedFeeDiscount;
        bodyMap['fee_discount_amount'] = appliedFeeDiscount;
      }
      // ⚠️ CRITICAL: Send base amount (balance) separately
      // Backend might need this to calculate: base + fine - discount
      if (baseAmount != null && baseAmount.isNotEmpty) {
        bodyMap['base_amount'] = baseAmount;
        bodyMap['balance_amount'] = baseAmount;
      }
      
      // ⚠️ CRITICAL: Send fine amount separately to ensure backend includes it in total
      // Backend might recalculate from base - discount, so we need to explicitly send fine
      if (fineAmount != null && fineAmount.isNotEmpty && double.parse(fineAmount) > 0) {
        bodyMap['fine_amount'] = fineAmount;
        bodyMap['fine'] = fineAmount;
      }
      
      if (guardianPhone != null && guardianPhone.isNotEmpty) {
        bodyMap['guardian_phone'] = guardianPhone;
      }
      if (studentName != null && studentName.isNotEmpty) {
        bodyMap['name'] = studentName;
      }
      
      // ⚠️ CRITICAL: Send total amount - this is what should be charged
      // Backend should use this directly, not recalculate
      if (amount != null && amount.isNotEmpty) {
        bodyMap['total'] = amount;
        // Also send as amount (some backends use 'amount' field)
        bodyMap['amount'] = amount;

      }
      
      // Add return_url to API request body if needed
      // Some payment gateways require return_url in the initial request
      // Use deep link URL scheme that opens the app after payment
      final returnUrl = 'smartschool://payment/success';
      bodyMap['return_url'] = returnUrl;
      

      final body = jsonEncode(bodyMap);

      // Support both new and legacy paymentrequest endpoints while always using BASE_URL.
      // Priority: /api/payment/paymentrequest (as per user's API spec)
      final endpoints = [
        '$baseUrl/api/payment/paymentrequest', // Primary endpoint (as per API spec)
        '$baseUrl/payment/paymentrequest', // Fallback
      ];

      for (final endpoint in endpoints) {
        final url = Uri.parse(endpoint);
        try {
          final response = await http
              .post(url, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));

          
          
          
          // ERROR HANDLING: Check for empty response body
          if (response.body.isEmpty || response.body.trim().isEmpty) {
            
            return {
              'status': 0,
              'message': 'Unable to process payment. Please try again later.',
            };
          }
          


          if (response.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(response.body)) {
            try {
              // ERROR HANDLING: Safe JSON parsing
              if (response.body.trim().isEmpty) {
                
                return {
                  'status': 0,
                  'message': 'Unable to process payment. Please try again later.',
                };
              }
              
              final jsonData = jsonDecode(response.body);
              

              // Handle different response structures
              if (jsonData is Map) {
                
                

                // CRITICAL: Check for redirect_url FIRST - if it exists, consider it success
                // regardless of status field (as per user's API response structure)
                String? paymentUrl;

                // Priority 1: Check redirect_url in root (as per API spec)
                if (jsonData['redirect_url'] != null &&
                    jsonData['redirect_url'].toString().trim().isNotEmpty) {
                  paymentUrl = jsonData['redirect_url'].toString().trim();
                  paymentUrl = jsonData['redirect_url'].toString().trim();
                  
                  // NEW: Append currency and amount to payment URL if needed
                  String finalPaymentUrl = paymentUrl;
                  if (currency != null && currency.isNotEmpty && !finalPaymentUrl.contains('currency=')) {
                    final separator = finalPaymentUrl.contains('?') ? '&' : '?';
                    finalPaymentUrl += '${separator}currency=$currency';
                  }
                  
                  if (amount != null && amount.isNotEmpty && !finalPaymentUrl.contains('amount=')) {
                    final separator = finalPaymentUrl.contains('?') ? '&' : '?';
                    finalPaymentUrl += '${separator}amount=$amount&total=$amount';
                  }

                  if (finalPaymentUrl != paymentUrl) {
                    
                    jsonData['redirect_url'] = finalPaymentUrl;
                    paymentUrl = finalPaymentUrl;
                  }
                  
                  
                } 
                // Priority 2: Check in nested data object
                else if (jsonData['data'] is Map) {
                  final data = jsonData['data'] as Map;
                  
                  if (data['redirect_url'] != null &&
                      data['redirect_url'].toString().trim().isNotEmpty) {
                    paymentUrl = data['redirect_url'].toString().trim();
                    
                  }
                }
                // Priority 3: Fallback to other possible keys
                if (paymentUrl == null) {
                  for (String key in [
                    'payment_url',
                    'url',
                    'paymentUrl',
                    'redirectUrl',
                    'payment_link',
                    'link',
                    'checkout_url',
                    'checkoutUrl',
                  ]) {
                    if (jsonData[key] != null &&
                        jsonData[key].toString().trim().isNotEmpty) {
                      paymentUrl = jsonData[key].toString().trim();
                      
                      break;
                    }
                  }
                }

              // Extract other response fields as per API spec
              final key = jsonData['key'];
              final apiPublishableKey = jsonData['api_publishable_key'];
              final total = jsonData['total'];
              final invoice = jsonData['invoice'];
              final paymentDetail = jsonData['payment_detail'];
              // Extract return_url if provided by API
              final returnUrl = jsonData['return_url']?.toString();

              // CRITICAL: Extract currency symbol from invoice.symbol
              // Per spec: "invoice": { "symbol": "$", "currency_name": "USD" }
              String? currencySymbol;
              String? currencyName;
              if (invoice is Map) {
                currencySymbol = invoice['symbol']?.toString();
                currencyName = invoice['currency_name']?.toString();
                
                
                
              } else {
                
              }



                // CRITICAL: If redirect_url exists, consider it SUCCESS regardless of status field
                // The API response may not have an explicit status field, but redirect_url indicates success
                final isSuccess = paymentUrl != null && paymentUrl.isNotEmpty;
                
                // Check for explicit status field, but prioritize redirect_url
                final explicitStatus = jsonData['status'];
                final hasExplicitSuccess = explicitStatus == 1 || 
                                          explicitStatus == '1' || 
                                          explicitStatus == true ||
                                          jsonData['success'] == true;



                // If redirect_url exists, it's definitely a success
                if (isSuccess) {
                  
                  
                  // Return full response structure with redirect_url prioritized
                  return {
                    'status': 1, // Always 1 if redirect_url exists
                    'message': 'Payment request created successfully',
                    'redirect_url': paymentUrl, // Primary key as per API spec
                    'payment_url': paymentUrl, // Alias for compatibility
                    'url': paymentUrl, // Alias for compatibility
                    'return_url': returnUrl, // Return URL provided by API
                    'key': key,
                    'api_publishable_key': apiPublishableKey,
                    'total': total,
                    'invoice': invoice,
                    'currency_symbol': currencySymbol, // From invoice.symbol
                    'currency_name': currencyName, // From invoice.currency_name
                    'payment_detail': paymentDetail,
                    'data': jsonData, // Preserve full response
                    // Preserve all other fields from response
                    ...jsonData.map((k, v) => MapEntry(k.toString(), v)),
                  };
                } else {
                  // No redirect_url found - check if there's an explicit error
                  final errorMessage = jsonData['message']?.toString() ?? 
                                      jsonData['error']?.toString() ??
                                      'Payment request failed - no redirect URL received';
                  
                  
                  
                  
                  return {
                    'status': hasExplicitSuccess ? 1 : 0,
                    'message': errorMessage,
                    'redirect_url': null,
                    'data': jsonData, // Preserve full response for debugging
                  };
                }
              } else {
                
              }
            } catch (e, stackTrace) {
              
            }

            final data = ResponseValidator.validateAndParseJson(
              response.body,
              'payment',
            );
            return data;
          }
        } catch (e) {
          
        }
      }

      return {
        'status': 0,
        'message': 'Failed to process payment. Please try again later.',
      };
    } catch (e) {
      
      return {'status': 0, 'message': 'Error processing payment: $e'};
    }
  }

  static void _logCurlRequest(
    Uri url,
    Map<String, String> headers,
    String body,
  ) {
    final sanitizedBody = body.replaceAll("'", "\\'");
    final buffer = StringBuffer();
    buffer.writeln('💳 cURL POST:');
    buffer.write('curl -X POST "${url.toString()}"');
    headers.forEach((key, value) {
      if (value.isEmpty) return;
      final sanitizedValue = value.replaceAll('"', '\\"');
      buffer.write(' \\\n  -H "$key: $sanitizedValue"');
    });
    buffer.write(' \\\n  -d \'$sanitizedBody\'');
    // 
  }

  /// Submit offline payment
  /// 
  /// API Endpoint: /api/Webservice/addofflinepayment
  /// Method: POST (multipart/form-data)
  /// 
  /// Field Mapping (as per cURL):
  /// - paymentMode → payment_type
  /// - paymentFrom → bank_account_transferred
  /// - Always includes student_transport_fee_id (can be empty string)
  /// 
  /// Always uses multipart/form-data (even without attachment) to match API expectations
  static Future<Map<String, dynamic>> submitOfflinePayment({
    required String studentFeesMasterId,
    required String feeGroupsFeetypeId,
    required String studentId,
    required String amount,
    required String paymentMode,
    required String paymentFrom,
    required String paymentDate,
    String? studentTransportFeeId,
    String? extraDiscount,
    List<String>? feeDiscountGroup,
    String? attachmentPath,
    String? requestId,
    bool removeAttachment = false,
    String? note,
    String? reference,
    String? studentSessionId,
  }) async {
    try {

      
      // Fallback for studentSessionId
      String finalSessionId = studentSessionId ?? '';
      if (finalSessionId.isEmpty || finalSessionId == 'null') {
        try {
          finalSessionId = await AuthService.getStudentSessionId();
        } catch (_) {}
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return {'status': 0, 'message': 'Base URL not configured'};

      // USER VERIFIED ENDPOINT
      final endpoint = '$baseUrl/api/Webservice/addofflinepayment';

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // DATA TRANSFORMATION: Match verified cURL perfectly + Essential Aliases
      // 1. Ensure amount doesn't have trailing .0 if not needed
      String cleanAmount = amount;
      if (cleanAmount.contains('.')) {
         final parts = cleanAmount.split('.');
         if (parts.length > 1 && (parts[1] == '0' || parts[1] == '00')) {
            cleanAmount = parts[0];
         }
      }


      final hasFile = attachmentPath != null && attachmentPath.trim().isNotEmpty;

      final isTransport = studentTransportFeeId != null && studentTransportFeeId.isNotEmpty;

      // DATA TRANSFORMATION: Match verified cURL perfectly + Essential Aliases
      final fields = {
        'payment_date': paymentDate,
        'student_session_id': finalSessionId,
        'amount': cleanAmount,
        'reference': reference ?? '',
        'payment_type': paymentMode.toLowerCase().trim(),
        'fee_groups_feetype_id': feeGroupsFeetypeId,
        'student_fees_master_id': studentFeesMasterId,
        'student_transport_fee_id': studentTransportFeeId ?? '',
        
        // Essential aliases for robustness (Smart School variants)
        'student_id': studentId,
        'student_fee_master_id': studentFeesMasterId, // Alias
        'fee_session_group_id': feeGroupsFeetypeId, // Alias
        'transport_fee_id': studentTransportFeeId ?? '', // Alias
        'bank_account_transferred': paymentFrom,
        'payment_from': paymentFrom,
        'payment_mode': paymentMode.toLowerCase().trim(),
        'pay_amount': cleanAmount,
        'fee_category': isTransport ? 'transport' : 'fees',
        'submit': '1',
      };



      if (note != null && note.isNotEmpty) {
        fields['note'] = note;
        fields['description'] = note;
      }
      
      if (requestId != null && requestId.isNotEmpty) {
        fields['request_id'] = requestId;
      }
      
      if (extraDiscount != null && extraDiscount.isNotEmpty) {
        fields['extra_discount'] = extraDiscount;
      }

      if (feeDiscountGroup != null && feeDiscountGroup.isNotEmpty) {
        fields['fee_discount_group'] = feeDiscountGroup.join(',');
        fields['applied_discount_id'] = feeDiscountGroup.join(',');
      }

      // ALWAYS use MultipartRequest for this endpoint to ensure multipart/form-data
      final multipartHeaders = Map<String, String>.from(headers)
        ..remove('Content-Type')
        ..remove('content-type');

      // CRITICAL: Normalize cookie to ci_session format for multipart uploads
      if (cookie != null && cookie.isNotEmpty) {
        String cookieValue = cookie.trim();
        if (!cookieValue.startsWith('ci_session=')) {
          final match = RegExp(r'ci_session=([^;]+)').firstMatch(cookieValue);
          if (match != null) {
            cookieValue = 'ci_session=${match.group(1)}';
          } else {
            cookieValue = 'ci_session=$cookieValue';
          }
        }
        multipartHeaders['Cookie'] = cookieValue;
      }

      final request = http.MultipartRequest('POST', Uri.parse(endpoint));
      request.headers.addAll(multipartHeaders);
      
      // Add all form fields
      fields.forEach((key, val) {
        request.fields[key] = val.toString();
      });

      // Add file attachment if present
      if (hasFile) {
        try {
          final file = File(attachmentPath!);
          if (await file.exists()) {
            final fileName = attachmentPath!.split('/').last;
            final extension = fileName.split('.').last.toLowerCase();
            
            // Determine content type
            String type = 'application';
            String subtype = 'octet-stream';
            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
              type = 'image';
              subtype = extension == 'jpg' ? 'jpeg' : extension;
            } else if (extension == 'pdf') {
              type = 'application';
              subtype = 'pdf';
            }

            // Field name 'attachment' as per user cURL
            // Field name 'file' as per other working modules in same app
            final mediaType = MediaType(type, subtype);
            
            request.files.add(
              await http.MultipartFile.fromPath(
                'attachment', 
                attachmentPath!,
                filename: fileName,
                contentType: mediaType,
              )
            );
            
            // Fallback field 'file' - used by most Smart School modules
            request.files.add(
              await http.MultipartFile.fromPath(
                'file', 
                attachmentPath!,
                filename: fileName,
                contentType: mediaType,
              )
            );

            
          } else {
            
          }
        } catch (e) {
          
        }
      }

      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      
      

      if (response.statusCode == 200) {
        if (ResponseValidator.isHtmlResponse(response.body)) {
          return {'status': 0, 'message': 'Endpoint returned web page instead of JSON'};
        }
        
        final json = jsonDecode(response.body);
        
        // CRITICAL: Log attachment-related response data
        
        if (json.containsKey('attachment')) {
          
        }
        if (json.containsKey('file')) {
          
        }
        if (json.containsKey('document')) {
          
        }
        
        final isOk = json['status']?.toString() == '1' || 
                    (json['message']?.toString().toLowerCase().contains('success') ?? false);
        
        if (isOk) {
          
          if (json.containsKey('attachment') || json.containsKey('file')) {
            
          } else {
            
          }
          return {'status': 1, 'message': json['message'] ?? 'Submitted successfully', 'raw': json};
        } else {
          // Flatten error map from PHP validation
          String error = json['message']?.toString() ?? 'Validation failed';
          if (json['error'] is Map) {
            final eMap = json['error'] as Map;
            final detail = eMap.values.where((v) => v.toString().isNotEmpty).join(' ');
            if (detail.isNotEmpty) error = detail;
          }
          return {'status': 0, 'message': error};
        }
      } else {
        return {'status': 0, 'message': 'Server Error: ${response.statusCode}'};
      }
    } catch (e) {
      
      return {'status': 0, 'message': 'System error: $e'};
    }
  }

  // Get fees discount
  // API: /api/webservice/getFeesDiscount
  // Body: {"student_session_id": "...", "student_fees_master_id": "...", "fee_groups_feetype_id": "...", "fee_category": "..."}
  // Headers: Authorization, Auth-Key, Client-Service, Content-Type, User-ID, Cookie (all dynamic)
  // Response: {"discount_fee": [...], "discount_not_applied": [...]}
  static Future<Map<String, dynamic>> getFeesDiscount({
    required String studentSessionId,
    required String studentFeesMasterId,
    required String feeGroupsFeetypeId,
    required String feeCategory,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured', 'discounts': []};
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'application/json';

      // Add session cookie
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'student_session_id': studentSessionId.toString(),
        'student_fees_master_id': studentFeesMasterId.toString(),
        'fee_groups_feetype_id': feeGroupsFeetypeId.toString(),
        'fee_category': feeCategory.toString(),
      });

      // Endpoint: Try multiple possible endpoints as per common API structures
      final endpoints = [
        '$baseUrl/fees/getFeesDiscount',
        '$baseUrl/api/webservice/getFeesDiscount',
        '$baseUrl/api/fees/getFeesDiscount',
      ];

      http.Response? response;
      String? usedUrl;

      for (final endpoint in endpoints) {
        final url = Uri.parse(endpoint);
        
        try {
          final res = await http.post(
            url,
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 15));
          
          if (res.statusCode == 200 && !ResponseValidator.isHtmlResponse(res.body)) {
            response = res;
            usedUrl = endpoint;
            break;
          }
        } catch (_) {}
      }

      if (response == null) {
        return {
          'status': 0,
          'message': 'Unable to load discounts',
          'discounts': [],
          'discount_fee': [],
          'discount_not_applied': [],
        };
      }

      if (response.statusCode == 200) {
        // CRITICAL: Check for empty response body BEFORE parsing
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          
          return {
            'status': 0,
            'message': 'Unable to load discounts. Please try again later.',
            'discount_fee': [],
            'discount_not_applied': [],
          };
        }
        
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData is Map) {
            // Extract discounts from API response
            // Response has: discount_fee (already applied) and discount_not_applied (available to apply)
            List<dynamic> discountFee = jsonData['discount_fee'] ?? [];
            List<dynamic> discountNotApplied = jsonData['discount_not_applied'] ?? [];
            
            // Combine both lists - mark which ones are already applied
            List<Map<String, dynamic>> allDiscounts = [];
            
            // Add already applied discounts
            for (var discount in discountFee) {
              allDiscounts.add({
                ...Map<String, dynamic>.from(discount),
                'is_applied': true,
              });
            }
            
            // Add available discounts (not yet applied)
            for (var discount in discountNotApplied) {
              allDiscounts.add({
                ...Map<String, dynamic>.from(discount),
                'is_applied': false,
              });
            }

            return {
              'status': 1,
              'message': 'Success',
              'discounts': allDiscounts,
              'discount_fee': discountFee,
              'discount_not_applied': discountNotApplied,
            };
          }
        } catch (e) {
          
          
          // CRITICAL: Handle FormatException for empty input
          if (e is FormatException && e.message.contains('Unexpected end of input')) {
            
            return {
              'status': 0,
              'message': 'Unable to load discounts. Please try again later.',
              'discounts': [],
              'discount_fee': [],
              'discount_not_applied': [],
            };
          }
        }
      }

      return {
        'status': 0,
        'message': 'Failed to load discounts',
        'discounts': [],
        'discount_fee': [],
        'discount_not_applied': [],
      };
    } catch (e, stackTrace) {
      
      
      
      // CRITICAL: Handle FormatException for empty input
      if (e is FormatException && e.message.contains('Unexpected end of input')) {
        
        return {
          'status': 0,
          'message': 'Unable to load discounts. Please try again later.',
          'discounts': [],
          'discount_fee': [],
          'discount_not_applied': [],
        };
      }
      return {'status': 0, 'message': 'Error loading discounts: $e', 'discounts': []};
    }
  }

  // Get session cookie from SharedPreferences
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
  // Pay multiple fees
  // API for zero-amount payments (100% discount)
  // Uses deposit endpoints instead of payment gateway endpoints
  static Future<Map<String, dynamic>> saveZeroAmountPayment({
    required List<Map<String, dynamic>> payments,
    List<dynamic>? feeDiscountGroup,
    String? note,
    String? date,
    String? currency,
  }) async {
    try {

      if (payments.isEmpty) {
        return {'status': 0, 'message': 'No fees selected for payment'};
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }
      
      // Get complete headers including auth tokens
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // For zero payments, use deposit endpoints instead of payment gateway
      final Map<String, dynamic> bodyMap = {
        'payments': payments,
        if (feeDiscountGroup != null) 'fee_discount_group': feeDiscountGroup,
        'payment_mode': 'offline', // Zero payments are treated as offline/deposit
        'payment_type': 'offline',
        'amount': '0.00', // Explicitly set zero amount
        if (note != null) 'note': note,
        if (date != null) 'date': date,
        'is_discount_payment': '1', // Flag to indicate this is a discount payment
      };

      // CRITICAL: Fetch user details for root mapping
      final profile = await AuthService.getUserProfile();
      final studentName = [
        profile['firstname'],
        profile['lastname']
      ].where((n) => n != null && n.toString().isNotEmpty).join(' ');
      
      // Add user details to body for deposit endpoints
      bodyMap['student_id'] = payments.first['student_id'] ?? '';
      bodyMap['student_name'] = studentName.isNotEmpty ? studentName : 'Student';
      bodyMap['email'] = profile['email'] ?? profile['guardian_email'] ?? '';
      bodyMap['phone'] = profile['phone'] ?? profile['guardian_phone'] ?? '';

      final body = jsonEncode(bodyMap);

      // Try deposit-specific endpoints first for zero payments
      final endpoints = [
        '$baseUrl/api/webservice/addFeesDeposite',
        '$baseUrl/api/webservice/add_fees_deposite',
        '$baseUrl/api/webservice/feedeposit',
        '$baseUrl/api/payment/add_fees_deposit',
        '$baseUrl/api/payment/addFeesDeposit',
      ];

      http.Response? response;
      String? usedUrl;

      for (final endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);
          final res = await http.post(
            url,
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 30));

          if (res.statusCode == 200 && !ResponseValidator.isHtmlResponse(res.body)) {
            response = res;
            usedUrl = endpoint;
            break;
          }
        } catch (_) {}
      }

      if (response == null) {
        return {
          'status': 0,
          'message': 'No response from zero-payment server. Please try again.',
        };
      }

      if (response.statusCode == 200) {
        try {
           final body = response.body;
           final Map<String, dynamic> jsonData = jsonDecode(body);
           
           // Ensure the response has the expected success structure
           if (jsonData['status'] == null) {
             jsonData['status'] = 1; // Assume success if we got 200
           }
           
           return jsonData;
        } catch (e) {
          // Return a basic success response if parsing fails but we got 200
          return {
            'status': 1,
            'message': 'Payment processed successfully',
            'raw_response': response.body,
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Zero-payment processing failed with status: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      
      return {'status': 0, 'message': 'Request timed out. Please try again.'};
    } catch (e) {
      
      return {'status': 0, 'message': 'Connection error: $e'};
    }
  }

  // API: /api/payment/fees_pay
  // Method: POST
  // Body: { "payments": [ { "student_fees_master_id": "...", "fee_groups_feetype_id": "...", "amount": 100, "student_id": "...", "fee_type": "...", "fee_group": "...", "discounts": [] } ] }
  static Future<Map<String, dynamic>> payMultipleFees({
    required List<Map<String, dynamic>> payments,
    List<dynamic>? feeDiscountGroup,
    String? paymentMode,
    String? note,
    String? date,
    String? processingChargeType,
    String? gatewayProcessingCharge,
    String? currency, // NEW: Currency code (e.g., EUR)
    double? totalFineAmount, // NEW: Total fine amount to prevent duplication
  }) async {
    try {

      if (payments.isEmpty) {
        return {'status': 0, 'message': 'No fees selected for payment'};
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'No base URL configured'};
      }
      
      // Get complete headers including auth tokens
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // CRITICAL: User provided cURL shows a nested 'payments' array structure
      // Endpoint: /api/payment/fees_pay
      // Structure: { "payments": [ ... ] }

      final Map<String, dynamic> bodyMap = {
        'payments': payments, // Send the payments array directly
        'payment_mode': paymentMode ?? 'online',
        'payment_type': (paymentMode ?? 'online').toLowerCase(),
        if (note != null) 'note': note,
        if (date != null) 'date': date,
      };

      // Add student info (some backends might need it at root)
      if (payments.isNotEmpty) {
        bodyMap['student_id'] = payments[0]['student_id'];
        
        // CRITICAL: Only add student_fees_master_id if it exists (Transport fees have null)
        if (payments[0]['student_fees_master_id'] != null && 
            payments[0]['student_fees_master_id'].toString().isNotEmpty && 
            payments[0]['student_fees_master_id'].toString() != 'null') {
          bodyMap['student_fees_master_id'] = payments[0]['student_fees_master_id'];
        }
        
        // CRITICAL: Send fine amount at root if totalFineAmount provided (backend specific?)
        if (totalFineAmount != null && totalFineAmount > 0) {
            bodyMap['fine_amount'] = totalFineAmount.toStringAsFixed(2);
            bodyMap['fine_amount_balance'] = totalFineAmount.toStringAsFixed(2);
        }

        // CRITICAL: Add transport fee ID to root if available
        if (payments[0]['student_transport_fee_id'] != null && 
            payments[0]['student_transport_fee_id'].toString().isNotEmpty && 
            payments[0]['student_transport_fee_id'].toString() != 'null') {
           bodyMap['student_transport_fee_id'] = payments[0]['student_transport_fee_id'];
        }
      }

      // CRITICAL: Send fee discount group if provided
      if (feeDiscountGroup != null && feeDiscountGroup.isNotEmpty) {
          bodyMap['fee_discount_group'] = feeDiscountGroup;
      }

      final profile = await AuthService.getUserProfile();
      final email = (profile['email'] ?? profile['guardian_email'] ?? '').toString().trim();
      final phone = (profile['phone'] ?? profile['guardian_phone'] ?? profile['contact_no'] ?? '').toString().trim();
      
      bodyMap['email'] = email.isNotEmpty ? email : 'student@school.com';
      if (phone.isNotEmpty) bodyMap['phone'] = phone;
      bodyMap['guardian_phone'] = profile['guardian_phone'] ?? phone;
      
      // Calculate totals for tracking (optional, but good for debugging)
      double totalAmount = 0;
      for (var p in payments) {
        totalAmount += _parseDouble(p['amount'] ?? 0);
      }
      bodyMap['amount'] = totalAmount.toStringAsFixed(2);
      bodyMap['total'] = totalAmount.toStringAsFixed(2);
      
      // Add return_url
      bodyMap['return_url'] = 'smartschool://payment/success';
      
      // CRITICAL: Allow overriding processing charges (e.g., forcing 0 for zero-payments)
      if (processingChargeType != null) bodyMap['processing_charge_type'] = processingChargeType;
      if (gatewayProcessingCharge != null) bodyMap['gateway_processing_charge'] = gatewayProcessingCharge;

      final body = jsonEncode(bodyMap);

      // Use the User-Verified Endpoint
      final endpoints = [
        '$baseUrl/api/payment/fees_pay', // User verified endpoint
        '$baseUrl/fees/fees_pay',
      ];

      http.Response? response;
      String? usedUrl;

      for (final endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);
          final res = await http.post(
            url,
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 30));

          if (res.statusCode == 200 && !ResponseValidator.isHtmlResponse(res.body)) {
              response = res;
              usedUrl = endpoint;
              break;
          }
        } catch (_) {}
      }

      if (response == null) {
        return {
          'status': 0,
          'message': 'No response from payment server. Please check your internet connection or try a different payment method.',
        };
      }

      if (response.statusCode == 200) {
        // Try standard parsing first
        try {
           final body = response.body;
           final Map<String, dynamic> jsonData = jsonDecode(body);
           
            // CRITICAL: Trust the redirect_url as provided by the server
            if (jsonData['data'] is Map && jsonData['data']['redirect_url'] != null) {
              // Priority 2
            }
           
            return _validatePaymentResponse(jsonData);
        } catch (_) {
           // Fallback: Fuzzy parsing for mixed content (PHP errors + JSON)
           
           try {
             final body = response.body;
             final startIndex = body.indexOf('{');
             final endIndex = body.lastIndexOf('}');
             
             if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
               final potentialJson = body.substring(startIndex, endIndex + 1);
               final jsonData = jsonDecode(potentialJson);
               
               return _validatePaymentResponse(jsonData);
             } else {
               throw const FormatException('No JSON object found in response');
             }
           } catch (e) {
             
             return {
               'status': 0, 
               'message': 'Server Error: The server returned invalid data.\n\nRaw response:\n${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}'
             };
           }
        }
      } else {
         
        return {
          'status': 0,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      
      return {'status': 0, 'message': 'Request timed out. Please try again.'};
    } catch (e) {
      
      return {'status': 0, 'message': 'Connection error: $e'};
    }
  }


  static Future<Map<String, dynamic>> payMultipleFeesV2(List<Map<String, dynamic>> payments) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return {'status': 0, 'message': 'Base URL not set'};

      final url = Uri.parse('$baseUrl/api/payment/fees_pay');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'payments': payments,
      });


      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        try {
           final jsonData = jsonDecode(response.body);
           return _validatePaymentResponse(jsonData);
        } catch (e) {
           
           return {'status': 0, 'message': 'Invalid server response'};
        }
      } else {
        return {'status': 0, 'message': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      
      return {'status': 0, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getFees(String studentId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();

      if (baseUrl.isEmpty) {
        
        return {'status': 0, 'message': 'Base URL not set', 'fees': <Fee>[]};
      }

      // Support both getFees and fees endpoints
      final endpoints = [
        await AppConfig.getApiEndpoint('getFees'),
        await AppConfig.getApiEndpoint('fees'),
      ];

      http.Response? response;
      String? lastError;

      // Try all endpoints in parallel for faster loading
      final List<Future<http.Response?>> trials = [];
      for (final endpoint in endpoints) {
        trials.add(() async {
          try {
            final url = Uri.parse(endpoint);
            
            final headers = await DynamicApiHeaders.getCompleteHeaders();
            final cookie = await _getSessionCookie();
            if (cookie != null && cookie.isNotEmpty) {
              headers['Cookie'] = cookie;
            }
            final body = jsonEncode({'student_id': studentId});
            final res = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 && !ResponseValidator.isHtmlResponse(res.body)) {
              return res;
            }
          } catch (_) {}
          return null;
        }());
      }

      final results = await Future.wait(trials);
      for (final res in results) {
        if (res != null) {
          response = res;
          break;
        }
      }

      if (response != null) {
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('transport_fees')) {
           // Type check preserved
        }
        
        // Use our standard extractor to get flat list
        final List<Map<String, dynamic>> rawFees = _extractFeesList(jsonData);
        
        // Convert to Fee models
        final List<Fee> fees = rawFees.map((f) => Fee.fromJson(f)).toList();
        
        
        

        return {
          ...jsonData,
          'status': 1,
          'message': 'Success',
          'fees': fees,
          'grand_fee': jsonData['grand_fee'],
          'student_session_id': jsonData['student_session_id'],
          'raw_response': jsonData,
        };
      } else {
        
        return {'status': 0, 'message': 'Failed to load fees: ${lastError ?? "Unknown error"}', 'fees': <Fee>[]};
      }
    } catch (e) {
      
      return {'status': 0, 'message': 'Error loading fees: $e', 'fees': <Fee>[]};
    }
  }

  static double _parseDouble(dynamic value) {
    return FeeCalculator.parseAmount(value);
  }

  static Map<String, dynamic> _validatePaymentResponse(dynamic jsonData) {
    if (jsonData is Map<String, dynamic>) {
       return jsonData;
    }
    return {'status': 0, 'message': 'Invalid response format'};
  }
}

List<Map<String, dynamic>> _extractFeesList(Map<String, dynamic> jsonData) {
  final List<Map<String, dynamic>> allFees = [];

  // 1. student_due_fee is a list of groups, e.g. [{ "name": "Class 1", "fees": [...] }, ...]
  final dueFees = jsonData['student_due_fee'];
  if (dueFees is List) {
    for (var group in dueFees) {
      if (group is Map) {
         final nestedFees = group['fees'];
         if (nestedFees is List) {
           for (var fee in nestedFees) {
             if (fee is Map) {
               final enriched = Map<String, dynamic>.from(group);
               enriched.addAll(Map<String, dynamic>.from(fee));
               // group['name'] is usually the category name like "Class 1 General"
               if (group['name'] != null && enriched['fee_group_name'] == null) {
                 enriched['fee_group_name'] = group['name'];
               }
               allFees.add(enriched);
             }
           }
         }
      }
    }
  }

  // 2. Handle flat 'fees' list if 'student_due_fee' was not found or was secondary
  if (allFees.isEmpty) {
    final candidateKeys = ['student_fee', 'fees', 'processing_fees', 'student_fees', 'fee_list', 'data', 'result'];
    for (final key in candidateKeys) {
      final value = jsonData[key];
      if (value is List && value.isNotEmpty) {
        allFees.addAll(value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        break;
      }
    }
  }
  
  // 3. Extract and tag transport fees
  // Check for various transport keys
  final transportKeys = ['transport_fees', 'student_transport_fee', 'transport_fee'];
  for (final key in transportKeys) {
    final transportValue = jsonData[key];
    if (transportValue is List && transportValue.isNotEmpty) {
      allFees.addAll(transportValue
          .whereType<Map>()
          .map((e) {
              final f = Map<String, dynamic>.from(e);
              f['fee_category'] = 'transport';
              
              // CRITICAL: Map ID correctly for payment
              f['student_transport_fee_id'] = f['id']; 
              // Clear other IDs to avoid confusion with regular fees
              f['student_fees_master_id'] = '';
              f['fee_groups_feetype_id'] = '';

              // CRITICAL: Set a clear Display Name
              final month = f['month'] ?? '';
              f['fee_group_name'] = 'Transport Fees ($month)';
              f['fee_type'] = 'transport';
              
              // Map code correctly if it's under a different key in transport records
              // If not found, use "TRANSPORT" as the default code
              final rawCode = ([f['code'], f['fee_code'], f['feemaster_code']]
                  .firstWhere((e) => e != null && e.toString().trim().isNotEmpty, orElse: () => 'TRANSPORT'))
                  .toString();
              f['code'] = rawCode;
              f['fee_code'] = rawCode;
              
              // Ensure amount fields are strings to prevent parsing errors
              f['amount'] = f['fees']?.toString() ?? f['amount']?.toString();
              
              return f;
          })
          .toList());
      // Found the transport fees, no need to check other keys
      break; 
    }
  }

  return allFees;
}

