import requests

PROJECT_URL = "https://ackxfnznrjufhppaznjd.supabase.co"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY"

headers = {
    "apikey": API_KEY,
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

print("⏳ جاري استخراج قائمة الجداول الفعلية...")

# محاولة جلب تعريفات الجداول عبر الـ OpenAPI (Swagger)
try:
    spec_url = f"{PROJECT_URL}/rest/v1/"
    response = requests.get(spec_url, headers=headers)
    if response.status_code == 200:
        definitions = response.json().get('definitions', {})
        tables = list(definitions.keys())
        
        print("\n" + "="*50)
        print("🏠 الجداول المكتشفة في مؤسسة بن عبيد")
        print("="*50)
        
        for table in tables:
            print(f"\n📊 الجدول: {table.upper()}")
            # جلب عينة بيانات لكل جدول مكتشف
            data_url = f"{PROJECT_URL}/rest/v1/{table}?select=*&limit=1"
            data_res = requests.get(data_url, headers=headers)
            if data_res.status_code == 200 and data_res.json():
                sample = data_res.json()[0]
                print(f"📌 الأعمدة: {list(sample.keys())}")
                print(f"📝 عينة: {sample}")
            else:
                print("📝 (جدول فارغ أو محمي)")
            print("-" * 30)
    else:
        print(f"❌ فشل جلب القائمة. كود الخطأ: {response.status_code}")
except Exception as e:
    print(f"❌ حدث خطأ: {e}")

print("\n✅ تم الفحص.")
