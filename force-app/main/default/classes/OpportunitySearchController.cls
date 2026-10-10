public with sharing class OpportunitySearchController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> searchOpportunities(
        String searchKey,
        Integer pageSize,
        String lastSeenName,
        Id lastSeenId
    ) {
        validateInput(searchKey, pageSize);

        String normalizedSearchKey = searchKey.trim();

        return [
            SELECT
                Id,
                Name,
                StageName,
                CloseDate,
                Amount,
                Account.Name,
                Owner.Name
            FROM Opportunity
            WHERE Name LIKE :normalizedSearchKey + '%'
              AND (Name, Id) > (:lastSeenName, :lastSeenId)
            ORDER BY Name ASC, Id ASC
            LIMIT :pageSize
            WITH USER_MODE
        ];
    }

    private static void validateInput(String searchKey, Integer pageSize) {
        if (String.isBlank(searchKey) || searchKey.trim().length() < 2) {
            throw new AuraHandledException(
                'Please enter at least 2 characters to search.'
            );
        }

        if (pageSize == null || pageSize < 1 || pageSize > 50) {
            throw new AuraHandledException(
                'Page size must be between 1 and 50.'
            );
        }
    }
}