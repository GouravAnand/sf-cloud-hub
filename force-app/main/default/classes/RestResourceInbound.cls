/**
 * RestResourceInbound
 * 
 * REST API resource class for handling inbound POST requests
 * Provides functionality to upsert custom objects via HTTP POST
 * 
 * Usage:
 * POST /services/apexrest/inbound/upsert
 * 
 * Request Body Example:
 * {
 *   "objectType": "CustomObject__c",
 *   "externalIdField": "ExternalId__c",
 *   "records": [
 *     {
 *       "ExternalId__c": "EXT-001",
 *       "Name": "Test Record",
 *       "Status__c": "Active"
 *     }
 *   ]
 * }
 * 
 * Response Example:
 * {
 *   "success": true,
 *   "message": "Successfully processed 1 record(s)",
 *   "totalRecords": 1,
 *   "successCount": 1,
 *   "failureCount": 0,
 *   "results": [
 *     {
 *       "id": "a03xx000003SLAAA2",
 *       "success": true,
 *       "externalId": "EXT-001"
 *     }
 *   ]
 * }
 */
@RestResource(urlMapping='/inbound/upsert')
global class RestResourceInbound {

    /**
     * Wrapper class for inbound request payload
     */
    public class UpsertRequest {
        public String objectType { get; set; }
        public String externalIdField { get; set; }
        public List<Map<String, Object>> records { get; set; }
    }

    /**
     * Wrapper class for individual record result
     */
    public class RecordResult {
        @AuraEnabled
        public String id { get; set; }
        
        @AuraEnabled
        public Boolean success { get; set; }
        
        @AuraEnabled
        public String message { get; set; }
        
        @AuraEnabled
        public String externalId { get; set; }
        
        @AuraEnabled
        public String error { get; set; }
        
        public RecordResult(String id, Boolean success, String message) {
            this.id = id;
            this.success = success;
            this.message = message;
        }
    }

    /**
     * Wrapper class for API response
     */
    public class ApiResponse {
        @AuraEnabled
        public Boolean success { get; set; }
        
        @AuraEnabled
        public String message { get; set; }
        
        @AuraEnabled
        public Integer totalRecords { get; set; }
        
        @AuraEnabled
        public Integer successCount { get; set; }
        
        @AuraEnabled
        public Integer failureCount { get; set; }
        
        @AuraEnabled
        public List<RecordResult> results { get; set; }
        
        @AuraEnabled
        public String statusCode { get; set; }
        
        public ApiResponse() {
            this.results = new List<RecordResult>();
            this.successCount = 0;
            this.failureCount = 0;
        }
    }

    /**
     * POST method for upserting records
     * 
     * @return ApiResponse containing upsert results
     */
    @HttpPost
    global static ApiResponse doPost() {
        ApiResponse response = new ApiResponse();
        
        try {
            // Parse request body
            UpsertRequest request = parseRequest();
            
            // Validate request
            validateRequest(request);
            
            // Perform upsert operation
            response = performUpsert(request);
            
        } catch (RequestValidationException e) {
            response.success = false;
            response.message = e.getMessage();
            response.statusCode = 'BAD_REQUEST';
            RestContext.response.statusCode = 400;
            
        } catch (InvalidObjectException e) {
            response.success = false;
            response.message = e.getMessage();
            response.statusCode = 'INVALID_OBJECT';
            RestContext.response.statusCode = 400;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'An unexpected error occurred: ' + e.getMessage();
            response.statusCode = 'INTERNAL_ERROR';
            RestContext.response.statusCode = 500;
        }
        
        return response;
    }

    /**
     * Parses the incoming request body into UpsertRequest object
     * 
     * @return Parsed UpsertRequest
     * @throws Exception if request body is invalid JSON
     */
    private static UpsertRequest parseRequest() {
        String requestBody = RestContext.request.requestBody.toString();
        
        if (String.isEmpty(requestBody)) {
            throw new RequestValidationException('Request body cannot be empty');
        }
        
        try {
            UpsertRequest request = (UpsertRequest) JSON.deserialize(
                requestBody,
                UpsertRequest.class
            );
            return request;
        } catch (Exception e) {
            throw new RequestValidationException('Invalid JSON format: ' + e.getMessage());
        }
    }

    /**
     * Validates the incoming request
     * 
     * @param request The UpsertRequest to validate
     * @throws RequestValidationException if validation fails
     */
    private static void validateRequest(UpsertRequest request) {
        // Validate objectType
        if (String.isEmpty(request.objectType)) {
            throw new RequestValidationException('objectType is required');
        }
        
        if (!isValidSObjectType(request.objectType)) {
            throw new InvalidObjectException('Invalid object type: ' + request.objectType);
        }
        
        // Validate externalIdField
        if (String.isEmpty(request.externalIdField)) {
            throw new RequestValidationException('externalIdField is required');
        }
        
        if (!fieldExistsOnObject(request.objectType, request.externalIdField)) {
            throw new InvalidObjectException(
                'Field ' + request.externalIdField + ' does not exist on ' + request.objectType
            );
        }
        
        // Validate records
        if (request.records == null || request.records.isEmpty()) {
            throw new RequestValidationException('records list cannot be empty');
        }
        
        if (request.records.size() > 200) {
            throw new RequestValidationException('Maximum 200 records allowed per request');
        }
    }

    /**
     * Performs the upsert operation
     * 
     * @param request The UpsertRequest containing records to upsert
     * @return ApiResponse with upsert results
     */
    private static ApiResponse performUpsert(UpsertRequest request) {
        ApiResponse response = new ApiResponse();
        response.totalRecords = request.records.size();
        
        try {
            // Get the SObject type
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe()
                .get(request.objectType);
            
            // Build SObject list from maps
            List<SObject> sObjectList = new List<SObject>();
            
            for (Map<String, Object> recordMap : request.records) {
                SObject record = sObjectType.newSObject();
                
                // Set field values from map
                for (String field : recordMap.keySet()) {
                    try {
                        record.put(field, recordMap.get(field));
                    } catch (Exception e) {
                        throw new FieldAssignmentException(
                            'Error assigning field ' + field + ': ' + e.getMessage()
                        );
                    }
                }
                
                sObjectList.add(record);
            }
            
            // Get the external ID field token
            Schema.SObjectField externalIdField = sObjectType.getDescribe()
                .fields.getMap()
                .get(request.externalIdField.toLowerCase());
            
            if (externalIdField == null) {
                throw new InvalidObjectException(
                    'External ID field ' + request.externalIdField + 
                    ' not found on ' + request.objectType
                );
            }
            
            // Perform upsert
            Database.UpsertResult[] upsertResults = Database.upsert(
                sObjectList,
                externalIdField,
                false
            );
            
            // Process results
            for (Integer i = 0; i < upsertResults.size(); i++) {
                Database.UpsertResult result = upsertResults[i];
                RecordResult recordResult = new RecordResult(
                    result.getId(),
                    result.isSuccess(),
                    result.isSuccess() ? 'Record upserted successfully' : 'Record upsert failed'
                );
                
                // Set external ID from original request
                Object externalIdValue = request.records[i].get(request.externalIdField);
                recordResult.externalId = String.valueOf(externalIdValue);
                
                if (!result.isSuccess()) {
                    response.failureCount++;
                    List<Database.Error> errors = result.getErrors();
                    if (!errors.isEmpty()) {
                        recordResult.error = errors[0].getMessage();
                    }
                } else {
                    response.successCount++;
                }
                
                response.results.add(recordResult);
            }
            
            // Set response metadata
            response.success = response.failureCount == 0;
            response.statusCode = response.success ? 'SUCCESS' : 'PARTIAL_SUCCESS';
            response.message = 'Successfully processed ' + response.successCount + 
                             ' record(s). Failed: ' + response.failureCount;
            
            // Set HTTP status code
            RestContext.response.statusCode = response.success ? 200 : 207;
            
        } catch (Exception e) {
            response.success = false;
            response.statusCode = 'UPSERT_ERROR';
            response.message = 'Upsert operation failed: ' + e.getMessage();
            RestContext.response.statusCode = 500;
        }
        
        return response;
    }

    /**
     * Validates if an SObject type exists
     * 
     * @param sObjectType The SObject API name
     * @return Boolean indicating if SObject type is valid
     */
    private static Boolean isValidSObjectType(String sObjectType) {
        try {
            Schema.getGlobalDescribe().get(sObjectType).getDescribe();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Validates if a field exists on an SObject
     * 
     * @param sObjectType The SObject API name
     * @param fieldName The field API name
     * @return Boolean indicating if field exists
     */
    private static Boolean fieldExistsOnObject(String sObjectType, String fieldName) {
        try {
            Schema.DescribeSObjectResult describe = Schema.getGlobalDescribe()
                .get(sObjectType)
                .getDescribe();
            
            return describe.fields.getMap().containsKey(fieldName.toLowerCase());
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Custom exception for request validation errors
     */
    public class RequestValidationException extends Exception {}

    /**
     * Custom exception for invalid object/field errors
     */
    public class InvalidObjectException extends Exception {}

    /**
     * Custom exception for field assignment errors
     */
    public class FieldAssignmentException extends Exception {}
}
