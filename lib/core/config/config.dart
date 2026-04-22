// -----------------------------------------------------------------------------
// ملف الإعدادات المركزية - مؤسسة بن عبيد التجارية
// الإصدار: 2.2.0
// تحذير: لا ترفع هذا الملف إلى GitHub إذا كان يحتوي على مفتاح الخدمة.
// -----------------------------------------------------------------------------

class AppConfig {
  // رابط مشروع Supabase
  static const String supabaseUrl = 'https://bin-obaid-api.onrender.com';
  
  // ============================================================
  // مفتاح العميل العام (anon public) - آمن للاستخدام في التطبيق
  // ============================================================
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyMjEyMzgsImV4cCI6MjA5MDc5NzIzOH0.Yzs_X6EI13jLeaDIkXwL6L-7pm-Zl3YXM4aB9Fwves8';

  // ============================================================
  // ⚠️ مفتاح الخدمة (service_role) - للتشخيص فقط ⚠️
  // هذا المفتاح يتجاوز جميع قيود الأمان (RLS).
  // يجب إزالته نهائياً بعد التأكد من عمل التطبيق.
  // ============================================================
  static const String supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY';

  // إعدادات النظام
  static const String appName = 'بن عبيد التجارية';
  static const String appVersion = '2.2.0';
  static const int connectionTimeout = 15; // ثانية
}