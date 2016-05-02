//
//  XMPPAccountManagerTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPAccountManagerTests : XMPPTestCase

@end

@implementation XMPPAccountManagerTests

#pragma mark Account Management

- (void)testAccountManagement
{
    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];
    assertThat(account, notNilValue());
    assertThat(account.JID, equalTo(JID(@"romeo@localhost")));
    assertThat(accountManager.accounts, contains(account, nil));

    // An account should initially be suspended (and therefore disconnected).
    assertThatBool(account.suspended, isTrue());
    assertThatBool(account.connected, isFalse());

    assertThat(account.options, equalTo(@{}));

    NSDictionary *options = @{ @"foo" : @"bar" };
    [accountManager setOptions:options forAccount:account];

    assertThat(account.options, equalTo(@{ @"foo" : @"bar" }));

    [accountManager removeAccount:account];
    assertThat(accountManager.accounts, isNot(contains(account, nil)));
}

- (void)testAccountOptions
{
    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"
                                     completion:nil];
        }
        return nil;
    }];

    //
    // Set Options
    //

    NSDictionary *options = @{ XMPPWebsocketStreamURLKey : [NSURL URLWithString:@"ws://localhost:5280/xmpp"] };
    [accountManager setOptions:options forAccount:account];

    //
    // Resume Account
    //

    [accountManager resumeAccount:account];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPAccountManagerDidConnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSuspendAndResumeAccounts
{
    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"
                                     completion:nil];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [accountManager resumeAccount:account];

    //
    // Wait for the Account to be resumed
    //

    [self expectationForNotification:XMPPAccountManagerDidResumeAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isFalse());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPAccountManagerDidConnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Suspend Account
    //

    [accountManager suspendAccount:account];

    //
    // Wait for the Account to be suspended
    //

    [self expectationForNotification:XMPPAccountManagerDidSuspendAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be disconnected
    //

    [self expectationForNotification:XMPPAccountManagerDidDisconnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isFalse());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSuspendAccountOnRemove
{
    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"
                                     completion:nil];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [accountManager resumeAccount:account];

    //
    // Wait for the Account to be resumed
    //

    [self expectationForNotification:XMPPAccountManagerDidResumeAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isFalse());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Remove Account
    //

    [accountManager removeAccount:account];

    //
    // Wait for the Account to be suspended
    //

    [self expectationForNotification:XMPPAccountManagerDidSuspendAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testKeyChain
{
    XMPPKeyChainService *keyChain = [[XMPPKeyChainService alloc] initWithServiceName:self.keyChainServiceName];

    NSDictionary *options = @{XMPPAccountManagerOptionsKeyChainServiceKey : keyChain};
    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:options];

    [accountManager addAccountWithJID:JID(@"romeo@example.com")
                              options:@{ @"foo" : @"bar" }
                                error:nil];

    assertThat(keyChain.identities, contains(JID(@"romeo@example.com"), nil));

    XMPPKeyChainItemAttributes *attributes = [keyChain attributesForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(attributes.options, equalTo(@{ @"foo" : @"bar" }));

    accountManager = [[XMPPAccountManager alloc] initWithOptions:options];
    assertThat(accountManager.accounts, hasCountOf(1));

    XMPPAccount *account = [accountManager.accounts firstObject];
    assertThat(account.JID, equalTo(JID(@"romeo@example.com")));
    assertThat(account.options, equalTo(@{ @"foo" : @"bar" }));
}

#pragma mark Reconnect

- (void)testReconnectOnFailure
{
    XMPPStreamStub *stream = [[XMPPStreamStub alloc] initWithHostname:@"localhost" options:nil];

    [stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveElement:doc.root];
    }];

    [stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveElement:doc.root];
    }];

    XMPPAccountManagerClientFactoryCallback callback = ^(XMPPAccount *account, NSDictionary *options) {
        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{XMPPClientOptionsStreamKey : stream}];
    };

    NSDictionary *options = @{XMPPAccountManagerOptionClientFactoryCallbackKey : callback};

    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"
                                     completion:nil];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [accountManager resumeAccount:account];

    //
    // Wait for the Account to be resumed
    //

    [self expectationForNotification:XMPPAccountManagerDidResumeAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isFalse());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPAccountManagerDidConnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Let the stream fail
    //

    NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                         code:XMPPStreamErrorCodeInternalServerError
                                     userInfo:nil];
    [stream failWithError:error];

    //
    // Wait for the Account to be disconnected
    //

    [self expectationForNotification:XMPPAccountManagerConnectionDidFailNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isFalse());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPAccountManagerDidConnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testReconnectAfterTime
{
    XMPPStreamStub *stream = [[XMPPStreamStub alloc] initWithHostname:@"localhost" options:nil];

    [stream onDidOpen:^(XMPPStreamStub *stream) {
        NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                             code:XMPPStreamErrorCodeInternalServerError
                                         userInfo:nil];
        [stream failWithError:error];
    }];

    [stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveElement:doc.root];
    }];

    XMPPAccountManagerClientFactoryCallback callback = ^(XMPPAccount *account, NSDictionary *options) {
        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{XMPPClientOptionsStreamKey : stream}];
    };

    NSDictionary *options = @{XMPPAccountManagerOptionClientFactoryCallbackKey : callback};

    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];

    //
    // Resume Account
    //

    [accountManager resumeAccount:account];

    //
    // Wait for connection failure notification
    //

    [self expectationForNotification:XMPPAccountManagerConnectionDidFailNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThat(notification.userInfo[XMPPAccountManagerAccountKey], is(account));
                                 return YES;
                             }];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPAccountManagerDidConnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark Despatching

- (void)testDispatching
{
    XMPPAccountManager *accountManager = [[XMPPAccountManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    accountManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [accountManager addAccountWithJID:JID(@"romeo@localhost") options:nil error:nil];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"
                                     completion:nil];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [accountManager resumeAccount:account];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPAccountManagerDidConnectAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Send Ping
    //

    XMPPJID *to = JID(@"localhost");
    XMPPJID *from = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

    PXElement *iq = doc.root;
    [iq setValue:[to stringValue] forAttribute:@"to"];
    [iq setValue:[from stringValue] forAttribute:@"from"];
    [iq setValue:@"get" forAttribute:@"type"];

    NSString *requestID = [[NSUUID UUID] UUIDString];
    [iq setValue:requestID forAttribute:@"id"];

    [iq addElementWithName:@"ping" namespace:@"urn:xmpp:ping" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Pong"];
    [accountManager.dispatcher handleIQRequest:iq
                                       timeout:60.0
                                    completion:^(PXElement *response, NSError *error) {
                                        assertThat(response, notNilValue());
                                        [expectation fulfill];
                                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    //
    // Suspend Account
    //

    [accountManager suspendAccount:account];

    //
    // Wait for the Account to be suspended
    //

    [self expectationForNotification:XMPPAccountManagerDidSuspendAccountNotification
                              object:accountManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isTrue());
                                 return notification.userInfo[XMPPAccountManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Send Ping
    //

    expectation = [self expectationWithDescription:@"Expect Pong"];
    [accountManager.dispatcher handleIQRequest:iq
                                       timeout:60.0
                                    completion:^(PXElement *response, NSError *error) {
                                        assertThat(response, nilValue());
                                        assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
                                        assertThatInteger(error.code, equalToInt(XMPPDispatcherErrorCodeNoRoute));
                                        [expectation fulfill];
                                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
