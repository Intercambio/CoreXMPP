//
//  XMPPConnectivityErrorTypeTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
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
