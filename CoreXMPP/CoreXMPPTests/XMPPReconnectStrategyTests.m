//
//  XMPPReconnectStrategyTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 18.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPReconnectStrategy.h"
#import "XMPPTestCase.h"

@interface XMPPReconnectStrategyTests : XMPPTestCase

@end

@implementation XMPPReconnectStrategyTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark Tests

- (void)testAddClient
{
    XMPPReconnectStrategy *strategy = [[XMPPReconnectStrategy alloc] init];

    XMPPClient *client = mock([XMPPClient class]);
    [given([client state]) willReturnUnsignedInteger:XMPPClientStateDisconnected];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Connect Client"];
    [givenVoid([client connect]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];

    [strategy addClient:client];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThat(strategy.clients, contains(client, nil));

    [verifyCount(client, times(1)) connect];
}

- (void)testRemoveClient
{
    XMPPReconnectStrategy *strategy = [[XMPPReconnectStrategy alloc] init];

    XMPPClient *client = mock([XMPPClient class]);
    [given([client state]) willReturnUnsignedInteger:XMPPClientStateConnected];

    [strategy addClient:client];
    assertThat(strategy.clients, contains(client, nil));

    [strategy removeClient:client];
    assertThat(strategy.clients, isNot(contains(client, nil)));
}

- (void)testReconnectImmediately
{
    XMPPReconnectStrategy *strategy = [[XMPPReconnectStrategy alloc] init];
    
    XMPPClient *client = mock([XMPPClient class]);
    [given([client state]) willReturnUnsignedInteger:XMPPClientStateConnected];
    
    [strategy addClient:client];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Connect Client"];
    [givenVoid([client connect]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                        object:client];
    
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    
    assertThatInt([strategy reconnectStrategyForClient:client], equalToInt(XMPPReconnectStrategyNone));
}

- (void)testReconnectAfterTimeout
{
    XMPPReconnectStrategy *strategy = [[XMPPReconnectStrategy alloc] init];
    
    XMPPClient *client = mock([XMPPClient class]);
    [given([client state]) willReturnUnsignedInteger:XMPPClientStateConnected];
    
    [strategy addClient:client];
    
    NSDictionary *userInfo = @{XMPPClientErrorKey: [NSError errorWithDomain:@"XMPPReconnectStrategyTests" code:12 userInfo:nil]};

    [self expectationForNotification:XMPPReconnectStrategyDidChangeClientStateNotification
                              object:strategy
                             handler:^BOOL(NSNotification *notification) {
                                 return notification.userInfo[XMPPReconnectStrategyClientKey] == client;
                             }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                        object:client
                                                      userInfo:userInfo];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatInt([strategy reconnectStrategyForClient:client], equalToInt(XMPPReconnectStrategyTimeout));
    assertThat([strategy nextConnectionAttemptForClient:client], notNilValue());
    assertThat([strategy nextConnectionAttemptForClient:client], greaterThan([NSDate date]));
}

@end
