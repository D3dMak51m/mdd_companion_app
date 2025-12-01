class AppConstants {
  static const String baseUrl = 'http://192.168.1.6:8000'; // Замените на реальный URL
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Замените на реальный URL

  // BLE UUIDs
  static const String serviceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String sosCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb';
  static const String ackCharacteristicUuid = '00002a38-0000-1000-8000-00805f9b34fb'; // Пример
  static const String configCharacteristicUuid = '00002a39-0000-1000-8000-00805f9b34fb'; // Пример

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userBoxName = 'user_box';
  static const String settingsBoxName = 'settings_box';
  static const String userIdKey = 'user_id';
}