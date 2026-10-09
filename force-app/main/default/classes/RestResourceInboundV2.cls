@RestResource(urlMapping='/inbound/upsert')
global class RestResourceInboundV2 {

    public class UpsertRequest {
        public String objectType { get; set; }
        public String externalIdField { get; set; }
        public List<Map<String, Object>> records { get; set; }
    }

    public class RecordResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String externalId { get; set; }
        @AuraEnabled public String error { get; set; }
    }

    public class ApiResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer failureCount { get; set; }
        @AuraEnabled public List<RecordResult> results { get; set; }
        @AuraEnabled public String statusCode { get; set; }

        public ApiResponse() {
            this.results = new List<RecordResult>();
            this.successCount = 0;
            this.failureCount = 0;
        }
    }

    @HttpPost
    global static ApiResponse doPost() {
        ApiResponse response = new ApiResponse();
        
        try {
            String body = RestContext.request.requestBody.toString();
            if (String.isEmpty(body)) {
                throw new IllegalArgumentException('Request body cannot be empty');
            }

            UpsertRequest req = (UpsertRequest) JSON.deserialize(body, UpsertRequest.class);
            
            if (String.isEmpty(req.objectType) || String.isEmpty(req.externalIdField) || 
                req.records == null || req.records.isEmpty() || req.records.size() > 200) {
                throw new IllegalArgumentException('Invalid request parameters');
            }

            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(req.objectType);
            if (sObjectType == null) {
                throw new IllegalArgumentException('Invalid object type: ' + req.objectType);
            }

            Schema.DescribeSObjectResult describe = sObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
            
            if (!fieldMap.containsKey(req.externalIdField.toLowerCase())) {
                throw new IllegalArgumentException('Field does not exist: ' + req.externalIdField);
            }

            List<SObject> records = new List<SObject>();
            for (Map<String, Object> recordMap : req.records) {
                SObject record = sObjectType.newSObject();
                for (String field : recordMap.keySet()) {
                    record.put(field, recordMap.get(field));
                }
                records.add(record);
            }

            Schema.SObjectField externalIdField = fieldMap.get(req.externalIdField.toLowerCase());
            Database.UpsertResult[] results = Database.upsert(records, externalIdField, false);

            response.totalRecords = results.size();
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                RecordResult rr = new RecordResult();
                rr.id = res.getId();
                rr.success = res.isSuccess();
                rr.externalId = String.valueOf(req.records[i].get(req.externalIdField));
                
                if (res.isSuccess()) {
                    rr.message = 'Upserted';
                    response.successCount++;
                } else {
                    response.failureCount++;
                    rr.message = 'Failed';
                    List<Database.Error> errors = res.getErrors();
                    rr.error = !errors.isEmpty() ? errors[0].getMessage() : 'Unknown error';
                }
                
                response.results.add(rr);
            }

            response.success = response.failureCount == 0;
            response.statusCode = response.success ? 'SUCCESS' : 'PARTIAL_SUCCESS';
            response.message = 'Processed: ' + response.successCount + ' success, ' + response.failureCount + ' failed';
            RestContext.response.statusCode = response.success ? 200 : 207;

        } catch (Exception e) {
            response.success = false;
            response.message = e.getMessage();
            response.statusCode = e instanceof IllegalArgumentException ? 'BAD_REQUEST' : 'ERROR';
            RestContext.response.statusCode = e instanceof IllegalArgumentException ? 400 : 500;
        }

        return response;
    }
}
