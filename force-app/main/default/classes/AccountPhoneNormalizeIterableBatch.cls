public with sharing class AccountPhoneNormalizeIterableBatch implements Database.Batchable<Account>, Database.Stateful {
  private final Iterable<Account> sourceRecords;

  public Integer processedCount = 0;
  public Integer updatedCount = 0;
  public Integer skippedCount = 0;
  public Integer failedCount = 0;

  public AccountPhoneNormalizeIterableBatch(Iterable<Account> sourceRecords) {
    this.sourceRecords = sourceRecords;
  }

  public Iterable<Account> start(Database.BatchableContext batchContext) {
    if (sourceRecords == null) {
      throw new BatchException('sourceRecords is required.');
    }

    return sourceRecords;
  }

  public void execute(
    Database.BatchableContext batchContext,
    List<Account> scope
  ) {
    List<Account> updates = new List<Account>();

    for (Account record : scope) {
      processedCount++;
      if (AccountPhoneDeltaUtil.hasPhoneDelta(record)) {
        updates.add(AccountPhoneDeltaUtil.buildPhoneUpdate(record));
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
      'Iterable batch finished. Processed=' +
        processedCount +
        ', Updated=' +
        updatedCount +
        ', Skipped=' +
        skippedCount +
        ', Failed=' +
        failedCount
    );
  }

  public class BatchException extends Exception {
  }

  public static Id run(Iterable<Account> sourceRecords, Integer scopeSize) {
    return Database.executeBatch(
      new AccountPhoneNormalizeIterableBatch(sourceRecords),
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
