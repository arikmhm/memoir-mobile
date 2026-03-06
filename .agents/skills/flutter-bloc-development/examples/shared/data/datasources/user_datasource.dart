// Example: Shared User Datasource
// Path: lib/shared/data/datasources/user_datasource.dart
//
// This is a SHARED datasource because user data is needed by:
// - Auth feature (login, logout)
// - Profile feature (view/edit profile)
// - Settings feature (preferences)
// - Any feature showing user info

import 'api_client.dart';

/// Shared datasource for user-related API calls
/// 
/// WHY SHARED: Multiple features need user data:
/// - Auth: login, register, logout
/// - Profile: view/update profile
/// - Settings: user preferences
/// - Dashboard: user info display
class UserDataSource {
  final ApiClient _api;

  UserDataSource(this._api);

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _api.get('/users/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUser(Map<String, dynamic> data) async {
    final response = await _api.put('/users/me', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await _api.delete('/users/me');
  }
}
