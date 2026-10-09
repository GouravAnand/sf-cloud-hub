public with sharing class AccountPhoneDeltaUtil {
  public static String normalizePhone(String phone) {
    if (String.isBlank(phone)) {
      return null;
    }

    return phone.replaceAll('[^0-9]', '');
  }

  public static Boolean hasPhoneDelta(Account record) {
    if (record == null) {
      return false;
    }

    String normalizedPhone = normalizePhone(record.Phone);
    return String.isNotBlank(normalizedPhone) &&
      normalizedPhone != record.Phone;
  }

  public static Account buildPhoneUpdate(Account record) {
    return new Account(Id = record.Id, Phone = normalizePhone(record.Phone));
  }
}
