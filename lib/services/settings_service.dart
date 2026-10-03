import 'package:shared_preferences/shared_preferences.dart';

/// Настройки приложения (ТЗ §4.8) — валюта и формат даты. Хранятся локально
/// (SharedPreferences, не Supabase — это настройка устройства/приложения,
/// а не данные пользователя, которые нужно синхронизировать).
///
/// По решению Олега (см. журнал 4.8) значения только сохраняются и
/// показываются на экране «Настройки» — вывод сумм/дат по всему остальному
/// приложению по-прежнему жёстко «₽» и дд.мм.гггг (как раз выбраны по
/// умолчанию здесь), переписывать все экраны под них сейчас избыточно.
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _currencyKey = 'settings_currency';
  static const _dateFormatKey = 'settings_date_format';

  static const defaultCurrency = '₽';
  static const defaultDateFormat = 'дд.мм.гггг';

  static const currencyOptions = ['₽', '\$', '€'];
  static const dateFormatOptions = ['дд.мм.гггг', 'мм/дд/гггг', 'гггг-мм-дд'];

  String get currency => _prefs.getString(_currencyKey) ?? defaultCurrency;

  Future<void> setCurrency(String value) => _prefs.setString(_currencyKey, value);

  String get dateFormat => _prefs.getString(_dateFormatKey) ?? defaultDateFormat;

  Future<void> setDateFormat(String value) => _prefs.setString(_dateFormatKey, value);

  static const _yandexTokenKey = 'settings_yandex_access_token';

  /// access_token Яндекс.Диска (ТЗ §4.10) — экран «Отчёты» получает его
  /// через YandexDiskService.authorize() (Этап 3.11) и хранит здесь же,
  /// вместе с остальными настройками приложения; сам сервис токен не
  /// хранит (см. его doc-комментарий).
  String? get yandexAccessToken => _prefs.getString(_yandexTokenKey);

  Future<void> setYandexAccessToken(String value) =>
      _prefs.setString(_yandexTokenKey, value);

  Future<void> clearYandexAccessToken() => _prefs.remove(_yandexTokenKey);

  static const _selectedAddressKey = 'settings_selected_address';

  /// Выбранный адрес на главном экране (ТЗ §4.13) — чтобы при следующем
  /// открытии приложения не выбирать заново. null — «Все» (без фильтра).
  String? get selectedAddress => _prefs.getString(_selectedAddressKey);

  Future<void> setSelectedAddress(String? value) => value == null
      ? _prefs.remove(_selectedAddressKey)
      : _prefs.setString(_selectedAddressKey, value);
}
