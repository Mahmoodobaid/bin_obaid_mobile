import requests

PROJECT_URL = "https://ackxfnznrjufhppaznjd.supabase.co"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY"

headers = {"apikey": API_KEY, "Authorization": f"Bearer {API_KEY}"}

def clean_val(val):
    if isinstance(val, str) and len(val) > 50:
        return "[بيانات طويلة جداً - تم إخفاؤها للوضوح]"
    return val

try:
    # جلب قائمة الجداول
    spec = requests.get(f"{PROJECT_URL}/rest/v1/", headers=headers).json()
    tables = list(spec.get('definitions', {}).keys())

    print("\n" + "★"*50)
    print("📋 عينة بيانات نظيفة من جداول مؤسسة بن عبيد")
    print("★"*50 + "\n")

    for table in tables:
        url = f"{PROJECT_URL}/rest/v1/{table}?select=*&limit=1"
        res = requests.get(url, headers=headers)
        
        if res.status_code == 200 and res.json():
            print(f"📍 الجدول: {table.upper()}")
            print("─" * 30)
            row = res.json()[0]
            for col, val in row.items():
                print(f"  ● {col.ljust(18)} : {clean_val(val)}")
            print("\n")
        elif res.status_code == 200:
            print(f"📍 الجدول: {table.upper()} (جدول فارغ لا يحتوي بيانات حالياً)\n")

except Exception as e:
    print(f"❌ حدث خطأ: {e}")
