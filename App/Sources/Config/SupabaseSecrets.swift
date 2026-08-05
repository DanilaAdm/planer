import Foundation

/// Подключение к проекту Supabase, зашитое в приложение.
///
/// Благодаря этим значениям приложение готово к работе сразу после установки:
/// на новом устройстве достаточно ввести e-mail и пароль, а адрес сервера и ключ
/// вводить не нужно.
///
/// Ключ `sb_publishable_…` по замыслу Supabase публичный — он предназначен именно
/// для клиентских приложений и не даёт доступа к данным сам по себе: строки
/// фильтруют политики Row Level Security на стороне PostgreSQL по `owner_id`.
/// Секретный ключ (`sb_secret_…`) обходит RLS, поэтому в приложение он попадать
/// не должен никогда.
enum SupabaseSecrets {
    static let url = "https://suqsglpckpyysfavklna.supabase.co"
    static let publishableKey = "sb_publishable_SaD2atqHa5oFYv7Nzu0H7Q_A52a42G6"
}
