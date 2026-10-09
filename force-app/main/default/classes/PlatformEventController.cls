public with sharing class PlatformEventController {
  @AuraEnabled
  public static String publishPlatformMessage(String message, String category) {
    if (String.isBlank(message)) {
      throw new AuraHandledException('Message cannot be blank.');
    }

    PlatformMessage__e eventRecord = new PlatformMessage__e(
      Message__c = message,
      Source__c = 'LWC Publisher',
      Category__c = String.isBlank(category) ? 'General' : category
    );

    Database.SaveResult result = EventBus.publish(eventRecord);
    if (result.isSuccess()) {
      return 'Platform event published successfully.';
    }

    String errorMessage = 'Unable to publish platform event.';
    if (result.getErrors() != null && !result.getErrors().isEmpty()) {
      errorMessage = result.getErrors()[0].getMessage();
    }
    throw new AuraHandledException(errorMessage);
  }
}
