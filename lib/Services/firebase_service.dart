import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isOffline = false;

  FirebaseService() {
    _checkConnectivity();
  }

  // Check network connectivity
  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _isOffline = connectivityResult.contains(ConnectivityResult.none);

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _isOffline = results.contains(ConnectivityResult.none);
      if (kDebugMode) {
        debugPrint('Network status changed: isOffline=$_isOffline');
      }
    });
  }

  // Cache data to SharedPreferences
  Future<void> _cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      if (kDebugMode) {
        debugPrint('Cached data for key: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error caching data for key $key: $e');
      }
    }
  }

  // Load cached data from SharedPreferences, with fallback to old key format
  Future<dynamic> _loadCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(key);
      if (cachedData != null) {
        if (kDebugMode) {
          debugPrint('Loaded cached data for key: $key');
        }
        return jsonDecode(cachedData);
      }

      // Try old underscore-delimited key format
      final oldKey = key.replaceAll('-', '_');
      if (oldKey != key) {
        cachedData = prefs.getString(oldKey);
        if (cachedData != null) {
          if (kDebugMode) {
            debugPrint('Loaded cached data from old key: $oldKey');
          }
          // Migrate to new key
          await prefs.setString(key, cachedData);
          await prefs.remove(oldKey);
          return jsonDecode(cachedData);
        }
      }

      if (kDebugMode) {
        debugPrint('No cached data for key: $key or old key: $oldKey');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading cached data for key $key: $e');
      }
      return null;
    }
  }

  // Fetch hospital details (name and logo) for a specific hospital
  Future<Map<String, String>> getHospitalDetails(String hospitalId) async {
    final cacheKey = 'Chamber-details-$hospitalId';

    if (_isOffline) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return Map<String, String>.from(cachedData);
      }
    }

    try {
      DocumentSnapshot hospitalDoc = await _db.collection('Chamber').doc(hospitalId).get();
      if (!hospitalDoc.exists) {
        throw Exception('Chamber not found');
      }
      var name = hospitalDoc.get('Chamber Name');
      var logo = hospitalDoc.get('Logo');
      final result = {
        'hospitalName': name is String ? name : 'Unknown Chamber',
        'logo': logo is String ? logo : ''
      };

      // Cache the result
      await _cacheData(cacheKey, result);
      return result;
    } catch (e) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return Map<String, String>.from(cachedData);
      }
      rethrow;
    }
  }

  // Fetch department names based on Hospital's Department IDs
  Future<List<Map<String, dynamic>>> getDepartmentsForHospital(String hospitalId) async {
    final cacheKey = 'Practices-$hospitalId';

    if (_isOffline) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
    }

    try {
      DocumentSnapshot hospitalDoc = await _db.collection('Chamber').doc(hospitalId).get();
      if (!hospitalDoc.exists) {
        throw Exception('Chamber not found');
      }
      List<dynamic> departmentIds = hospitalDoc.get('Chamber Practice') as List<dynamic>;

      List<Map<String, dynamic>> departments = [];
      for (String departmentId in departmentIds) {
        DocumentSnapshot departmentDoc = await _db.collection('Practice').doc(departmentId).get();
        if (!departmentDoc.exists) {
          continue;
        }
        var departmentName = departmentDoc.get('Practice Name');
        departments.add({
          'Practice ID': departmentId,
          'Practice Name': departmentName is String ? departmentName : 'Unknown Practice',
        });
      }

      // Cache the result
      await _cacheData(cacheKey, departments);
      return departments;
    } catch (e) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      rethrow;
    }
  }

  // Fetch doctors based on hospital and department, including userId for doctor identification
  Future<List<Map<String, dynamic>>> getDoctorsForDepartment(String hospitalId, String departmentId) async {
    final cacheKey = 'Lawyers-$hospitalId-$departmentId';

    if (_isOffline) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
    }

    try {
      final querySnapshot = await _db
          .collection('Users')
          .where('Chamber ID', isEqualTo: hospitalId)
          .where('Practice ID', isEqualTo: departmentId)
          .where('Role', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> doctors = [];
      for (var doc in querySnapshot.docs) {
        String userId = doc.id;
        var lname = doc.get('Lname');
        var experience = doc.get('Experience');
        var userPic = doc.get('User Pic');
        doctors.add({
          'userId': userId,
          'name': lname is String ? 'Esq. $lname ' : 'Unknown Esq.',
          'experience': experience != null ? '$experience Yrs' : '0 Yrs',
          'userPic': userPic is String ? userPic : '',
        });
      }

      // Cache the result
      await _cacheData(cacheKey, doctors);
      return doctors;
    } catch (e) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      rethrow;
    }
  }

  // Fetch details of a specific doctor based on userId
  Future<Map<String, dynamic>> getDoctorDetails(String userId) async {
    final cacheKey = 'doctor-details-$userId';

    if (_isOffline) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }

    try {
      DocumentSnapshot userDoc = await _db.collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('Doctor not found');
      }

      if (userDoc.get('Role') == true) {
        // Debug data
        final data = userDoc.data() as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('UserDoc Data for $userId: $data');
        }

        final result = {
          'Fname': _safeString(data['Fname'], 'Unknown'),
          'Lname': _safeString(data['Lname'], 'Unknown'),
          'Region': _safeString(data['Region'], 'Unknown'),
          'Title': _safeString(data['Title'], 'Dr.'),
          'Email': _safeString(data['Email'], 'N/A'),
          'Mobile Number': _safeString(data['Mobile Number'], 'N/A'),
          'Experience': data['Experience']?.toString() ?? '0',
          'userPic': _safeString(data['User Pic'], ''),
          'departmentId': _safeString(data['Practice ID'], ''),
          'hospitalId': _safeString(data['Chamber ID'], ''),
          'Status': _safeString(data['Status'], 'false'),
        };

        // Cache the result
        await _cacheData(cacheKey, result);
        return result;
      } else {
        throw Exception('User role is not set to true');
      }
    } catch (e) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
      rethrow;
    }
  }

  // Helper to safely cast to string
  String _safeString(dynamic value, String defaultValue) {
    if (value is String) {
      return value;
    }
    if (kDebugMode) {
      debugPrint('Invalid type for field: $value (expected String, got ${value.runtimeType})');
    }
    return defaultValue;
  }

  // Fetch department name based on department ID
  Future<String> getDepartmentName(String departmentId) async {
    final cacheKey = 'department-name-$departmentId';

    if (_isOffline) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return cachedData as String;
      }
    }

    try {
      DocumentSnapshot departmentDoc = await _db.collection('Practice').doc(departmentId).get();
      if (!departmentDoc.exists) {
        throw Exception('Practice not found');
      }
      var name = departmentDoc.get('Practice Name');
      String departmentName = name is String ? name : 'Unknown Practice';

      // Cache the result
      await _cacheData(cacheKey, departmentName);
      return departmentName;
    } catch (e) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return cachedData as String;
      }
      rethrow;
    }
  }

  // Fetch hospital name based on hospital ID
  Future<String> getHospitalName(String hospitalId) async {
    final cacheKey = 'hospital-name-$hospitalId';

    if (_isOffline) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return cachedData as String;
      }
    }

    try {
      DocumentSnapshot hospitalDoc = await _db.collection('Chamber').doc(hospitalId).get();
      if (!hospitalDoc.exists) {
        throw Exception('Chamber not found');
      }
      var name = hospitalDoc.get('Chamber Name');
      String hospitalName = name is String ? name : 'Unknown Chamber';

      // Cache the result
      await _cacheData(cacheKey, hospitalName);
      return hospitalName;
    } catch (e) {
      final cachedData = await _loadCachedData(cacheKey);
      if (cachedData != null) {
        return cachedData as String;
      }
      rethrow;
    }
  }
}