@IsTest
private class AccountPhoneNormalizeBatchTest {
  @testSetup
  static void setupData() {
    insert new List<Account>{
      new Account(Name = 'Iterative Account 1', Phone = '555-010-0001'),
      new Account(Name = 'Iterative Account 2', Phone = '5550100002'),
      new Account(Name = 'Iterative Account 3')
    };
  }

  @IsTest
  static void queryLocatorBatchUpdatesOnlyDeltaRecords() {
    Test.startTest();
    Id jobId = AccountPhoneNormalizeQueryLocatorBatch.run(200);
    Test.stopTest();

    System.assertNotEquals(null, jobId);

    Account updatedAccount = [
      SELECT Phone
      FROM Account
      WHERE Name = 'Iterative Account 1'
      LIMIT 1
    ];
    Account unchangedAccount = [
      SELECT Phone
      FROM Account
      WHERE Name = 'Iterative Account 2'
      LIMIT 1
    ];
    Account blankPhoneAccount = [
      SELECT Phone
      FROM Account
      WHERE Name = 'Iterative Account 3'
      LIMIT 1
    ];

    System.assertEquals('5550100001', updatedAccount.Phone);
    System.assertEquals('5550100002', unchangedAccount.Phone);
    System.assertEquals(null, blankPhoneAccount.Phone);
  }

  @IsTest
  static void iterableBatchUpdatesOnlyDeltaRecords() {
    List<Account> sourceRecords = [
      SELECT Id, Phone
      FROM Account
      WHERE
        Name IN (
          'Iterative Account 1',
          'Iterative Account 2',
          'Iterative Account 3'
        )
      ORDER BY Name
    ];

    Test.startTest();
    Id jobId = AccountPhoneNormalizeIterableBatch.run(sourceRecords, 200);
    Test.stopTest();

    System.assertNotEquals(null, jobId);

    Account updatedAccount = [
      SELECT Phone
      FROM Account
      WHERE Name = 'Iterative Account 1'
      LIMIT 1
    ];
    Account unchangedAccount = [
      SELECT Phone
      FROM Account
      WHERE Name = 'Iterative Account 2'
      LIMIT 1
    ];
    Account blankPhoneAccount = [
      SELECT Phone
      FROM Account
      WHERE Name = 'Iterative Account 3'
      LIMIT 1
    ];

    System.assertEquals('5550100001', updatedAccount.Phone);
    System.assertEquals('5550100002', unchangedAccount.Phone);
    System.assertEquals(null, blankPhoneAccount.Phone);
  }

  @IsTest
  static void normalizationUtilityRemovesFormatting() {
    System.assertEquals(
      '15551234567',
      AccountPhoneDeltaUtil.normalizePhone('+1 (555) 123-4567')
    );
    System.assertEquals(null, AccountPhoneDeltaUtil.normalizePhone(null));
  }
}
