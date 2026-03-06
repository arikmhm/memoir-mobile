// Example: Earnings Feature - Datasource (Supabase)
// Path: lib/earnings/data/datasources/earnings_datasource.dart

import 'package:supabase_flutter/supabase_flutter.dart';

/// Datasource handles all Supabase SDK interactions for earnings
/// 
/// IMPORTANT: Only datasources should import Supabase directly.
/// Repositories call datasources, never Supabase.
class EarningsDataSource {
  final SupabaseClient _supabase;

  EarningsDataSource(this._supabase);

  /// Fetch earnings summary from Supabase
  Future<Map<String, dynamic>> fetchEarningsSummary({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Call Supabase RPC function for aggregated data
    final response = await _supabase.rpc(
      'get_driver_earnings_summary',
      params: {
        'p_driver_id': driverId,
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
      },
    );

    return response as Map<String, dynamic>;
  }

  /// Fetch daily breakdown of earnings
  Future<List<Map<String, dynamic>>> fetchDailyEarnings({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase
        .from('earnings')
        .select('date, amount, trip_count')
        .eq('driver_id', driverId)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String())
        .order('date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
