import requests

PROJECT_URL = "https://ackxfnznrjufhppaznjd.supabase.co"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFja3hmbnpucmp1ZmhwcGF6bmpkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTIyMTIzOCwiZXhwIjoyMDkwNzk3MjM4fQ.QFuG1ZsClKJjAefoY8HDjY6TzyA3RMmM_6U9rl9FHFY"
headers = {"apikey": API_KEY, "Authorization": f"Bearer {API_KEY}"}

def clean_val(val):
    if val is None: return "None"
    if isinstance(val, str) and len(val) > 50:
        return f"{val[:47]}..."
    return val

try:
    # جلب أول 5 صفوف من جدول المنتجات
    url = f"{PROJECT_URL}/rest/v1/products?select=*&limit=5"
    res = requests.get(url, headers=headers)

    print("\n" + "══════════════════════════════════════════════")
    print("📦 استعراض أول 5 منتجات - مؤسسة بن عبيد")
    print("══════════════════════════════════════════════\n")

    if res.status_code == 200:
        products = res.json()
        if not products:
            print("⚪ جدول المنتجات فارغ حالياً.")
        else:
            for index, row in enumerate(products, 1):
                print(f"📍 المنتج رقم: {index}")
                print("──────────────────────────────")
                for col, val in row.items():
                    print(f"  🔹 {col.ljust(18)} : {clean_val(val)}")
                print("----------------------------------------\n")
    else:
        print(f"❌ فشل جلب البيانات. رمز الخطأ: {res.status_code}")

except Exception as e:
    print(f"❌ حدث خطأ أثناء الاتصال: {e}")
