import 'package:flutter_riverpod/flutter_riverpod.dart'; import '../../../../services/api_service.dart';
final statsProvider = FutureProvider((ref) async => await ref.read(apiServiceProvider).getDashboardStats());
