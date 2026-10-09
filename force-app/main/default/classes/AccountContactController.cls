public with sharing class AccountContactController {

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchKey) {

        if(String.isBlank(searchKey)) {
            return new List<Account>();
        }

        return [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE :('%' + searchKey + '%')
            LIMIT 10
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsByAccount(Id accountId) {

        if(accountId == null) {
            return new List<Contact>();
        }

        return [
            SELECT Id, Name, Email, Phone
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name
        ];
    }
}