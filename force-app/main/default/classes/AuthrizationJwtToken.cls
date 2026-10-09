/**
 * AuthrizationJwtToken
 * 
 * This class demonstrates OAuth 2.0 implementation using JWT (JSON Web Token) 
 * tokens and Salesforce Named Credentials for secure API authentication.
 * 
 * Features:
 * - JWT token generation and signing
 * - OAuth 2.0 token exchange using client credentials flow
 * - Integration with Salesforce Named Credentials
 * - Access token caching and refresh handling
 */
 public with sharing class AuthrizationJwtToken {
    
    // Named Credential API name (configure in Setup > Named Credentials)
    private static final String NAMED_CREDENTIAL_NAME = 'OAuth_JWT_Provider';
    
    // JWT claim constants
    private static final String ALGORITHM = 'HS256';
    private static final String TOKEN_TYPE = 'Bearer';
    private static final Integer TOKEN_EXPIRY_SECONDS = 3600; // 1 hour
    
    // Cache for access tokens to avoid unnecessary API calls
    private static Map<String, TokenResponse> tokenCache = new Map<String, TokenResponse>();
    
    /**
     * TokenResponse - Inner class to represent OAuth 2.0 token response
     */
    public class TokenResponse {
        public String accessToken;
        public String tokenType;
        public Integer expiresIn;
        public Long expirationTime;
        
        public TokenResponse(String token, String type, Integer expires) {
            this.accessToken = token;
            this.tokenType = type;
            this.expiresIn = expires;
            this.expirationTime = System.currentTimeMillis() + (expires * 1000);
        }
        
        public Boolean isExpired() {
            return System.currentTimeMillis() >= this.expirationTime;
        }
    }
    
    /**
     * JwtClaim - Inner class to represent JWT claim set
     */
    public class JwtClaim {
        public String iss; // Issuer
        public String sub; // Subject
        public String aud; // Audience
        public Long iat; // Issued at
        public Long exp; // Expiration time
        public String clientId;
        public String clientSecret;
        
        public JwtClaim(String issuer, String subject, String audience, String clientId, String clientSecret) {
            this.iss = issuer;
            this.sub = subject;
            this.aud = audience;
            this.clientId = clientId;
            this.clientSecret = clientSecret;
            this.iat = System.currentTimeMillis() / 1000;
            this.exp = this.iat + TOKEN_EXPIRY_SECONDS;
        }
    }
    
    /**
     * generateJwtToken - Generates a signed JWT token
     * 
     * @param issuer - The issuer identifier
     * @param subject - The subject identifier
     * @param audience - The audience (typically the token endpoint URL)
     * @param clientId - OAuth 2.0 client ID
     * @param clientSecret - OAuth 2.0 client secret
     * @return String - Signed JWT token
     */
    public static String generateJwtToken(String issuer, String subject, String audience, String clientId, String clientSecret) {
        try {
            JwtClaim claims = new JwtClaim(issuer, subject, audience, clientId, clientSecret);
            String claimsJson = JSON.serialize(claims);
            
            // Create JWT header
            String headerJson = JSON.serialize(new Map<String, String>{
                'alg' => ALGORITHM,
                'typ' => 'JWT'
            });
            
            // Encode header and claims to Base64
            String header = base64UrlEncode(Blob.valueOf(headerJson));
            String payload = base64UrlEncode(Blob.valueOf(claimsJson));
            String signatureInput = header + '.' + payload;
            
            // Create signature using HMAC-SHA256
            Blob signature = Crypto.generateMac('HmacSHA256', 
                Blob.valueOf(signatureInput), 
                Blob.valueOf(clientSecret));
            String encodedSignature = base64UrlEncode(signature);
            
            // Return complete JWT token
            return signatureInput + '.' + encodedSignature;
        } catch (Exception e) {
            System.debug('Error generating JWT token: ' + e.getMessage());
            throw new AuthenticationException('Failed to generate JWT token: ' + e.getMessage());
        }
    }
    
    /**
     * getAccessToken - Retrieves an access token using OAuth 2.0 client credentials flow
     * Implements caching to avoid unnecessary token generation
     * 
     * @param tokenEndpoint - The OAuth 2.0 token endpoint URL
     * @param clientId - OAuth 2.0 client ID
     * @param clientSecret - OAuth 2.0 client secret
     * @return String - Access token
     */
    public static String getAccessToken(String tokenEndpoint, String clientId, String clientSecret) {
        try {
            // Create cache key
            String cacheKey = clientId + '_' + tokenEndpoint;
            
            // Check if valid token exists in cache
            if (tokenCache.containsKey(cacheKey)) {
                TokenResponse cachedToken = tokenCache.get(cacheKey);
                if (!cachedToken.isExpired()) {
                    System.debug('Using cached access token');
                    return cachedToken.accessToken;
                }
            }
            
            // Generate JWT token
            String jwtToken = generateJwtToken(
                clientId,
                clientId,
                tokenEndpoint,
                clientId,
                clientSecret
            );
            
            // Make HTTP request to token endpoint
            HttpRequest request = new HttpRequest();
            request.setEndpoint(tokenEndpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setHeader('Accept', 'application/json');
            
            // Build request body for client credentials grant
            String body = 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' +
                         '&assertion=' + EncodingUtil.urlEncode(jwtToken, 'UTF-8');
            request.setBody(body);
            
            // Execute HTTP request
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            // Parse response
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                String accessToken = (String) responseMap.get('access_token');
                Integer expiresIn = (Integer) responseMap.get('expires_in');
                String tokenType = (String) responseMap.get('token_type');
                
                // Cache the token
                TokenResponse tokenResponse = new TokenResponse(accessToken, tokenType, expiresIn);
                tokenCache.put(cacheKey, tokenResponse);
                
                System.debug('Successfully obtained access token');
                return accessToken;
            } else {
                System.debug('Token endpoint returned error: ' + response.getStatusCode() + ' - ' + response.getBody());
                throw new AuthenticationException('Failed to obtain access token. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Error getting access token: ' + e.getMessage());
            throw new AuthenticationException('Failed to get access token: ' + e.getMessage());
        }
    }
    
    /**
     * getAccessTokenViaNamedCredential - Retrieves access token using Named Credential
     * This method leverages Salesforce Named Credentials for secure credential storage
     * 
     * @param namedCredentialName - The Name Credential API name
     * @return String - Access token
     */
    public static String getAccessTokenViaNamedCredential(String namedCredentialName) {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:' + namedCredentialName + '/token');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String body = 'grant_type=client_credentials';
            request.setBody(body);
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String accessToken = (String) responseMap.get('access_token');
                
                System.debug('Successfully obtained access token via Named Credential');
                return accessToken;
            } else {
                throw new AuthenticationException('Failed to obtain token via Named Credential. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Error getting access token via Named Credential: ' + e.getMessage());
            throw new AuthenticationException('Failed to get access token: ' + e.getMessage());
        }
    }
    
    /**
     * makeAuthenticatedRequest - Makes an HTTP request with OAuth 2.0 Bearer token authorization
     * 
     * @param endpoint - The API endpoint URL
     * @param method - HTTP method (GET, POST, PUT, DELETE, etc.)
     * @param accessToken - The access token
     * @param body - Request body (optional)
     * @return HttpResponse - The HTTP response
     */
    public static HttpResponse makeAuthenticatedRequest(String endpoint, String method, String accessToken, String body) {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod(method);
            request.setHeader('Authorization', TOKEN_TYPE + ' ' + accessToken);
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');
            
            if (body != null && !body.isEmpty()) {
                request.setBody(body);
            }
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            System.debug('Request completed with status: ' + response.getStatusCode());
            return response;
        } catch (Exception e) {
            System.debug('Error making authenticated request: ' + e.getMessage());
            throw new AuthenticationException('Failed to make authenticated request: ' + e.getMessage());
        }
    }
    
    /**
     * clearTokenCache - Clears the token cache to force new token generation
     */
    public static void clearTokenCache() {
        tokenCache.clear();
        System.debug('Token cache cleared');
    }
    
    /**
     * base64UrlEncode - Encodes a Blob to Base64 URL-safe format
     * 
     * @param input - Blob to encode
     * @return String - Base64 URL-safe encoded string
     */
    private static String base64UrlEncode(Blob input) {
        String encoded = EncodingUtil.base64Encode(input);
        encoded = encoded.replace('+', '-');
        encoded = encoded.replace('/', '_');
        encoded = encoded.replaceAll('=+$', '');
        return encoded;
    }
    
    /**
     * Custom exception for authentication errors
     */
    public class AuthenticationException extends Exception {}
}