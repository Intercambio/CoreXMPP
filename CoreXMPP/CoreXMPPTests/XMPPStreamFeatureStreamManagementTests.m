//
//  XMPPStreamFeatureStreamManagementTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
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

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    //
    // Prepare Negotiation
    //

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *stanza = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        assertThat(stanza.name, equalTo(@"enable"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"enabled" namespace:@"urn:xmpp:sm:3" prefix:nil];
            [feature handleStanza:response.root completion:nil];
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

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    //
    // Prepare Negotiation
    //

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *stanza = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        assertThat(stanza.name, equalTo(@"enable"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"failed" namespace:@"urn:xmpp:sm:3" prefix:nil];
            [response.root addElementWithName:@"unexpected-request" namespace:@"urn:ietf:params:xml:ns:xmpp-stanzas" content:nil];
            [feature handleStanza:response.root completion:nil];
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

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    XMPPStreamFeatureStreamManagement *sm = (XMPPStreamFeatureStreamManagement *)feature;
    sm.numberOfReceivedStanzas = 134;

    PXDocument *request = [[PXDocument alloc] initWithElementName:@"r" namespace:@"urn:xmpp:sm:3" prefix:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting Response from Client"];
    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *stanza = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        assertThat(stanza.name, equalTo(@"a"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        NSUInteger h = [[stanza valueForAttribute:@"h"] integerValue];
        assertThatInteger(h, equalToInteger(134));

        [expectation fulfill];

        if (_completion) {
            _completion(nil);
        }

        return nil;
    }];
    [feature handleStanza:request.root
               completion:^(NSError *error){

               }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRequestAckByClient
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    XMPPStreamFeatureStreamManagement *sm = (XMPPStreamFeatureStreamManagement *)feature;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting Request from Client"];
    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *stanza = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        assertThat(stanza.name, equalTo(@"r"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        [expectation fulfill];

        if (_completion) {
            _completion(nil);
        }

        return nil;
    }];
    [sm requestAcknowledgement];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testHandleAckByClient
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());

    id<XMPPStreamFeatureDelegateStreamManagement> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateStreamManagement));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting Acknowledgement"];
    [[givenVoid([delegate streamFeature:feature didAcknowledgeStanzas:554]) withMatcher:equalToInteger(554) forArgument:1] willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];

    PXDocument *ack = [[PXDocument alloc] initWithElementName:@"a"
                                                    namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                       prefix:nil];
    [ack.root setValue:@"554" forAttribute:@"h"];
    [feature handleStanza:ack.root completion:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcknowledgementByClient
{
    XMPPStreamStub *stream = [[XMPPStreamStub alloc] initWithHostname:@"localhost" options:nil];
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    client.stanzaHandler = stanzaHandler;

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];
        if (_completion) {
            _completion(nil);
        }
        return nil;
    }];

    //
    // Prepare Client with Stream Management Feature
    //

    [stream onDidOpen:^(XMPPStreamStub *stream) {

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [doc.root addElementWithName:@"sm" namespace:@"urn:xmpp:sm:3" content:nil];

        [stream receiveElement:doc.root];
    }];

    [stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {
        assertThat(element.name, equalTo(@"enable"));
        assertThat(element.namespace, equalTo(@"urn:xmpp:sm:3"));
        PXDocument *response = [[PXDocument alloc] initWithElementName:@"enabled"
                                                             namespace:@"urn:xmpp:sm:3"
                                                                prefix:nil];
        [stream receiveElement:response.root];
    }];

    XCTestExpectation *establishedConnectionExpectation = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [establishedConnectionExpectation fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // SM
    //

    XMPPStreamFeatureStreamManagement *sm = [client.negotiatedFeatures firstObject];
    assertThat(sm, notNilValue());
    assertThat([[sm class] name], equalTo(@"sm"));
    assertThat([[sm class] namespace], equalTo(@"urn:xmpp:sm:3"));
    assertThatInteger(sm.numberOfReceivedStanzas, equalToInteger(0));

    //
    // Ack Recevied Stanza
    //

    [self keyValueObservingExpectationForObject:sm
                                        keyPath:@"numberOfReceivedStanzas"
                                  expectedValue:@(1)];

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message"
                                                                namespace:@"jabber:client"
                                                                   prefix:nil];
    [messageDocument.root setStringValue:@"1"];
    [stream receiveElement:messageDocument.root];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
