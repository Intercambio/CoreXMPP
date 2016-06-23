//
//  XMPPStreamFeatureSessionTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPStreamFeatureSessionTests : XMPPTestCase

@end

@implementation XMPPStreamFeatureSessionTests

- (void)testNameAndNamespace
{
    assertThat([XMPPStreamFeatureSession name], equalTo(@"session"));
    assertThat([XMPPStreamFeatureSession namespace], equalTo(XMPPStreamFeatureSessionNamespace));
}

- (void)testStartSession
{
    //
    // Prepare the Feature and the Delegate
    //

    XMPPStreamFeatureSession *feature = [[XMPPStreamFeatureSession alloc] initWithConfiguration:[self featureDocument]];

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    //
    // Prepare Negotiation
    //

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *iq = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        assertThat(iq.name, equalTo(@"iq"));
        assertThat(iq.namespace, equalTo(@"jabber:client"));
        assertThat([iq valueForAttribute:@"type"], equalTo(@"set"));
        assertThat([iq valueForAttribute:@"id"], notNilValue());

        assertThatInteger(iq.numberOfElements, equalToInteger(1));

        PXElement *bind = [iq elementAtIndex:0];
        assertThat(bind.name, equalTo(@"session"));
        assertThat(bind.namespace, equalTo(XMPPStreamFeatureSessionNamespace));

        NSString *requestId = [iq valueForAttribute:@"id"];

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

            PXElement *iq = response.root;
            [iq setValue:@"result" forAttribute:@"type"];
            [iq setValue:requestId forAttribute:@"id"];

            [feature handleDocument:response error:nil];
        });

        if (_completion) {
            _completion(nil);
        }

        return nil;
    }];

    //
    // Begin Negotiation
    //

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting successfull negotiation"];
    [givenVoid([delegate streamFeatureDidSucceedNegotiation:feature]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];
    [feature beginNegotiationWithHostname:@"localhost" options:nil];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testStartSessionWithError
{
    //
    // Prepare the Feature and the Delegate
    //

    XMPPStreamFeatureSession *feature = [[XMPPStreamFeatureSession alloc] initWithConfiguration:[self featureDocument]];

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    //
    // Prepare Negotiation
    //

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *iq = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        NSString *requestId = [iq valueForAttribute:@"id"];

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

            PXElement *iq = response.root;
            [iq setValue:@"error" forAttribute:@"type"];
            [iq setValue:requestId forAttribute:@"id"];

            PXElement *error = [iq addElementWithName:@"error" namespace:@"jabber:client" content:nil];
            [error setValue:@"auth" forAttribute:@"type"];
            [error addElementWithName:@"forbidden" namespace:@"urn:ietf:params:xml:ns:xmpp-stanzas" content:nil];

            [feature handleDocument:response error:nil];
        });

        if (_completion) {
            _completion(nil);
        }

        return nil;
    }];

    //
    // Begin Negotiation
    //

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting failed negotiation"];
    [givenVoid([delegate streamFeature:feature didFailNegotiationWithError:anything()]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];
    [feature beginNegotiationWithHostname:@"localhost" options:nil];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    HCArgumentCaptor *errorCaptor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(1)) streamFeature:feature didFailNegotiationWithError:(id)errorCaptor];

    NSError *error = [errorCaptor value];
    assertThat(error, notNilValue());

    assertThat(error.domain, equalTo(XMPPStanzaErrorDomain));
    assertThatInteger(error.code, equalToInteger(XMPPStanzaErrorCodeForbidden));
}

#pragma mark -

- (PXDocument *)featureDocument
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"session"
                                                         namespace:XMPPStreamFeatureSessionNamespace
                                                            prefix:nil];

    return document;
}

@end
