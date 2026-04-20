// -------------------------------------------------------------------------
// ملف الإعدادات المركزية - مؤسسة بن عبيد التجارية
// الإصدار: 2.2.0 (Ultra Admin Access)
// -------------------------------------------------------------------------

class AppConfig {
  // 1. رابط الخادم السحابي (Supabase)
  static const String supabaseUrl = 'https://ackxfnznrjufhppaznjd.supabase.co';
  
  // 2. مفتاح الصلاحيات المطلقة (Service Role)
  // يستخدم لتجاوز قيود الـ RLS وحل مشكلة الجداول الفارغة
  static const String supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY';

  // 3. مفتاح التوافقية (Compatibility Key)
  // هام جداً: هذا السطر يحل أخطاء ملفات (api_service.dart) و (connection_settings_screen.dart) 
  // التي تسببت في فشل الـ Build لأنها لا تزال تبحث عن مسمى 'supabaseAnonKey'
  static const String supabaseAnonKey = supabaseServiceKey;

  // 4. إعدادات النظام الإضافية
  static const String appName = 'Bin Obaid Trading';
  static const String appVersion = '2.2.0';
  static const int connectionTimeout = 15; // ثانية لتجاوز مشاكل الـ DNS في اليمن
}
