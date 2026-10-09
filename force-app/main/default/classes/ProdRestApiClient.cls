public with sharing class ProdRestApiClient {
    public static final String DEFAULT_API_VERSION = 'v66.0';

    public class ApiException extends Exception {
    }

    /**
     * Queries production org via REST API and returns parsed records
     * @param namedCredential Named Credential configured for Prod org
     * @param soql SOQL query to execute
     * @param apiVersion Salesforce API version (e.g., 'v66.0')
     * @return List of record maps with field data
     */
    public static List<Map<String, Object>> queryProduction(
        String namedCredential,
        String soql,
        String apiVersion
    ) {
        validateInput(namedCredential, 'Named Credential');
        validateInput(soql, 'SOQL');

        HttpRequest request = buildHttpRequest(namedCredential, soql, apiVersion);
        HttpResponse response = executeRequest(request);
        
        return parseQueryResponse(response);
    }

    /**
     * Overloaded method using default API version
     */
    public static List<Map<String, Object>> queryProduction(String namedCredential, String soql) {
        return queryProduction(namedCredential, soql, DEFAULT_API_VERSION);
    }

    /**
     * Builds the HTTP request for Salesforce query endpoint
     */
    @TestVisible
    private static HttpRequest buildHttpRequest(String namedCredential, String soql, String apiVersion) {
        HttpRequest request = new HttpRequest();
        String encodedCredential = EncodingUtil.urlEncode(namedCredential, 'UTF-8');
        String encodedSoql = EncodingUtil.urlEncode(soql, 'UTF-8');
        
        request.setEndpoint(
            'callout:' + encodedCredential + '/services/data/' + apiVersion + '/query?q=' + encodedSoql
        );
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        
        return request;
    }

    /**
     * Executes the HTTP request and handles response
     */
    @TestVisible
    private static HttpResponse executeRequest(HttpRequest request) {
        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();
        
        if (statusCode < 200 || statusCode > 299) {
            throw new ApiException(
                'Production query failed. Status ' + statusCode + ': ' + response.getBody()
            );
        }
        
        return response;
    }

    /**
     * Parses the JSON response and extracts records
     */
    @TestVisible
    private static List<Map<String, Object>> parseQueryResponse(HttpResponse response) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> rawRecords = (List<Object>) payload.get('records');
        List<Map<String, Object>> records = new List<Map<String, Object>>();

        if (rawRecords == null) {
            return records;
        }

        for (Object rawRecord : rawRecords) {
            Map<String, Object> record = (Map<String, Object>) rawRecord;
            record.remove('attributes'); // Remove Salesforce metadata
            records.add(record);
        }

        return records;
    }

    /**
     * Validates input parameters
     */
    private static void validateInput(String value, String parameterName) {
        if (String.isBlank(value)) {
            throw new ApiException(parameterName + ' is required.');
        }
    }
}
