//
//  XMPPConnectivityErrorTypeTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "NSError+ConnectivityErrorType.h"
#import "XMPPTestCase.h"

@interface XMPPConnectivityErrorTypeTests : XMPPTestCase

@end

@implementation XMPPConnectivityErrorTypeTests

- (void)testDefault
{
    NSError *error = [NSError errorWithDomain:@"XMPPConnectivityErrorTypeTests"
                                         code:42
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeTemporal);
}

#pragma mark NSPOSIXErrorDomain

- (void)testSocketError
{
    // this error code indicates, that the socket has been interupted for example due to the background mode. In this case, the client can reconnect directly.

    NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:57 // Socket is not connected
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNone);
}

#pragma mark NSURLErrorDomain

- (void)testNSURLErrorNotConnectedToInternet
{
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorNotConnectedToInternet
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNetworkReachability);
}

- (void)testNSURLErrorDNSLookupFailed
{
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorDNSLookupFailed
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNetworkReachability);
}

- (void)testNSURLErrorCannotFindHost
{
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorCannotFindHost
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNetworkReachability);
}

#pragma mark kCFErrorDomainCFNetwork

- (void)testkCFURLErrorNotConnectedToInternet
{
    NSError *error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorNotConnectedToInternet
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNetworkReachability);
}

- (void)testkCFURLErrorDNSLookupFailed
{
    NSError *error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorDNSLookupFailed
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNetworkReachability);
}

- (void)testkCFURLErrorCannotFindHost
{
    NSError *error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorCannotFindHost
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypeNetworkReachability);
}

#pragma mark XMPPStreamFeatureSASLErrorDomain

- (void)testStreamFeatureSASLErrorCodeNotAuthorized
{
    NSError *error = [NSError errorWithDomain:XMPPStreamFeatureSASLErrorDomain
                                         code:XMPPStreamFeatureSASLErrorCodeNotAuthorized
                                     userInfo:nil];
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];
    XCTAssertEqual(errorType, XMPPConnectivityErrorTypePermanent);
}

@end
