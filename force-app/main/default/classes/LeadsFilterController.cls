public with sharing class LeadsFilterController {
  @AuraEnabled(cacheable=true)
  public static List<Lead> getLeads(String statusFilter) {
    if (String.isBlank(statusFilter)) {
      return [
        SELECT Id, Name, Company, Status, Email, Phone, Owner.Name, CreatedDate
        FROM Lead
        ORDER BY CreatedDate DESC
        LIMIT 200
      ];
    }

    return [
      SELECT Id, Name, Company, Status, Email, Phone, Owner.Name, CreatedDate
      FROM Lead
      WHERE Status = :statusFilter
      ORDER BY CreatedDate DESC
      LIMIT 200
    ];
  }
}
