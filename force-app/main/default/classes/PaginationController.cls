/**
 * PaginationController
 * 
 * Provides pagination and lazy loading functionality for LWC components
 * Implements two approaches:
 * 1. Traditional pagination using page number, limit, and offset
 * 2. Lazy loading through scrolling with cursor-based approach
 */
public class PaginationController {

    /**
     * Wrapper class to return paginated results
     */
    public class PaginationResult {
        @AuraEnabled
        public List<SObject> records { get; set; }
        
        @AuraEnabled
        public Integer pageNumber { get; set; }
        
        @AuraEnabled
        public Integer totalRecords { get; set; }
        
        @AuraEnabled
        public Integer totalPages { get; set; }
        
        @AuraEnabled
        public Boolean hasNextPage { get; set; }
        
        @AuraEnabled
        public Boolean hasPreviousPage { get; set; }
        
        public PaginationResult() {
            this.records = new List<SObject>();
            this.pageNumber = 1;
            this.totalRecords = 0;
            this.totalPages = 0;
            this.hasNextPage = false;
            this.hasPreviousPage = false;
        }
    }

    /**
     * Wrapper class for lazy loading results
     */
    public class LazyLoadResult {
        @AuraEnabled
        public List<SObject> records { get; set; }
        
        @AuraEnabled
        public String cursor { get; set; }
        
        @AuraEnabled
        public Boolean hasMore { get; set; }
        
        @AuraEnabled
        public Integer totalRecords { get; set; }
        
        public LazyLoadResult() {
            this.records = new List<SObject>();
            this.cursor = '';
            this.hasMore = false;
            this.totalRecords = 0;
        }
    }

    /**
     * METHOD 1: Traditional Pagination
     * 
     * Fetches records using page number and limit (offset calculated internally)
     * 
     * @param sObjectType The SObject API name (e.g., 'Account', 'Contact')
     * @param pageNumber The page number to fetch (1-based)
     * @param pageSize The number of records per page
     * @param filters Optional WHERE clause filters
     * @param sortField Optional field name for sorting
     * @param sortOrder Optional sort order (ASC or DESC)
     * @return PaginationResult containing records and pagination metadata
     */
    @AuraEnabled(cacheable=false)
    public static PaginationResult getPaginatedRecords(
        String sObjectType,
        Integer pageNumber,
        Integer pageSize,
        String filters,
        String sortField,
        String sortOrder
    ) {
        PaginationResult result = new PaginationResult();
        
        try {
            // Validate inputs
            if (pageNumber < 1) pageNumber = 1;
            if (pageSize < 1 || pageSize > 50000) pageSize = 100;
            
            sortField = String.isEmpty(sortField) ? 'Id' : sortField;
            sortOrder = String.isEmpty(sortOrder) ? 'ASC' : sortOrder.toUpperCase();
            filters = String.isEmpty(filters) ? '' : 'WHERE ' + filters;
            
            // Build and execute count query
            String countQuery = 'SELECT COUNT() FROM ' + sObjectType + ' ' + filters;
            result.totalRecords = Database.countQuery(countQuery);
            
            // Calculate pagination metadata
            result.totalPages = (result.totalRecords + pageSize - 1) / pageSize;
            result.pageNumber = Math.min(pageNumber, result.totalPages > 0 ? result.totalPages : 1);
            result.hasNextPage = result.pageNumber < result.totalPages;
            result.hasPreviousPage = result.pageNumber > 1;
            
            // Calculate offset
            Integer offset = (result.pageNumber - 1) * pageSize;
            
            // Build and execute records query
            String query = 'SELECT Id FROM ' + sObjectType + ' ' + filters + 
                          ' ORDER BY ' + sortField + ' ' + sortOrder +
                          ' LIMIT :pageSize OFFSET :offset';
            
            result.records = Database.query(query);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching paginated records: ' + e.getMessage());
        }
        
        return result;
    }

