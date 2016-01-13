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

@interface XMPPServiceManagerTests : XCTestCase

@end

@implementation XMPPServiceManagerTests

- (void)testAccountManagement
{
    XMPPServiceManager *serviceManager = [[XMPPServiceManager alloc] initWithOptions:nil];
    id<XMPPServiceManagerDelegate> delegate = mockProtocol(@protocol(XMPPServiceManagerDelegate));
    serviceManager.delegate = delegate;

    XMPPAccount *account = [serviceManager accountWithJID:@"romeo@localhost"];
    assertThat(account, notNilValue());
    assertThat(account.JID, equalTo(@"romeo@localhost"));
    assertThat(serviceManager.accounts, contains(account, nil));

    // An account should initially be suspended (and therefore disconnected).
    assertThatBool(account.suspended, isTrue());
    assertThatBool(account.connected, isFalse());

    //
    // Prepare SASL Authentication
    //

    [givenVoid([delegate serviceManager:serviceManager account:anything() needsCredentialsForSASLMechanism:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] lastObject];
        if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
            [mechanism authenticateWithUsername:@"romeo" password:@"123"];
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
}

@end
