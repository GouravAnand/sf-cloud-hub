public with sharing class ProdDataSyncService {
    
    public class SyncException extends Exception {
    }

    public class SyncResult {
        public String sourceObjectApiName;
        public String targetObjectApiName;
        public Integer recordsReturned;
        public Integer recordsInserted;
        public List<Id> sandboxRecordIds = new List<Id>();
        public String soql;
    }

    public class SyncJob implements Queueable, Database.AllowsCallouts {
        private final String namedCredential;
        private final String sourceObjectApiName;
        private final String targetObjectApiName;
        private final String whereClause;
        private final Integer limitSize;

        public SyncJob(
            String namedCredential,
            String sourceObjectApiName,
            String targetObjectApiName,
            String whereClause,
            Integer limitSize
        ) {
            this.namedCredential = namedCredential;
            this.sourceObjectApiName = sourceObjectApiName;
            this.targetObjectApiName = targetObjectApiName;
            this.whereClause = whereClause;
            this.limitSize = limitSize;
        }

        public void execute(QueueableContext context) {
            syncFromProduction(
                namedCredential,
                sourceObjectApiName,
                targetObjectApiName,
                whereClause,
                limitSize
            );
        }
    }

    /**
     * Enqueues an async job to sync records from production
     * Use this for large datasets to avoid governor limits
     * @param namedCredential Named Credential for Prod org
     * @param sourceObjectApiName Source object API name (e.g., 'Account')
     * @param targetObjectApiName Target object API name in Sandbox
     * @param whereClause Optional WHERE clause (e.g., 'Industry = "Tech"')
     * @param limitSize Max records to sync (max 2000)
     * @return Job ID for tracking
     */
    public static Id enqueueSyncFromProduction(
        String namedCredential,
        String sourceObjectApiName,
        String targetObjectApiName,
        String whereClause,
        Integer limitSize
    ) {
        return System.enqueueJob(
            new SyncJob(
                namedCredential,
                sourceObjectApiName,
                targetObjectApiName,
                whereClause,
                limitSize
            )
        );
    }

    /**
     * Synchronously syncs records from production to sandbox
     * Only non-relationship fields are synced
     * @param namedCredential Named Credential for Prod org
     * @param sourceObjectApiName Source object API name
     * @param targetObjectApiName Target object API name
     * @param whereClause Optional WHERE clause
     * @param limitSize Max records to sync (max 2000)
     * @return SyncResult with details of inserted records
     */
    public static SyncResult syncFromProduction(
        String namedCredential,
        String sourceObjectApiName,
        String targetObjectApiName,
        String whereClause,
        Integer limitSize
    ) {
        // Validate and normalize inputs
        validateNamedValue(namedCredential, 'Named Credential');
        sourceObjectApiName = normalizeObjectApiName(sourceObjectApiName, 'sourceObjectApiName');
        targetObjectApiName = normalizeObjectApiName(targetObjectApiName, 'targetObjectApiName');

        // Build SOQL with only non-relationship fields
        List<String> sourceFields = getNonRelationshipFieldNames(sourceObjectApiName);
        String soql = buildSoql(sourceObjectApiName, sourceFields, whereClause, limitSize);
        
        // Query production records via REST API
        List<Map<String, Object>> productionRecords = ProdRestApiClient.queryProduction(
            namedCredential,
            soql
        );
        
        // Insert records into sandbox
        List<Id> insertedIds = insertSandboxRecords(targetObjectApiName, productionRecords);

        // Build and return result
        return buildSyncResult(sourceObjectApiName, targetObjectApiName, productionRecords, insertedIds, soql);
    }

    /**
     * Gets non-relationship field names for an object
     * Excludes: relationships, BASE64, REFERENCE, ADDRESS, LOCATION fields
     * @param objectApiName Object to describe
     * @return Sorted list of queryable field names
     */
    public static List<String> getNonRelationshipFieldNames(String objectApiName) {
        objectApiName = normalizeObjectApiName(objectApiName, 'objectApiName');
        Schema.DescribeSObjectResult objectDescribe = getObjectDescribe(objectApiName);
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        List<String> fieldNames = new List<String>();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            if (isQueryableNonRelationshipField(fieldDescribe)) {
                fieldNames.add(fieldDescribe.getName());
            }
        }

        fieldNames.sort();
        return fieldNames;
    }

    /**
     * Inserts records into target sandbox object
     * Handles type coercion and field validation
     * @param targetObjectApiName Target object API name
     * @param records List of record maps from production
     * @return List of inserted record IDs
     */
    public static List<Id> insertSandboxRecords(
        String targetObjectApiName,
        List<Map<String, Object>> records
    ) {
        targetObjectApiName = normalizeObjectApiName(targetObjectApiName, 'targetObjectApiName');
        if (records == null || records.isEmpty()) {
            return new List<Id>();
        }

        Schema.DescribeSObjectResult targetDescribe = getObjectDescribe(targetObjectApiName);
        Map<String, Schema.SObjectField> targetFields = targetDescribe.fields.getMap();
        List<SObject> recordsToInsert = new List<SObject>();

        for (Map<String, Object> sourceRecord : records) {
            SObject targetRecord = targetDescribe.getSObjectType().newSObject();

            for (String fieldName : sourceRecord.keySet()) {
                if (!targetFields.containsKey(fieldName)) {
                    continue;
                }

                Schema.DescribeFieldResult fieldDescribe = targetFields.get(fieldName).getDescribe();
                if (!isInsertableDataField(fieldDescribe)) {
                    continue;
                }

                targetRecord.put(
                    fieldDescribe.getName(),
                    coerceValue(fieldDescribe, sourceRecord.get(fieldName))
                );
            }

            recordsToInsert.add(targetRecord);
        }

        insert recordsToInsert;

        List<Id> insertedIds = new List<Id>();
        for (SObject insertedRecord : recordsToInsert) {
            insertedIds.add(insertedRecord.Id);
        }
        return insertedIds;
    }

    /**
     * Builds SOQL query with specified fields, where clause, and limit
     */
    @TestVisible
    private static String buildSoql(
        String objectApiName,
        List<String> fieldNames,
        String whereClause,
        Integer limitSize
    ) {
        if (fieldNames == null || fieldNames.isEmpty()) {
            throw new SyncException('No queryable non-relationship fields found for ' + objectApiName);
        }

        String soql = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM ' + objectApiName;
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + stripLeadingWhere(whereClause);
        }
        if (limitSize != null && limitSize > 0) {
            soql += ' LIMIT ' + Math.min(limitSize, 2000);
        }
        return soql;
    }

    /**
     * Builds the sync result object
     */
    private static SyncResult buildSyncResult(
        String sourceObjectApiName,
        String targetObjectApiName,
        List<Map<String, Object>> productionRecords,
        List<Id> insertedIds,
        String soql
    ) {
        SyncResult result = new SyncResult();
        result.sourceObjectApiName = sourceObjectApiName;
        result.targetObjectApiName = targetObjectApiName;
        result.recordsReturned = productionRecords.size();
        result.recordsInserted = insertedIds.size();
        result.sandboxRecordIds = insertedIds;
        result.soql = soql;
        return result;
    }

    /**
     * Determines if a field is queryable and not a relationship
     */
    private static Boolean isQueryableNonRelationshipField(
        Schema.DescribeFieldResult fieldDescribe
    ) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        return fieldDescribe.isAccessible() &&
            fieldDescribe.getRelationshipName() == null &&
            fieldType != Schema.DisplayType.BASE64 &&
            fieldType != Schema.DisplayType.REFERENCE &&
            fieldType != Schema.DisplayType.ADDRESS &&
            fieldType != Schema.DisplayType.LOCATION;
    }

    /**
     * Determines if a field is insertable and not a relationship
     */
    private static Boolean isInsertableDataField(Schema.DescribeFieldResult fieldDescribe) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        return fieldDescribe.isCreateable() &&
            fieldDescribe.getRelationshipName() == null &&
            fieldType != Schema.DisplayType.BASE64 &&
            fieldType != Schema.DisplayType.REFERENCE &&
            fieldType != Schema.DisplayType.ADDRESS &&
            fieldType != Schema.DisplayType.LOCATION;
    }

    /**
     * Coerces field values to the correct Salesforce type
     * Handles DATE, DATETIME, TIME, INTEGER, DOUBLE, CURRENCY, PERCENT, BOOLEAN
     */
    private static Object coerceValue(Schema.DescribeFieldResult fieldDescribe, Object rawValue) {
        if (rawValue == null) {
            return null;
        }

        String rawText = String.valueOf(rawValue);
        switch on fieldDescribe.getType() {
            when DATE {
                return Date.valueOf(rawText);
            }
            when DATETIME {
                return Datetime.valueOfGmt(rawText.replace('T', ' ').replace('Z', ''));
            }
            when TIME {
                return parseTime(rawText);
            }
            when INTEGER {
                return Integer.valueOf(rawText);
            }
            when DOUBLE, CURRENCY, PERCENT {
                return Decimal.valueOf(rawText);
            }
            when BOOLEAN {
                return Boolean.valueOf(rawText);
            }
            when else {
                return rawValue;
            }
        }
    }

    /**
     * Parses time string to Time object
     */
    private static Time parseTime(String rawText) {
        String normalizedTime = rawText;
        if (normalizedTime.endsWith('Z')) {
            normalizedTime = normalizedTime.substring(0, normalizedTime.length() - 1);
        }

        List<String> timeParts = normalizedTime.split(':');
        Integer hour = Integer.valueOf(timeParts[0]);
        Integer minute = Integer.valueOf(timeParts[1]);
        Decimal secondValue = Decimal.valueOf(timeParts[2]);
        Integer second = secondValue.intValue();
        Integer millisecond = ((secondValue - second) * 1000).intValue();
        return Time.newInstance(hour, minute, second, millisecond);
    }

    /**
     * Gets object describe result from global describe
     */
    private static Schema.DescribeSObjectResult getObjectDescribe(String objectApiName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectApiName)) {
            throw new SyncException('Unknown object API name: ' + objectApiName);
        }
        return globalDescribe.get(objectApiName).getDescribe();
    }

    /**
     * Normalizes and validates object API name
     */
    private static String normalizeObjectApiName(String objectApiName, String parameterName) {
        validateNamedValue(objectApiName, parameterName);
        String normalizedName = objectApiName.trim();
        if (!Pattern.matches('[A-Za-z][A-Za-z0-9_]*(__c|__mdt|__x|__e|__b)?', normalizedName)) {
            throw new SyncException('Invalid object API name: ' + objectApiName);
        }
        return normalizedName;
    }

    /**
     * Validates that a value is not blank
     */
    private static void validateNamedValue(String value, String parameterName) {
        if (String.isBlank(value)) {
            throw new SyncException(parameterName + ' is required.');
        }
    }

    /**
     * Removes leading 'WHERE ' from where clause if present
     */
    private static String stripLeadingWhere(String whereClause) {
        String trimmedWhere = whereClause.trim();
        if (trimmedWhere.toLowerCase().startsWith('where ')) {
            return trimmedWhere.substring(6).trim();
        }
        return trimmedWhere;
    }
}
