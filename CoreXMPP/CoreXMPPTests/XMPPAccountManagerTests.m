//
//  XMPPAccountManagerTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPAccountManagerTests : XMPPTestCase
@property (nonatomic, strong) XMPPDispatcherImpl *dispatcher;
@property (nonatomic, strong) id<XMPPClientFactory> clientFactory;
@property (nonatomic, strong) XMPPClient *client;
@property (nonatomic, strong) XMPPAccountManager *accountManager;
@property (nonatomic, strong) id<SASLMechanismDelegate> SASLDelegate;
@end

@implementation XMPPAccountManagerTests

- (void)setUp
{
    [super setUp];
    self.dispatcher = mock([XMPPDispatcherImpl class]);
    self.clientFactory = mockProtocol(@protocol(XMPPClientFactory));
    self.client = mock([XMPPClient class]);
    self.accountManager = [[XMPPAccountManager alloc] initWithDispatcher:self.dispatcher
                                                           clientFactory:self.clientFactory];
    self.SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    self.accountManager.SASLDelegate = self.SASLDelegate;

    [given([self.clientFactory createClientToHost:equalTo(@"localhost")
                                      withOptions:equalTo(@{})
                                           stream:nilValue()]) willReturn:self.client];
}

#pragma mark Tests

- (void)testAddAccount
{
    NSError *error = nil;
    BOOL success = [self.accountManager addAccount:JID(@"romeo@localhost")
                                       withOptions:@{}
                                             error:&error];
    XCTAssertTrue(success, @"Failed to add account: %@", [error localizedDescription]);

    assertThat(self.accountManager.accounts, contains(JID(@"romeo@localhost"), nil));

    [verify(self.clientFactory) createClientToHost:equalTo(@"localhost")
                                       withOptions:equalTo(@{})
                                            stream:nilValue()];

    [verify(self.client) setDelegate:anything()];
    [verify(self.client) setDelegateQueue:is(dispatch_get_main_queue())];

    [verify(self.client) setSASLContext:equalTo(JID(@"romeo@localhost"))];
    [verify(self.client) setSASLDelegate:is(self.SASLDelegate)];
    [verify(self.client) setSASLDelegateQueue:is(dispatch_get_main_queue())];

    [verify(self.dispatcher) setConnection:self.client forJID:JID(@"romeo@localhost")];
    [verify(self.client) setConnectionDelegate:is(self.dispatcher)];
}

- (void)testAddExsitiongAccount
{
    NSError *error = nil;
    BOOL success = [self.accountManager addAccount:JID(@"romeo@localhost")
                                       withOptions:@{}
                                             error:&error];
    XCTAssertTrue(success, @"Failed to add account: %@", [error localizedDescription]);

    success = [self.accountManager addAccount:JID(@"romeo@localhost")
                                  withOptions:@{}
                                        error:&error];
    XCTAssertFalse(success);
    XCTAssertEqualObjects(error.domain, XMPPErrorDomain);
    XCTAssertEqual(error.code, XMPPErrorCodeAccountExists);
}

- (void)testUpdateOptions
{
    NSError *error = nil;
    BOOL success = [self.accountManager addAccount:JID(@"romeo@localhost")
                                       withOptions:@{}
                                             error:&error];
    XCTAssertTrue(success, @"Failed to add account: %@", [error localizedDescription]);

    NSDictionary *options = @{ @"foo" : @(42) };
    [self.accountManager updateAccount:JID(@"romeo@localhost")
                           withOptions:options];

    [verify(self.client) updateOptions:equalTo(options)];
}

- (void)testRemoveAccount
{
    NSError *error = nil;
    BOOL success = [self.accountManager addAccount:JID(@"romeo@localhost")
                                       withOptions:@{}
                                             error:&error];
    XCTAssertTrue(success, @"Failed to add account: %@", [error localizedDescription]);

    [self.accountManager removeAccount:JID(@"romeo@localhost")];

    assertThat(self.accountManager.accounts, isNot(contains(JID(@"romeo@localhost"), nil)));
}

- (void)testConnectivity
{
    NSError *error = nil;
    BOOL success = [self.accountManager addAccount:JID(@"romeo@localhost")
                                       withOptions:@{}
                                             error:&error];
    XCTAssertTrue(success, @"Failed to add account: %@", [error localizedDescription]);

    id<XMPPAccountInfo> info = [self.accountManager infoForAccount:JID(@"romeo@localhost")];

    assertThat(info, notNilValue());
}

@end
