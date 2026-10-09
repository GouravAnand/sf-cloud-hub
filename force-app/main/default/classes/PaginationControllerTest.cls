/**
 * PaginationControllerTest
 * 
 * Test class for PaginationController
 * Covers both pagination and lazy loading approaches
 */
@isTest
private class PaginationControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test accounts for pagination testing
        List<Account> accounts = new List<Account>();
        for (Integer i = 1; i <= 250; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = i <= 125 ? 'Technology' : 'Finance'
            ));
        }
        insert accounts;
    }

    // ===== PAGINATION TESTS =====

    @isTest
    static void testGetPaginatedRecordsFirstPage() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                1,
                50,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(50, result.records.size(), 'Should return 50 records on first page');
        System.assertEquals(1, result.pageNumber, 'Page number should be 1');
        System.assertEquals(250, result.totalRecords, 'Total records should be 250');
        System.assertEquals(5, result.totalPages, 'Total pages should be 5');
        System.assertTrue(result.hasNextPage, 'Should have next page');
        System.assertFalse(result.hasPreviousPage, 'Should not have previous page');
    }

    @isTest
    static void testGetPaginatedRecordsMiddlePage() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                3,
                50,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(50, result.records.size(), 'Should return 50 records');
        System.assertEquals(3, result.pageNumber, 'Page number should be 3');
        System.assertTrue(result.hasNextPage, 'Should have next page');
        System.assertTrue(result.hasPreviousPage, 'Should have previous page');
    }

    @isTest
    static void testGetPaginatedRecordsLastPage() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                5,
                50,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(50, result.records.size(), 'Should return 50 records on last page');
        System.assertEquals(5, result.pageNumber, 'Page number should be 5');
        System.assertFalse(result.hasNextPage, 'Should not have next page');
        System.assertTrue(result.hasPreviousPage, 'Should have previous page');
    }

    @isTest
    static void testGetPaginatedRecordsWithFilters() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                1,
                100,
                'Industry = \'Technology\'',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(125, result.totalRecords, 'Should return only Technology industry records');
        System.assertEquals(2, result.totalPages, 'Total pages should be 2 for filtered results');
    }

    @isTest
    static void testGetPaginatedRecordsInvalidPageNumber() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                0,
                50,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(1, result.pageNumber, 'Invalid page number should default to 1');
    }

    @isTest
    static void testGetPaginatedRecordsInvalidPageSize() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                1,
                0,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(100, result.records.size(), 'Invalid page size should default to 100');
    }

    @isTest
    static void testGetPaginatedRecordsCustomSort() {
        Test.startTest();
        PaginationController.PaginationResult result = 
            PaginationController.getPaginatedRecords(
                'Account',
                1,
                50,
                '',
                'Name',
                'DESC'
            );
        Test.stopTest();

        System.assertEquals(50, result.records.size(), 'Should return sorted records');
    }

    // ===== LAZY LOADING TESTS =====

    @isTest
    static void testGetInitialLazyLoadRecords() {
        Test.startTest();
        PaginationController.LazyLoadResult result = 
            PaginationController.getInitialLazyLoadRecords(
                'Account',
                50,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(50, result.records.size(), 'Should return 50 initial records');
        System.assertTrue(result.hasMore, 'Should indicate more records available');
        System.assertEquals(250, result.totalRecords, 'Total records should be 250');
        System.assertNotEquals('', result.cursor, 'Cursor should be set');
    }

    @isTest
    static void testGetInitialLazyLoadRecordsWithFilters() {
        Test.startTest();
        PaginationController.LazyLoadResult result = 
            PaginationController.getInitialLazyLoadRecords(
                'Account',
                50,
                'Industry = \'Technology\'',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(50, result.records.size(), 'Should return 50 filtered records');
        System.assertEquals(125, result.totalRecords, 'Total records should be 125');
        System.assertTrue(result.hasMore, 'Should have more records');
    }

    @isTest
    static void testGetNextLazyLoadBatch() {
        // First, get initial records to get cursor
        PaginationController.LazyLoadResult initialResult = 
            PaginationController.getInitialLazyLoadRecords(
                'Account',
                50,
                '',
                'Id',
                'ASC'
            );

        Test.startTest();
        PaginationController.LazyLoadResult nextResult = 
            PaginationController.getNextLazyLoadBatch(
                'Account',
                initialResult.cursor,
                50,
                '',
                'Id',
                'ASC'
            );
        Test.stopTest();

        System.assertEquals(50, nextResult.records.size(), 'Should return 50 records in next batch');
        System.assertTrue(nextResult.hasMore, 'Should have more records');
        System.assertNotEquals(initialResult.cursor, nextResult.cursor, 'Cursor should be updated');
    }

    @isTest
    static void testGetNextLazyLoadBatchEmptyCursor() {
        Test.startTest();
        try {
            PaginationController.getNextLazyLoadBatch(
                'Account',
                '',
                50,
                '',
                'Id',
                'ASC'
            );
            System.assert(false, 'Should throw exception for empty cursor');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Cursor is required'), 
                          'Should show cursor required error');
        }
        Test.stopTest();
    }

    @isTest
    static void testLazyLoadMultipleBatches() {
        Test.startTest();
        
        // Get initial batch
        PaginationController.LazyLoadResult result1 = 
            PaginationController.getInitialLazyLoadRecords(
                'Account',
                50,
                '',
                'Id',
                'ASC'
            );
        System.assertEquals(50, result1.records.size());

        // Get second batch
        PaginationController.LazyLoadResult result2 = 
            PaginationController.getNextLazyLoadBatch(
                'Account',
                result1.cursor,
                50,
                '',
                'Id',
                'ASC'
            );
        System.assertEquals(50, result2.records.size());

        // Get third batch
        PaginationController.LazyLoadResult result3 = 
            PaginationController.getNextLazyLoadBatch(
                'Account',
                result2.cursor,
                50,
                '',
                'Id',
                'ASC'
            );
        System.assertEquals(50, result3.records.size());

        // Get fourth batch
        PaginationController.LazyLoadResult result4 = 
            PaginationController.getNextLazyLoadBatch(
                'Account',
                result3.cursor,
                50,
                '',
                'Id',
                'ASC'
            );
        System.assertEquals(50, result4.records.size());

        // Get fifth batch (should have 50 remaining records)
        PaginationController.LazyLoadResult result5 = 
            PaginationController.getNextLazyLoadBatch(
                'Account',
                result4.cursor,
                50,
                '',
                'Id',
                'ASC'
            );
        System.assertEquals(50, result5.records.size());
        System.assertFalse(result5.hasMore, 'Should not have more records after last batch');

        Test.stopTest();
    }

    // ===== HELPER METHOD TESTS =====

    @isTest
    static void testBuildWhereClause() {
        Map<String, String> filters = new Map<String, String>();
        filters.put('Industry', 'Technology');
        filters.put('BillingCity', 'New York');

        Test.startTest();
        String whereClause = PaginationController.buildWhereClause(filters);
        Test.stopTest();

        System.assert(whereClause.contains('Industry'), 'Should contain Industry filter');
        System.assert(whereClause.contains('Technology'), 'Should contain value');
        System.assert(whereClause.contains('AND'), 'Should have AND operator');
    }

    @isTest
    static void testBuildWhereClauseEmpty() {
        Test.startTest();
        String whereClause = PaginationController.buildWhereClause(new Map<String, String>());
        Test.stopTest();

        System.assertEquals('', whereClause, 'Empty filters should return empty string');
    }

    @isTest
    static void testIsValidSObjectType() {
        Test.startTest();
        Boolean isValid = PaginationController.isValidSObjectType('Account');
        Boolean isInvalid = PaginationController.isValidSObjectType('InvalidObject');
        Test.stopTest();

        System.assertTrue(isValid, 'Account should be valid SObject');
        System.assertFalse(isInvalid, 'InvalidObject should not be valid');
    }

    @isTest
    static void testPaginationResultWrapper() {
        PaginationController.PaginationResult result = 
            new PaginationController.PaginationResult();

        System.assertEquals(0, result.records.size(), 'Records list should be empty');
        System.assertEquals(1, result.pageNumber, 'Default page number should be 1');
        System.assertEquals(0, result.totalRecords, 'Default total records should be 0');
        System.assertFalse(result.hasNextPage, 'Default hasNextPage should be false');
        System.assertFalse(result.hasPreviousPage, 'Default hasPreviousPage should be false');
    }

    @isTest
    static void testLazyLoadResultWrapper() {
        PaginationController.LazyLoadResult result = 
            new PaginationController.LazyLoadResult();

        System.assertEquals(0, result.records.size(), 'Records list should be empty');
        System.assertEquals('', result.cursor, 'Default cursor should be empty');
        System.assertFalse(result.hasMore, 'Default hasMore should be false');
        System.assertEquals(0, result.totalRecords, 'Default total records should be 0');
    }
}
