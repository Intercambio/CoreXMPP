//
//  XMPPStreamFeatureSessionTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
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

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        PXElement *iq = document.root;

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

    //
    // Prepare Negotiation
    //

    [givenVoid([delegate streamFeature:feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        PXElement *iq = document.root;

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
