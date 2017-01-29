//
//  XMPPStreamFeatureStreamManagementTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
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

@interface XMPPStreamFeatureStreamManagementTests : XMPPTestCase

@end

@implementation XMPPStreamFeatureStreamManagementTests

#pragma mark Enabling Stream Management

- (void)testEnablingStreamManagement
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());
    assertThat([[feature class] name], equalTo(@"sm"));
    assertThat([[feature class] namespace], equalTo(@"urn:xmpp:sm:3"));

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        PXElement *stanza = document.root;

        assertThat(stanza.name, equalTo(@"enable"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"enabled" namespace:@"urn:xmpp:sm:3" prefix:nil];
            [feature handleDocument:response error:nil];
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

    //
    // Verify
    //

    assertThat(feature, conformsTo(@protocol(XMPPClientStreamManagement)));

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;
    assertThatBool(sm.enabled, isTrue());

    [verifyCount(delegate, times(1)) streamFeatureDidSucceedNegotiation:feature];
    [verifyCount(delegate, never()) streamFeature:feature didFailNegotiationWithError:anything()];
}

- (void)testEnablingStreamManagementFailed
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());
    assertThat([[feature class] name], equalTo(@"sm"));
    assertThat([[feature class] namespace], equalTo(@"urn:xmpp:sm:3"));

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        PXElement *stanza = document.root;

        assertThat(stanza.name, equalTo(@"enable"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"failed" namespace:@"urn:xmpp:sm:3" prefix:nil];
            [response.root addElementWithName:@"unexpected-request" namespace:@"urn:ietf:params:xml:ns:xmpp-stanzas" content:nil];
            [feature handleDocument:response error:nil];
        });

        return nil;
    }];

    //
    // Begin Negotiation
    //

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting successfull negotiation"];
    [givenVoid([delegate streamFeature:feature didFailNegotiationWithError:anything()]) willDo:^id(NSInvocation *invocation) {
        NSError *error = [[invocation mkt_arguments] lastObject];
        assertThat(error, notNilValue());
        assertThat(error.domain, equalTo(XMPPStanzaErrorDomain));
        assertThatInteger(error.code, equalToInteger(XMPPStanzaErrorCodeUnexpectedRequest));
        [expectation fulfill];
        return nil;
    }];
    [feature beginNegotiationWithHostname:@"localhost" options:nil];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    //
    // Verify
    //

    assertThat(feature, conformsTo(@protocol(XMPPClientStreamManagement)));

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;
    assertThatBool(sm.enabled, isFalse());

    [verifyCount(delegate, never()) streamFeatureDidSucceedNegotiation:feature];
    [verifyCount(delegate, times(1)) streamFeature:feature didFailNegotiationWithError:anything()];
}

#pragma mark Acknowledgement

