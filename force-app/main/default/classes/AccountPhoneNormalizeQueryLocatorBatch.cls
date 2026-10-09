public with sharing class AccountPhoneNormalizeQueryLocatorBatch implements Database.Batchable<SObject>, Database.Stateful {
  public Integer processedCount = 0;
  public Integer updatedCount = 0;
  public Integer skippedCount = 0;
  public Integer failedCount = 0;

  public Database.QueryLocator start(Database.BatchableContext batchContext) {
    return Database.getQueryLocator(
      'SELECT Id, Phone FROM Account WHERE Phone != null ORDER BY Id'
    );
  }

  public void execute(
    Database.BatchableContext batchContext,
    List<SObject> scope
  ) {
    List<Account> updates = new List<Account>();

    for (SObject record : scope) {
      Account accountRecord = (Account) record;
      processedCount++;
      if (AccountPhoneDeltaUtil.hasPhoneDelta(accountRecord)) {
        updates.add(AccountPhoneDeltaUtil.buildPhoneUpdate(accountRecord));
      } else {
        skippedCount++;
      }
    }

    if (updates.isEmpty()) {
      return;
    }

    Database.SaveResult[] results = Database.update(updates, false);
    for (Database.SaveResult result : results) {
      if (result.isSuccess()) {
        updatedCount++;
      } else {
        failedCount++;
      }
    }
  }

  public void finish(Database.BatchableContext batchContext) {
    System.debug(
      LoggingLevel.INFO,
      'QueryLocator batch finished. Processed=' +
        processedCount +
        ', Updated=' +
        updatedCount +
        ', Skipped=' +
        skippedCount +
        ', Failed=' +
        failedCount
    );
  }

  public static Id run(Integer scopeSize) {
    return Database.executeBatch(
      new AccountPhoneNormalizeQueryLocatorBatch(),
      normalizeScopeSize(scopeSize)
    );
  }

  @TestVisible
  private static Integer normalizeScopeSize(Integer scopeSize) {
    Integer effectiveScopeSize = scopeSize == null ||
      scopeSize <= 0
      ? 200
      : scopeSize;
    return Math.min(effectiveScopeSize, 200);
  }
}
