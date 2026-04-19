import requests

PROJECT_URL = "https://ackxfnznrjufhppaznjd.supabase.co"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY"

headers = {"apikey": API_KEY, "Authorization": f"Bearer {API_KEY}"}

try:
    # جلب مخطط قاعدة البيانات (OpenAPI spec)
    response = requests.get(f"{PROJECT_URL}/rest/v1/", headers=headers)
    if response.status_code == 200:
        definitions = response.json().get('definitions', {})
        
        print("\n" + "╔" + "═"*48 + "╗")
        print("║" + "   📊 هيكل جداول قاعدة بيانات مؤسسة بن عبيد   ".center(43) + "║")
        print("╚" + "═"*48 + "╝")

        for table, details in definitions.items():
            print(f"\n📂 الجدول: [ {table.upper()} ]")
            print("└──┬───")
            properties = details.get('properties', {})
            for i, (col, col_info) in enumerate(properties.items()):
                prefix = "   ├── " if i < len(properties) - 1 else "   └── "
                data_type = col_info.get('type', 'unknown')
                format_type = f"({col_info.get('format', '')})" if col_info.get('format') else ""
                print(f"{prefix}📌 {col.ljust(18)} │ 🛠 {data_type} {format_type}")
        
        print("\n" + "═"*50)
    else:
        print(f"❌ خطأ في الاتصال: {response.status_code}")
except Exception as e:
    print(f"❌ حدث خطأ: {e}")