- (void)testRequestAckByServer
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());
    assertThat([[feature class] name], equalTo(@"sm"));
    assertThat([[feature class] namespace], equalTo(@"urn:xmpp:sm:3"));

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;

    assertThatInteger(sm.numberOfReceivedDocuments, equalToInteger(0));

    PXDocument *stanza_1 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_2 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_3 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];

    [sm didHandleReceviedDocument:stanza_1];
    [sm didHandleReceviedDocument:stanza_2];
    [sm didHandleReceviedDocument:stanza_3];

    assertThatInteger(sm.numberOfReceivedDocuments, equalToInteger(3));

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting Response from Client"];
    [givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        PXElement *stanza = document.root;

        assertThat(stanza.name, equalTo(@"a"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        NSUInteger h = [[stanza valueForAttribute:@"h"] integerValue];
        assertThatInteger(h, equalToInteger(3));

        [expectation fulfill];

        return nil;
    }];

    PXDocument *request = [[PXDocument alloc] initWithElementName:@"r" namespace:@"urn:xmpp:sm:3" prefix:nil];
    [feature handleDocument:request error:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRequestAckByClient
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting Request from Client"];
    [givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        PXElement *stanza = document.root;

        assertThat(stanza.name, equalTo(@"r"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        [expectation fulfill];

        return nil;
    }];
    [sm requestAcknowledgement];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcknowledgeSentStanzasAndResume
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());

    //
    // Prepare Negotiation
    //

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    [[givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];
        PXElement *stanza = document.root;

        assertThat(stanza.name, equalTo(@"enable"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));
        assertThatBool([[stanza valueForAttribute:@"resume"] boolValue], isTrue());

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"enabled" namespace:@"urn:xmpp:sm:3" prefix:nil];
            [response.root setValue:@"a" forAttribute:@"id"];
            [response.root setValue:@"true" forAttribute:@"resume"];
            [feature handleDocument:response error:nil];
        });

        return nil;
    }] willDo:^id(NSInvocation *invocation) {
        return nil;
    }];

    //
    // Begin Negotiation
    //

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting successfull negotiation"];
    [givenVoid([feature.delegate streamFeatureDidSucceedNegotiation:feature]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];
    [feature beginNegotiationWithHostname:@"localhost" options:nil];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;

    assertThatBool(sm.resumable, isTrue());
    assertThatInteger(sm.numberOfSentDocuments, equalToInteger(0));
    assertThatInteger(sm.numberOfAcknowledgedDocuments, equalToInteger(0));

    PXDocument *stanza_1 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_2 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_3 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];

    __block BOOL ack_1 = NO;
    __block BOOL ack_2 = NO;
    __block BOOL ack_3 = NO;

    [sm didSentDocument:stanza_1
        acknowledgement:^(NSError *error) {
            ack_1 = YES;
        }];
    [sm didSentDocument:stanza_2
        acknowledgement:^(NSError *error) {
            ack_2 = YES;
        }];
    [sm didSentDocument:stanza_3
        acknowledgement:^(NSError *error) {
            ack_3 = YES;
        }];

    assertThatInteger(sm.numberOfSentDocuments, equalToInteger(3));
    assertThatInteger(sm.numberOfAcknowledgedDocuments, equalToInteger(0));
    assertThat(sm.unacknowledgedDocuments, equalTo(@[ stanza_1, stanza_2, stanza_3 ]));

    assertThatBool(ack_1, isFalse());
    assertThatBool(ack_2, isFalse());
    assertThatBool(ack_3, isFalse());

    [sm didHandleReceviedDocument:stanza_1];

    PXDocument *ack = [[PXDocument alloc] initWithElementName:@"a"
                                                    namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                       prefix:nil];
    [ack.root setValue:@"2" forAttribute:@"h"];
    [feature handleDocument:ack error:nil];

    assertThatInteger(sm.numberOfAcknowledgedDocuments, equalToInteger(2));
    assertThat(sm.unacknowledgedDocuments, equalTo(@[ stanza_3 ]));

    assertThatBool(ack_1, isTrue());
    assertThatBool(ack_2, isTrue());
    assertThatBool(ack_3, isFalse());

    //
    // Prepare Resume
    //

    delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    XCTestExpectation *expectResending = [self expectationWithDescription:@"Resending Stanzas"];

    [[givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];
        PXElement *stanza = document.root;

        assertThat(stanza.name, equalTo(@"resume"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));
        assertThat([stanza valueForAttribute:@"previd"], equalTo(@"a"));
        assertThat([stanza valueForAttribute:@"h"], equalTo(@"1"));

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"resumed" namespace:@"urn:xmpp:sm:3" prefix:nil];
            [response.root setValue:@"a" forAttribute:@"previd"];
            [response.root setValue:@"2" forAttribute:@"h"];
            [feature handleDocument:response error:nil];
        });

        return nil;
    }] willDo:^id(NSInvocation *invocation) {
        PXDocument *document = [[invocation mkt_arguments] lastObject];
        assertThat(document.data, equalTo(stanza_3.data));

        [expectResending fulfill];
        return nil;
    }];

    //
    // Resume
    //

    expectation = [self expectationWithDescription:@"Expecting successfull negotiation"];
    [givenVoid([feature.delegate streamFeatureDidSucceedNegotiation:feature]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];
    [feature beginNegotiationWithHostname:@"localhost" options:nil];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
