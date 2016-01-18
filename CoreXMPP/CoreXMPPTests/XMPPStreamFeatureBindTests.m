//
//  XMPPStreamFeatureBindTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPStreamFeatureBindTests : XMPPTestCase

@end

@implementation XMPPStreamFeatureBindTests

- (void)testNameAndNamespace
{
    assertThat([XMPPStreamFeatureBind name], equalTo(@"bind"));
    assertThat([XMPPStreamFeatureBind namespace], equalTo(XMPPStreamFeatureBindNamespace));
}

- (void)testBindWithoutResource
{
    //
    // Prepare the Feature and the Delegate
    //

    XMPPStreamFeatureBind *feature = [[XMPPStreamFeatureBind alloc] initWithConfiguration:[self featureDocument]];

    id<XMPPStreamFeatureDelegateBind> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateBind));
    feature.delegate = delegate;

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleElement:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *iq = [[invocation mkt_arguments] lastObject];

        assertThat(iq.name, equalTo(@"iq"));
        assertThat(iq.namespace, equalTo(@"jabber:client"));
        assertThat([iq valueForAttribute:@"type"], equalTo(@"set"));
        assertThat([iq valueForAttribute:@"id"], notNilValue());

        assertThatInteger(iq.numberOfElements, equalToInteger(1));

        PXElement *bind = [iq elementAtIndex:0];
        assertThat(bind.name, equalTo(@"bind"));
        assertThat(bind.namespace, equalTo(XMPPStreamFeatureBindNamespace));

        assertThatInteger(bind.numberOfElements, equalToInteger(0));

        NSString *requestId = [iq valueForAttribute:@"id"];

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

            PXElement *iq = response.root;
            [iq setValue:@"result" forAttribute:@"type"];
            [iq setValue:requestId forAttribute:@"id"];

            PXElement *bind = [iq addElementWithName:@"bind" namespace:XMPPStreamFeatureBindNamespace content:nil];
            [bind addElementWithName:@"jid" namespace:XMPPStreamFeatureBindNamespace content:@"test@example.com/example"];

            [feature handleElement:iq];
        });

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

    [verify(delegate) streamFeature:feature didBindToJID:equalTo(JID(@"test@example.com/example"))];
    [verify(delegate) resourceNameForStreamFeature:feature];
}

- (void)testBindWithResource
{
    //
    // Prepare the Feature and the Delegate
    //

    XMPPStreamFeatureBind *feature = [[XMPPStreamFeatureBind alloc] initWithConfiguration:[self featureDocument]];

    id<XMPPStreamFeatureDelegateBind> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateBind));
    feature.delegate = delegate;

    [given([delegate resourceNameForStreamFeature:feature]) willReturn:@"example"];

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleElement:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *iq = [[invocation mkt_arguments] lastObject];

        assertThat(iq.name, equalTo(@"iq"));
        assertThat(iq.namespace, equalTo(@"jabber:client"));
        assertThat([iq valueForAttribute:@"type"], equalTo(@"set"));
        assertThat([iq valueForAttribute:@"id"], notNilValue());

        assertThatInteger(iq.numberOfElements, equalToInteger(1));

        PXElement *bind = [iq elementAtIndex:0];
        assertThat(bind.name, equalTo(@"bind"));
        assertThat(bind.namespace, equalTo(XMPPStreamFeatureBindNamespace));

        assertThatInteger(bind.numberOfElements, equalToInteger(1));

        PXElement *resource = [bind elementAtIndex:0];
        assertThat(resource.name, equalTo(@"resource"));
        assertThat(resource.namespace, equalTo(XMPPStreamFeatureBindNamespace));
        assertThat(resource.stringValue, equalTo(@"example"));

        NSString *requestId = [iq valueForAttribute:@"id"];

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

            PXElement *iq = response.root;
            [iq setValue:@"result" forAttribute:@"type"];
            [iq setValue:requestId forAttribute:@"id"];

            PXElement *bind = [iq addElementWithName:@"bind" namespace:XMPPStreamFeatureBindNamespace content:nil];
            [bind addElementWithName:@"jid" namespace:XMPPStreamFeatureBindNamespace content:@"test@example.com/example"];

            [feature handleElement:iq];
        });

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

    [verify(delegate) streamFeature:feature didBindToJID:equalTo(JID(@"test@example.com/example"))];
    [verify(delegate) resourceNameForStreamFeature:feature];
}

- (void)testBindWithConflict
{
    //
    // Prepare the Feature and the Delegate
    //

    XMPPStreamFeatureBind *feature = [[XMPPStreamFeatureBind alloc] initWithConfiguration:[self featureDocument]];

    id<XMPPStreamFeatureDelegateBind> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateBind));
    feature.delegate = delegate;

    [given([delegate resourceNameForStreamFeature:feature]) willReturn:@"example"];

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleElement:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *iq = [[invocation mkt_arguments] lastObject];

        NSString *requestId = [iq valueForAttribute:@"id"];

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

            PXElement *iq = response.root;
            [iq setValue:@"error" forAttribute:@"type"];
            [iq setValue:requestId forAttribute:@"id"];

            PXElement *error = [iq addElementWithName:@"error" namespace:@"jabber:client" content:nil];
            [error setValue:@"modify" forAttribute:@"type"];
            [error addElementWithName:@"conflict" namespace:@"urn:ietf:params:xml:ns:xmpp-stanzas" content:nil];

            [feature handleElement:iq];
        });

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

    [verifyCount(delegate, never()) streamFeature:feature didBindToJID:anything()];
    [verify(delegate) resourceNameForStreamFeature:feature];

    HCArgumentCaptor *errorCaptor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(1)) streamFeature:feature didFailNegotiationWithError:(id)errorCaptor];

    NSError *error = [errorCaptor value];
    assertThat(error, notNilValue());

    assertThat(error.domain, equalTo(XMPPStanzaErrorDomain));
    assertThatInteger(error.code, equalToInteger(XMPPStanzaErrorCodeConflict));
}

#pragma mark -

- (PXDocument *)featureDocument
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"bind"
                                                         namespace:XMPPStreamFeatureBindNamespace
                                                            prefix:nil];

    return document;
}

@end
