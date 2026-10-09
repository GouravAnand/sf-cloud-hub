public with sharing class ChildRecordController {
    public ChildRecordController() {

    }

    @AuraEnabled(cacheable=true)
    public static List<Child__c> getChildRecords(Id parentId) {
        return [SELECT Id, Name, Parent__c FROM Child__c WHERE Parent__c = :parentId];
    }
}