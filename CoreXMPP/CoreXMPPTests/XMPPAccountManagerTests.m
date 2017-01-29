//
//  XMPPAccountManagerTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
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
