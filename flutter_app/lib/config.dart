class Config {
  // Default = localhost:8000, which works on:
  //   • a REAL USB device once you run:  adb reverse tcp:8000 tcp:8000
  //   • the iOS simulator / desktop / web
  // For an Android EMULATOR instead, override:
  //   flutter run --dart-define=API_BASE=http://10.0.2.2:8000
  // For a phone on the same Wi-Fi (no USB):
  //   flutter run --dart-define=API_BASE=http://<laptop-LAN-ip>:8000   (backend on --host 0.0.0.0)
  static const String apiBase =
      String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8000');

  // Supabase — publishable key is client-safe (RLS enforced).
  static const String supabaseUrl = 'https://zfzluirxexbefunbuyxf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_XxYRB6G6fs2nj46550hloA_-aH8Xm85';
}
