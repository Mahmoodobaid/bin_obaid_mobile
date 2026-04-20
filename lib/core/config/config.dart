class AppConfig {
  static const String supabaseUrl = 'https://ackxfnznrjufhppaznjd.supabase.co';
  
  // تم التعديل إلى مفتاح Service Role لضمان الصلاحيات الكاملة (Admin Access)
  static const String supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY';

  // ملاحظة: تأكد من استخدام supabaseServiceKey عند عمل Initialize لـ Supabase
}
