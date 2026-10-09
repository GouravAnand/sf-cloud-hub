public with sharing class ProdDataSyncUtil {
    public static final String DEFAULT_API_VERSION = 'v66.0';

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

    public static SyncResult syncFromProduction(
        String namedCredential,
        String sourceObjectApiName,
        String targetObjectApiName,
        String whereClause,
        Integer limitSize
    ) {
        validateNamedValue(namedCredential, 'Named Credential');
        sourceObjectApiName = normalizeObjectApiName(sourceObjectApiName, 'sourceObjectApiName');
        targetObjectApiName = normalizeObjectApiName(targetObjectApiName, 'targetObjectApiName');

        List<String> sourceFields = getNonRelationshipFieldNames(sourceObjectApiName);
        String soql = buildSoql(sourceObjectApiName, sourceFields, whereClause, limitSize);
        List<Map<String, Object>> productionRecords = queryProduction(
            namedCredential,
            soql,
            DEFAULT_API_VERSION
        );
        List<Id> insertedIds = insertSandboxRecords(targetObjectApiName, productionRecords);

        SyncResult result = new SyncResult();
        result.sourceObjectApiName = sourceObjectApiName;
        result.targetObjectApiName = targetObjectApiName;
        result.recordsReturned = productionRecords.size();
        result.recordsInserted = insertedIds.size();
        result.sandboxRecordIds = insertedIds;
        result.soql = soql;
        return result;
    }

    public static List<String> getNonRelationshipFieldNames(String objectApiName) {
        objectApiName = normalizeObjectApiName(objectApiName, 'objectApiName');
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
        Schema.DescribeSObjectResult objectDescribe = sObjType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        List<String> fieldNames = new List<String>();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fldDesc = fieldMap.get(fieldName).getDescribe();

            if (fldDesc.isAccessible && !isRelationship_CompoundFld(fldDesc)) {
                fieldNames.add(fieldDescribe.getName());
            }
        }

        fieldNames.sort();
        return fieldNames;
    }

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

    @TestVisible
    private static List<Map<String, Object>> queryProduction(
        String namedCredential,
        String soql,
        String apiVersion
    ) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:' +
                EncodingUtil.urlEncode(namedCredential, 'UTF-8') +
                '/services/data/' +
                apiVersion +
                '/query?q=' +
                EncodingUtil.urlEncode(soql, 'UTF-8')
        );
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();
        if (statusCode < 200 || statusCode > 299) {
            throw new SyncException(
                'Production query failed. Status ' +
                    statusCode +
                    ': ' +
                    response.getBody()
            );
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
        );
        List<Object> rawRecords = (List<Object>) payload.get('records');
        List<Map<String, Object>> records = new List<Map<String, Object>>();

        if (rawRecords == null) {
            return records;
        }

        for (Object rawRecord : rawRecords) {
            Map<String, Object> record = (Map<String, Object>) rawRecord;
            record.remove('attributes');
            records.add(record);
        }

        return records;
    }

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

    private static Boolean isRelationship_CompoundFld(
        Schema.DescribeFieldResult fieldDescribe
    ) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        return fieldDescribe.isAccessible() && fieldDescribe.getRelationshipName() == null &&
                fieldType != Schema.DisplayType.BASE64 &&
                fieldType != Schema.DisplayType.REFERENCE &&
                fieldType != Schema.DisplayType.ADDRESS &&
                fieldType != Schema.DisplayType.LOCATION;
    }

    private static Boolean isInsertableDataField(Schema.DescribeFieldResult fieldDescribe) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        return fieldDescribe.isCreateable() &&
            fieldDescribe.getRelationshipName() == null &&
            fieldType != Schema.DisplayType.BASE64 &&
            fieldType != Schema.DisplayType.REFERENCE &&
            fieldType != Schema.DisplayType.ADDRESS &&
            fieldType != Schema.DisplayType.LOCATION;
    }

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

    private static Schema.DescribeSObjectResult getObjectDescribe(String objectApiName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectApiName)) {
            throw new SyncException('Unknown object API name: ' + objectApiName);
        }
        return globalDescribe.get(objectApiName).getDescribe();
    }

    private static String normalizeObjectApiName(String objectApiName, String parameterName) {
        validateNamedValue(objectApiName, parameterName);
        String normalizedName = objectApiName.trim();
        if (!Pattern.matches('[A-Za-z][A-Za-z0-9_]*(__c|__mdt|__x|__e|__b)?', normalizedName)) {
            throw new SyncException('Invalid object API name: ' + objectApiName);
        }
        return normalizedName;
    }

    private static void validateNamedValue(String value, String parameterName) {
        if (String.isBlank(value)) {
            throw new SyncException(parameterName + ' is required.');
        }
    }

    private static String stripLeadingWhere(String whereClause) {
        String trimmedWhere = whereClause.trim();
        if (trimmedWhere.toLowerCase().startsWith('where ')) {
            return trimmedWhere.substring(6).trim();
        }
        return trimmedWhere;
    }
}
