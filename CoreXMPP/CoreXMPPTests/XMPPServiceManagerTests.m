//
//  XMPPServiceManagerTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPServiceManagerTests : XMPPTestCase

@end

@implementation XMPPServiceManagerTests

#pragma mark Account Management

- (void)testAccountManagement
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];
    assertThat(account, notNilValue());
    assertThat(account.JID, equalTo(JID(@"romeo@localhost")));
    assertThat(serviceManager.accounts, contains(account, nil));

    // An account should initially be suspended (and therefore disconnected).
    assertThatBool(account.suspended, isTrue());
    assertThatBool(account.connected, isFalse());

    assertThat(account.options, equalTo(@{}));

    NSDictionary *options = @{ @"foo" : @"bar" };
    [serviceManager setOptions:options forAccount:account];

    assertThat(account.options, equalTo(@{ @"foo" : @"bar" }));

    [serviceManager removeAccount:account];
    assertThat(serviceManager.accounts, isNot(contains(account, nil)));
}

- (void)testAccountOptions
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@example.com")];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"];
        }
        return nil;
    }];

    //
    // Set Options
    //

    NSDictionary *options = @{ XMPPWebsocketStreamURLKey : [NSURL URLWithString:@"ws://localhost:5280/xmpp"] };
    [serviceManager setOptions:options forAccount:account];

    //
    // Resume Account
    //

    [serviceManager resumeAccount:account];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSuspendAndResumeAccounts
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [serviceManager resumeAccount:account];

    //
    // Wait for the Account to be resumed
    //

    [self expectationForNotification:XMPPServiceManagerDidResumeAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isFalse());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Suspend Account
    //

    [serviceManager suspendAccount:account];

    //
    // Wait for the Account to be suspended
    //

    [self expectationForNotification:XMPPServiceManagerDidSuspendAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be disconnected
    //

    [self expectationForNotification:XMPPServiceManagerDidDisconnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isFalse());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSuspendAccountOnRemove
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [serviceManager resumeAccount:account];

    //
    // Wait for the Account to be resumed
    //

    [self expectationForNotification:XMPPServiceManagerDidResumeAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isFalse());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Remove Account
    //

    [serviceManager removeAccount:account];

    //
    // Wait for the Account to be suspended
    //

    [self expectationForNotification:XMPPServiceManagerDidSuspendAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
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

    XMPPServiceManagerClientFactoryCallback callback = ^(XMPPAccount *account, NSDictionary *options) {
        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{XMPPClientOptionsStreamKey : stream}];
    };

    NSDictionary *options = @{XMPPServiceManagerOptionClientFactoryCallbackKey : callback};

    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [serviceManager resumeAccount:account];

    //
    // Wait for the Account to be resumed
    //

    [self expectationForNotification:XMPPServiceManagerDidResumeAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isFalse());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
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

    [self expectationForNotification:XMPPServiceManagerDidDisconnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isFalse());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
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

    XMPPServiceManagerClientFactoryCallback callback = ^(XMPPAccount *account, NSDictionary *options) {
        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{XMPPClientOptionsStreamKey : stream}];
    };

    NSDictionary *options = @{XMPPServiceManagerOptionClientFactoryCallbackKey : callback};

    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];

    //
    // Resume Account
    //

    [serviceManager resumeAccount:account];

    //
    // Wait for connection failure notification
    //

    [self expectationForNotification:XMPPServiceManagerConnectionDidFailNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThat(notification.userInfo[XMPPServiceManagerAccountKey], is(account));
                                 return YES;
                             }];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark Suspend & Resume

- (void)testSuspendAndResumeServiceManager
{
    XMPPServiceManagerClientFactoryCallback callback = ^(XMPPAccount *account, NSDictionary *options) {

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

        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{XMPPClientOptionsStreamKey : stream}];
    };

    NSDictionary *options = @{XMPPServiceManagerOptionClientFactoryCallbackKey : callback};

    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];

    //
    // Resume Account
    //

    [serviceManager resumeAllAccounts];

    // Wait for the account to be connected

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Suspend Service Manager
    //

    [serviceManager suspend];

    assertThatBool(serviceManager.suspended, isTrue());

    [serviceManager resume];

    // Wait for the account to be connected

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    assertThatBool(account.connected, isTrue());
}

#pragma mark Module Management

- (void)testManageModules
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];

    NSString *moduleName = @"XEP-0199";

    XMPPPingModule *module = (XMPPPingModule *)[serviceManager addModuleWithType:moduleName options:nil];
    assertThat(module, isA([XMPPPingModule class]));
    assertThat(serviceManager.modules, contains(module, nil));

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Completion"];
    [module sendPingTo:JID(@"juliet@localhost")
                     from:JID(@"romeo@localhost")
                  timeout:10.0
        completionHandler:^(BOOL success, NSError *error) {
            assertThatBool(success, isFalse());
            assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
            assertThatInteger(error.code, equalToInt(XMPPDispatcherErrorCodeNoRoute));
            [expectation fulfill];
        }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    [serviceManager removeModule:module];
    assertThat(serviceManager.modules, isNot(contains(module, nil)));
}

#pragma mark Despatching

- (void)testDispatching
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPPingModule *module = (XMPPPingModule *)[serviceManager addModuleWithType:@"XEP-0199" options:nil];

    XMPPAccount *account = [serviceManager accountWithJID:JID(@"romeo@localhost")];

    //
    // Prepare SASL Authentication
    //

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[[mechanism.context JID] stringValue]
                                       password:@"123"];
        }
        return nil;
    }];

    //
    // Resume Account
    //

    [serviceManager resumeAccount:account];

    //
    // Wait for the Account to be connected
    //

    [self expectationForNotification:XMPPServiceManagerDidConnectAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.connected, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Send Ping
    //

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Pong"];
    [module sendPingTo:JID(@"localhost")
                     from:JID(@"romeo@localhost")
                  timeout:10.0
        completionHandler:^(BOOL success, NSError *error) {
            assertThatBool(success, isTrue());
            [expectation fulfill];
        }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    //
    // Suspend Account
    //

    [serviceManager suspendAccount:account];

    //
    // Wait for the Account to be suspended
    //

    [self expectationForNotification:XMPPServiceManagerDidSuspendAccountNotification
                              object:serviceManager
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 assertThatBool(account.suspended, isTrue());
                                 return notification.userInfo[XMPPServiceManagerAccountKey] == account;
                             }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Send Ping
    //

    expectation = [self expectationWithDescription:@"Expect Completion"];
    [module sendPingTo:JID(@"juliet@localhost")
                     from:JID(@"romeo@localhost")
                  timeout:10.0
        completionHandler:^(BOOL success, NSError *error) {
            assertThatBool(success, isFalse());
            assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
            assertThatInteger(error.code, equalToInt(XMPPDispatcherErrorCodeNotConnected));
            [expectation fulfill];
        }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
