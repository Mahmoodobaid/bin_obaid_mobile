import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_base.dart';
import 'api_extensions.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService extends ApiBase {
  // يمكنك إضافة أي دوال خاصة هنا إذا لزم الأمر
  // لكن معظم الدوال موجودة في ApiBase و ApiExtensions
}
