//
//  XMPPServiceManagerTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import <CoreXMPP/CoreXMPP.h>

#import "XMPPStreamStub.h"

@interface XMPPServiceManagerTests : XCTestCase

@end

@implementation XMPPServiceManagerTests

- (void)testAccountManagement
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;

    XMPPAccount *account = [serviceManager accountWithJID:@"romeo@localhost"];
    assertThat(account, notNilValue());
    assertThat(account.JID, equalTo(@"romeo@localhost"));
    assertThat(serviceManager.accounts, contains(account, nil));

    // An account should initially be suspended (and therefore disconnected).
    assertThatBool(account.suspended, isTrue());
    assertThatBool(account.connected, isFalse());

    [serviceManager removeAccount:account];
    assertThat(serviceManager.accounts, isNot(contains(account, nil)));
}

- (void)testSuspendAndResumeAccounts
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;
    
    XMPPAccount *account = [serviceManager accountWithJID:@"romeo@localhost"];
    
    //
    // Prepare SASL Authentication
    //
    
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[mechanism.context JID]
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
    
    XMPPAccount *account = [serviceManager accountWithJID:@"romeo@localhost"];
    
    //
    // Prepare SASL Authentication
    //
    
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[mechanism.context JID]
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
        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{ XMPPClientOptionsStreamKey: stream}];
    };
    
    NSDictionary *options = @{ XMPPServiceManagerOptionClientFactoryCallbackKey :  callback};
    
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;
    
    XMPPAccount *account = [serviceManager accountWithJID:@"romeo@localhost"];
    
    //
    // Prepare SASL Authentication
    //
    
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        assertThat(mechanism, instanceOf([SASLMechanismPLAIN class]));
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            assertThat(mechanism.context, is(account));
            [mechanism authenticateWithUsername:[mechanism.context JID]
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
    
    NSError *error = [NSError errorWithDomain:XMPPClientStreamErrorDomain
                                         code:XMPPClientStreamErrorCodeInternalServerError
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
        
        return [[XMPPClient alloc] initWithHostname:@"localhost" options:@{ XMPPClientOptionsStreamKey: stream}];
    };
    
    NSDictionary *options = @{ XMPPServiceManagerOptionClientFactoryCallbackKey :  callback};
    
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:options];
    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    serviceManager.SASLDelegate = SASLDelegate;
    
    XMPPAccount *account = [serviceManager accountWithJID:@"romeo@localhost"];
    
    
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
    
    assertThatBool(account.connected, isFalse());
    
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

@end
