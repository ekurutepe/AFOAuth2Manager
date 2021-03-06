// AFOAuth2SessionManager.m
//
// Copyright (c) 2012-2015 AFNetworking (http://afnetworking.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFOAuth2SessionManager.h"
#import "AFOAuth2Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFOAuth2SessionManager ()
@property (readwrite, nonatomic, copy) NSString *serviceProviderIdentifier;
@property (readwrite, nonatomic, copy) NSString *clientID;
@property (readwrite, nonatomic, copy) NSString *secret;
@end

@implementation AFOAuth2SessionManager

+ (nullable instancetype)clientWithBaseURL:(NSURL *)url
                         clientID:(NSString *)clientID
                           secret:(NSString *)secret
{
    return [[self alloc] initWithBaseURL:url clientID:clientID secret:secret sessionConfiguration:nil];
}

+ (nullable instancetype)clientWithBaseURL:(NSURL *)url
                         clientID:(NSString *)clientID
                           secret:(NSString *)secret
             sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration
{
    return [[self alloc] initWithBaseURL:url clientID:clientID secret:secret sessionConfiguration:configuration];
}

- (nullable instancetype)initWithBaseURL:(NSURL *)url
                       clientID:(NSString *)clientID
                         secret:(NSString *)secret
{
    return [self initWithBaseURL:url clientID:clientID secret:secret sessionConfiguration:nil];
}

- (nullable instancetype)initWithBaseURL:(NSURL *)url
                       clientID:(NSString *)clientID
                         secret:(NSString *)secret
           sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration
{
    NSParameterAssert(clientID);

    self = [super initWithBaseURL:url sessionConfiguration:configuration];
    if (!self) {
        return nil;
    }

    self.serviceProviderIdentifier = [self.baseURL host];
    self.clientID = clientID;
    self.secret = secret;

    self.useHTTPBasicAuthentication = YES;

    [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    return self;
}

#pragma mark -

- (void)setUseHTTPBasicAuthentication:(BOOL)useHTTPBasicAuthentication {
    _useHTTPBasicAuthentication = useHTTPBasicAuthentication;

    if (self.useHTTPBasicAuthentication) {
        [self.requestSerializer setAuthorizationHeaderFieldWithUsername:self.clientID password:self.secret];
    } else {
        [self.requestSerializer setValue:nil forHTTPHeaderField:@"Authorization"];
    }
}

- (void)setSecret:(NSString *)secret {
    if (!secret) {
        secret = @"";
    }

    _secret = secret;
}

#pragma mark -

- (NSURLSessionDataTask *)authenticateUsingOAuthWithURLString:(NSString *)URLString
                                                     username:(NSString *)username
                                                     password:(NSString *)password
                                                        scope:(NSString *)scope
                                                      success:(nullable void (^)(AFOAuthCredential *credential))success
                                                      failure:(nullable void (^)(NSError *error))failure
{
    NSParameterAssert(username);
    NSParameterAssert(password);
    NSParameterAssert(scope);

    NSDictionary *parameters = @{
                                 @"grant_type": kAFOAuthPasswordCredentialsGrantType,
                                 @"username": username,
                                 @"password": password,
                                 @"scope": scope
                                };

    return [self authenticateUsingOAuthWithURLString:URLString parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)authenticateUsingOAuthWithURLString:(NSString *)URLString
                                                        scope:(NSString *)scope
                                                      success:(nullable void (^)(AFOAuthCredential *credential))success
                                                      failure:(nullable void (^)(NSError *error))failure
{
    NSParameterAssert(scope);

    NSDictionary *parameters = @{
                                 @"grant_type": kAFOAuthClientCredentialsGrantType,
                                 @"scope": scope
                                };

    return [self authenticateUsingOAuthWithURLString:URLString parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)authenticateUsingOAuthWithURLString:(NSString *)URLString
                                                 refreshToken:(NSString *)refreshToken
                                                      success:(nullable void (^)(AFOAuthCredential *credential))success
                                                      failure:(nullable void (^)(NSError *error))failure
{
    NSParameterAssert(refreshToken);

    NSDictionary *parameters = @{
                                 @"grant_type": kAFOAuthRefreshGrantType,
                                 @"refresh_token": refreshToken
                                };

    return [self authenticateUsingOAuthWithURLString:URLString parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)authenticateUsingOAuthWithURLString:(NSString *)URLString
                                                         code:(NSString *)code
                                                  redirectURI:(NSString *)uri
                                                      success:(nullable void (^)(AFOAuthCredential *credential))success
                                                      failure:(nullable void (^)(NSError *error))failure
{
    NSParameterAssert(code);
    NSParameterAssert(uri);

    NSDictionary *parameters = @{
                                 @"grant_type": kAFOAuthCodeGrantType,
                                 @"code": code,
                                 @"redirect_uri": uri
                                };

    return [self authenticateUsingOAuthWithURLString:URLString parameters:parameters success:success failure:failure];
}

- (nullable NSURLSessionDataTask *)authenticateUsingOAuthWithURLString:(NSString *)URLString
                                                   parameters:(NSDictionary *)parameters
                                                      success:(nullable void (^)(AFOAuthCredential *credential))success
                                                      failure:(nullable void (^)(NSError * _Nullable error))failure
{
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    if (!self.useHTTPBasicAuthentication) {
        mutableParameters[@"client_id"] = self.clientID;
        mutableParameters[@"client_secret"] = self.secret;
    }
    parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    NSError *requestSerializationError;
    
    NSURL *url = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
        
    NSURLRequest *request = [self.requestSerializer requestWithMethod:@"POST" URLString:url.absoluteString parameters:parameters error:&requestSerializationError];
    
    if (requestSerializationError != nil) {
        if (failure != nil) {
            failure(requestSerializationError);
        }
        return nil;
    }
    
    NSURLSessionDataTask *task = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id _Nullable responseObject, NSError * _Nullable error) {
        if (error != nil) {
            if (failure != nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
                failure(error);
#pragma clang diagnostic pop
            }
            return;
        }
        if (!responseObject) {
            if (failure != nil) {
                failure(nil);
            }
            
            return;
        }
        
        if ([responseObject valueForKey:@"error"]) {
            if (failure != nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
                failure(AFErrorFromRFC6749Section5_2Error(responseObject));
#pragma clang diagnostic pop
            }    
           return;
        }
        
        NSString *refreshToken = [responseObject valueForKey:@"refresh_token"];
        if (!refreshToken || [refreshToken isEqual:[NSNull null]]) {
            refreshToken = [parameters valueForKey:@"refresh_token"];
        }
        
        AFOAuthCredential *credential = [AFOAuthCredential credentialWithOAuthToken:[responseObject valueForKey:@"access_token"] tokenType:[responseObject valueForKey:@"token_type"]];
        
        if (refreshToken) { // refreshToken is optional in the OAuth2 spec
            [credential setRefreshToken:refreshToken];
        }
        
        // Expiration is optional, but recommended in the OAuth2 spec. It not provide, assume distantFuture === never expires
        NSDate *expireDate = [NSDate distantFuture];
        id expiresIn = [responseObject valueForKey:@"expires_in"];
        if (expiresIn && ![expiresIn isEqual:[NSNull null]]) {
            expireDate = [NSDate dateWithTimeIntervalSinceNow:[expiresIn doubleValue]];
        }
        
        if (expireDate) {
            [credential setExpiration:expireDate];
        }
        
        if (success != nil) {
            success(credential);
        }
    }];
    
    [task resume];

    return task;
}

@end

NS_ASSUME_NONNULL_END