    /**
     * METHOD 2: Lazy Loading with Scrolling
     * 
     * Fetches the first batch of records for lazy loading
     * Uses a cursor-based approach for efficient scrolling
     * 
     * @param sObjectType The SObject API name (e.g., 'Account', 'Contact')
     * @param batchSize The number of records to fetch per scroll
     * @param filters Optional WHERE clause filters
     * @param sortField Optional field name for sorting
     * @param sortOrder Optional sort order (ASC or DESC)
     * @return LazyLoadResult containing initial records and cursor for next fetch
     */
    @AuraEnabled(cacheable=false)
    public static LazyLoadResult getInitialLazyLoadRecords(
        String sObjectType,
        Integer batchSize,
        String filters,
        String sortField,
        String sortOrder
    ) {
        LazyLoadResult result = new LazyLoadResult();
        
        try {
            // Validate inputs
            if (batchSize < 1 || batchSize > 50000) batchSize = 100;
            
            sortField = String.isEmpty(sortField) ? 'Id' : sortField;
            sortOrder = String.isEmpty(sortOrder) ? 'ASC' : sortOrder.toUpperCase();
            filters = String.isEmpty(filters) ? '' : 'WHERE ' + filters;
            
            // Get total count
            String countQuery = 'SELECT COUNT() FROM ' + sObjectType + ' ' + filters;
            result.totalRecords = Database.countQuery(countQuery);
            
            // Build and execute query
            String query = 'SELECT Id FROM ' + sObjectType + ' ' + filters +
                          ' ORDER BY ' + sortField + ' ' + sortOrder +
                          ' LIMIT :batchSize';
            
            result.records = Database.query(query);
            
            // Set cursor (last record's Id) for next batch
            if (!result.records.isEmpty()) {
                SObject lastRecord = result.records[result.records.size() - 1];
                result.cursor = (String) lastRecord.get('Id');
                result.hasMore = result.records.size() >= batchSize && 
                                result.records.size() < result.totalRecords;
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching initial lazy load records: ' + e.getMessage());
        }
        
        return result;
    }

    /**
     * METHOD 2B: Lazy Loading - Load Next Batch
     * 
     * Fetches the next batch of records based on cursor position
     * Called when user scrolls to load more records
     * 
     * @param sObjectType The SObject API name (e.g., 'Account', 'Contact')
     * @param cursor The Id of the last record from the previous batch
     * @param batchSize The number of records to fetch per scroll
     * @param filters Optional WHERE clause filters
     * @param sortField Optional field name for sorting
     * @param sortOrder Optional sort order (ASC or DESC)
     * @return LazyLoadResult containing next batch of records and new cursor
     */
    @AuraEnabled(cacheable=false)
    public static LazyLoadResult getNextLazyLoadBatch(
        String sObjectType,
        String cursor,
        Integer batchSize,
        String filters,
        String sortField,
        String sortOrder
    ) {
        LazyLoadResult result = new LazyLoadResult();
        
        try {
            // Validate inputs
            if (String.isEmpty(cursor)) {
                throw new AuraHandledException('Cursor is required for lazy loading');
            }
            if (batchSize < 1 || batchSize > 50000) batchSize = 100;
            
            sortField = String.isEmpty(sortField) ? 'Id' : sortField;
            sortOrder = String.isEmpty(sortOrder) ? 'ASC' : sortOrder.toUpperCase();
            filters = String.isEmpty(filters) ? '' : 'WHERE ' + filters;
            
            // Get total count
            String countQuery = 'SELECT COUNT() FROM ' + sObjectType + ' ' + filters;
            result.totalRecords = Database.countQuery(countQuery);
            
            // Build query to get records AFTER the cursor
            String query = 'SELECT Id FROM ' + sObjectType + ' ' + filters +
                          ' AND Id > :cursor ' +
                          ' ORDER BY ' + sortField + ' ' + sortOrder +
                          ' LIMIT :batchSize';
            
            result.records = Database.query(query);
            
            // Update cursor for next batch
            if (!result.records.isEmpty()) {
                SObject lastRecord = result.records[result.records.size() - 1];
                result.cursor = (String) lastRecord.get('Id');
                result.hasMore = result.records.size() >= batchSize;
            } else {
                result.hasMore = false;
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching lazy load batch: ' + e.getMessage());
        }
        
        return result;
    }

    /**
     * Helper method to build complex SOQL WHERE clause
     * 
     * @param fieldFilters Map of field name to filter value
     * @return Constructed WHERE clause
     */
    public static String buildWhereClause(Map<String, String> fieldFilters) {
        if (fieldFilters == null || fieldFilters.isEmpty()) {
            return '';
        }
        
        List<String> conditions = new List<String>();
        for (String field : fieldFilters.keySet()) {
            String value = fieldFilters.get(field);
            conditions.add(field + ' = \'' + String.escapeSingleQuotes(value) + '\'');
        }
        
        return String.join(conditions, ' AND ');
    }

    /**
     * Method to safely validate SObject type exists
     * 
     * @param sObjectType The SObject API name
     * @return Boolean indicating if SObject type is valid
     */
    public static Boolean isValidSObjectType(String sObjectType) {
        try {
            Schema.getGlobalDescribe().get(sObjectType).getDescribe();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
