import requests
import json

PROJECT_URL = "https://ackxfnznrjufhppaznjd.supabase.co"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY"

headers = {"apikey": API_KEY, "Authorization": f"Bearer {API_KEY}"}

def get_tables():
    res = requests.get(f"{PROJECT_URL}/rest/v1/", headers=headers)
    return list(res.json().get('definitions', {}).keys()) if res.status_code == 200 else []

print("\n🔍 جاري جلب عينة بيانات من أول صف لكل جدول...\n")

tables = get_tables()

for table in tables:
    # جلب أول صف فقط من كل جدول
    url = f"{PROJECT_URL}/rest/v1/{table}?select=*&limit=1"
    response = requests.get(url, headers=headers)
    
    print(f"📊 الجدول: {table.upper()}")
    print("═" * 30)
    
    if response.status_code == 200:
        data = response.json()
        if data:
            row = data[0]
            for col, val in row.items():
                # تجميل عرض البيانات الطويلة أو الـ JSON
                display_val = val
                if isinstance(val, (dict, list)):
                    display_val = json.dumps(val, ensure_ascii=False)[:50] + "..."
                
                print(f"🔹 {col.ljust(18)} : {display_val}")
        else:
            print("⚪ (الجدول فارغ حالياً)")
    else:
        print(f"❌ تعذر الوصول للبيانات (خطأ {response.status_code})")
    
    print("-" * 40 + "\n")

