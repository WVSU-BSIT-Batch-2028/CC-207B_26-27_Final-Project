import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static Future<bool> testConnection() async {
    final result = await client.rpc('foodwise_health_check');

    return result['status'] == 'ok';
  }
}
