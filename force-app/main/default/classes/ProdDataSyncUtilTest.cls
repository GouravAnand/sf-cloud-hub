@IsTest
private class ProdDataSyncUtilTest {
    private class ProductionQueryMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().startsWith('callout:Prod_NC/services/data/v66.0/query'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(
                '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"Account"},"Name":"Acme Production","Phone":"555-0100","Id":"001000000000001AAA"}]}'
            );
            return response;
        }
    }

    private class FailedProductionQueryMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(401);
            response.setBody('{"message":"Session expired or invalid"}');
            return response;
        }
    }

    @IsTest
    static void getNonRelationshipFieldNamesReturnsDirectFieldsOnly() {
        List<String> fieldNames = ProdDataSyncUtil.getNonRelationshipFieldNames('Account');

        System.assert(fieldNames.contains('Name'), 'Expected standard data field.');
        System.assert(!fieldNames.contains('OwnerId'), 'Reference fields should be skipped.');
    }

    @IsTest
    static void syncFromProductionQueriesAndInsertsSandboxRecords() {
        Test.setMock(HttpCalloutMock.class, new ProductionQueryMock());

        Test.startTest();
        ProdDataSyncUtil.SyncResult result = ProdDataSyncUtil.syncFromProduction(
            'Prod_NC',
            'Account',
            'Account',
            'Name != null',
            1
        );
        Test.stopTest();

        System.assertEquals(1, result.recordsReturned);
        System.assertEquals(1, result.recordsInserted);
        System.assertEquals(1, result.sandboxRecordIds.size());
        System.assert(result.soql.contains(' FROM Account WHERE Name != null LIMIT 1'));

        Account insertedAccount = [
            SELECT Name, Phone
            FROM Account
            WHERE Id = :result.sandboxRecordIds[0]
        ];
        System.assertEquals('Acme Production', insertedAccount.Name);
        System.assertEquals('555-0100', insertedAccount.Phone);
    }

    @IsTest
    static void enqueueSyncFromProductionRunsAsQueueable() {
        Test.setMock(HttpCalloutMock.class, new ProductionQueryMock());

        Test.startTest();
        Id jobId = ProdDataSyncUtil.enqueueSyncFromProduction(
            'Prod_NC',
            'Account',
            'Account',
            null,
            1
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Acme Production']);
    }

    @IsTest
    static void productionErrorsThrowSyncException() {
        Test.setMock(HttpCalloutMock.class, new FailedProductionQueryMock());

        Test.startTest();
        try {
            ProdDataSyncUtil.syncFromProduction('Prod_NC', 'Account', 'Account', null, 1);
            System.assert(false, 'Expected SyncException.');
        } catch (ProdDataSyncUtil.SyncException exceptionResult) {
            System.assert(exceptionResult.getMessage().contains('Status 401'));
        }
        Test.stopTest();
    }
}
