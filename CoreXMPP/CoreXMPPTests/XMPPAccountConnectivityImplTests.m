//
//  XMPPAccountConnectivityImplTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPAccountConnectivityImpl.h"
#import "XMPPReconnectStrategy.h"
#import "XMPPTestCase.h"

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
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateDisconnected);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateConnecting];
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateConnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateEstablished];
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateConnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateNegotiating];
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateConnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateConnected];
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateConnected);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateDisconnecting];
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateDisconnecting);

    [self.accountConnectivity client:self.client didChangeState:XMPPClientStateDisconnected];
    XCTAssertEqual(self.accountConnectivity.state, XMPPAccountConnectivityStateDisconnected);
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

    [verify(self.strategy) start];
}

- (void)testClearAfterReconnect
{
    NSError *error = [NSError errorWithDomain:@"XMPPAccountConnectivityImplTests" code:42 userInfo:nil];

    [self.accountConnectivity client:self.client didFailWithError:error];
    XCTAssertEqualObjects(self.accountConnectivity.recentError, error);

    [self.accountConnectivity clientDidConnect:self.client resumedStream:NO];
    XCTAssertNil(self.accountConnectivity.recentError);

    [verify(self.strategy) stop];
}

@end
