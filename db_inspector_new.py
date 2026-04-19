import pg8000.native

try:
    print("⏳ جاري الاتصال بمشروع بن عبيد عبر المنفذ 6543...")
    conn = pg8000.native.Connection(
        user="postgres",
        password="770491653mall_2026", 
        host="db.ackxfnznrjufhppaznjd.supabase.co",
        port=6543,
        database="postgres"
    )

    tables = conn.run("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")

    print("\n" + "="*60)
    print("🏠 هيكل قاعدة بيانات مؤسسة بن عبيد")
    print("="*60)

    for table in tables:
        t_name = table[0]
        print(f"\n📊 الجدول: {t_name.upper()}")
        columns = conn.run(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{t_name}'")
        cols_display = " | ".join([f"{c[0]} ({c[1]})" for c in columns])
        print(f"📌 الأعمدة: {cols_display}")
        try:
            rows = conn.run(f'SELECT * FROM "{t_name}" LIMIT 2')
            if rows:
                for row in rows: print(f"📝 بيانات: {row}")
            else: print("📝 (جدول فارغ)")
        except: print("⚠️ تعذر جلب البيانات")
        print("-" * 40)

    conn.close()
    print("\n✅ تم الفحص بنجاح.")

except Exception as e:
    print(f"\n❌ فشل الاتصال: {e}")
