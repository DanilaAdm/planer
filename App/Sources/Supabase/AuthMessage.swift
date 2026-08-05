import Foundation
import Supabase

/// Понятные тексты вместо английских сообщений Supabase.
///
/// Supabase возвращает ошибки строками вида «Invalid login credentials», которые
/// показывать пользователю нельзя. Разбор идёт по машинному коду `errorCode`, а
/// не по тексту: текст сообщения на сервере меняется от версии к версии.
enum AuthMessage {
    /// Единый текст для любой ситуации «пара e-mail + пароль не подошла».
    ///
    /// Намеренно не различаем «нет такого аккаунта» и «неверный пароль»: иначе
    /// форма входа превращается в способ узнать, зарегистрирован ли адрес.
    static let invalidCredentials = "Email или пароль неверный\nПопробуйте снова"

    static let offline = "Нет связи с сервером. Проверьте интернет и попробуйте снова."

    static let notConfigured = "Не удалось подключиться к серверу. Проверьте адрес проекта в настройках."

    static let confirmationRequired = """
        Мы отправили письмо для подтверждения адреса. \
        Подтвердите почту по ссылке из письма и войдите снова.
        """

    static func text(for error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .invalidCredentials, .userNotFound:
                return invalidCredentials
            case .emailNotConfirmed:
                return confirmationRequired
            case .userAlreadyExists, .emailExists:
                return "Аккаунт с такой почтой уже существует. Войдите под ним."
            case .weakPassword:
                return "Пароль слишком простой. Используйте минимум 6 символов."
            case .validationFailed:
                return "Проверьте адрес почты и пароль: пароль должен быть не короче 6 символов."
            case .overRequestRateLimit, .overEmailSendRateLimit:
                return "Слишком много попыток подряд. Подождите минуту и попробуйте снова."
            case .signupDisabled:
                return "Регистрация новых аккаунтов сейчас отключена."
            case .emailAddressNotAuthorized:
                return "Этот адрес почты не допущен к регистрации в проекте."
            default:
                break
            }
        }

        if isConnectivityFailure(error) { return offline }

        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    /// Отличает отсутствие сети от отказа сервера: в первом случае повторять
    /// попытку осмысленно, во втором — нет.
    static func isConnectivityFailure(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return connectivityCodes.contains(urlError.code)
    }

    private static let connectivityCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
        .cannotConnectToHost, .dnsLookupFailed, .timedOut,
        .internationalRoamingOff, .dataNotAllowed, .secureConnectionFailed
    ]
}
