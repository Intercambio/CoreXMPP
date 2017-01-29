//
//  XMPPAccountConnectivityImplTests.m
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

#import "XMPPTestCase.h"

// Needs to be imported after CoreXMPP framework (via XMPPTestCase) to avoid compiler warnings
#import "XMPPAccountConnectivityImpl.h"

@interface XMPPAccountConnectivityImplTests : XMPPTestCase
@property (nonatomic, strong) XMPPJID *account;
@property (nonatomic, strong) XMPPClient *client;
@property (nonatomic, strong) id<XMPPReconnectStrategy> strategy;
@property (nonatomic, strong) id<XMPPAccountConnectivityImplDelegate> accountConnectivityDelegate;
@property (nonatomic, strong) XMPPAccountConnectivityImpl *accountConnectivity;
@end

@implementation XMPPAccountConnectivityImplTests

- (void)setUp
{
    [super setUp];

    self.account = JID(@"romeo@localhost");
    self.client = mock([XMPPClient class]);
    self.strategy = mockProtocol(@protocol(XMPPReconnectStrategy));
    self.accountConnectivityDelegate = mockProtocol(@protocol(XMPPAccountConnectivityImplDelegate));
    self.accountConnectivity = [[XMPPAccountConnectivityImpl alloc] initWithAccount:self.account
                                                                             client:self.client];
    self.accountConnectivity.delegate = self.accountConnectivityDelegate;

    [[given([self.accountConnectivityDelegate accountConnectivity:equalTo(self.accountConnectivity)
                                       reconnectStrategyForClient:equalTo(self.client)
                                                        withError:anything()
                                                 numberOfAttempts:0]) withMatcher:anything()
                                                                      forArgument:3] willReturn:self.strategy];

    [given([self.strategy nextConnectionAttempt]) willReturn:[NSDate distantFuture]];
}

#pragma mark Tests

- (void)testClientState
{
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateDisconnected);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateConnecting];
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateConnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateEstablished];
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateConnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateNegotiating];
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateConnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateConnected];
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateConnected);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateDisconnecting];
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateDisconnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateDisconnected];
    XCTAssertEqual(self.accountConnectivity.connectionState, XMPPAccountConnectionStateDisconnected);
}

- (void)testConnect
{
    [self.accountConnectivity connect];
    [verifyCount(self.client, times(1)) connect];
}

- (void)testConnectAfterDisconnect
{
    [self.accountConnectivity clientDidDisconnect:self.client];
    [verifyCount(self.client, times(1)) connect];
}

- (void)testStartStrategyAfterError
{
    NSError *error = [NSError errorWithDomain:@"XMPPAccountConnectivityImplTests" code:42 userInfo:nil];

    [self.accountConnectivity client:self.client didFailWithError:error];
    [[verifyCount(self.accountConnectivityDelegate, times(1)) withMatcher:anything() forArgument:3] accountConnectivity:anything()
                                                                                             reconnectStrategyForClient:anything()
                                                                                                              withError:anything()
                                                                                                       numberOfAttempts:0];

    XCTAssertEqualObjects(self.accountConnectivity.recentError, error);
    XCTAssertEqualObjects(self.accountConnectivity.nextConnectionAttempt, [NSDate distantFuture]);

    [(id<XMPPReconnectStrategy>)verify(self.strategy) start];
}

- (void)testClearAfterReconnect
{
    NSError *error = [NSError errorWithDomain:@"XMPPAccountConnectivityImplTests" code:42 userInfo:nil];

    [self.accountConnectivity client:self.client didFailWithError:error];
    XCTAssertEqualObjects(self.accountConnectivity.recentError, error);

    [self.accountConnectivity clientDidConnect:self.client resumedStream:NO];
    XCTAssertNil(self.accountConnectivity.recentError);

    [(id<XMPPReconnectStrategy>)verify(self.strategy) stop];
}

@end
