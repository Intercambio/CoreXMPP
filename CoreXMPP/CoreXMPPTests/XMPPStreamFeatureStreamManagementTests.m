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

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;

    assertThatInteger(sm.numberOfReceivedStanzas, equalToInteger(0));

    PXDocument *stanza_1 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_2 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_3 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];

    [sm didHandleReceviedStanza:stanza_1.root];
    [sm didHandleReceviedStanza:stanza_2.root];
    [sm didHandleReceviedStanza:stanza_3.root];

    assertThatInteger(sm.numberOfReceivedStanzas, equalToInteger(3));

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting Response from Client"];
    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *stanza = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

        assertThat(stanza.name, equalTo(@"a"));
        assertThat(stanza.namespace, equalTo(@"urn:xmpp:sm:3"));

        NSUInteger h = [[stanza valueForAttribute:@"h"] integerValue];
        assertThatInteger(h, equalToInteger(3));

        [expectation fulfill];

        if (_completion) {
            _completion(nil);
        }

        return nil;
    }];

    PXDocument *request = [[PXDocument alloc] initWithElementName:@"r" namespace:@"urn:xmpp:sm:3" prefix:nil];
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

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;

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

- (void)testAcknowledgeSentStanzas
{
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"sm" namespace:@"urn:xmpp:sm:3" prefix:nil];
    XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    assertThat(feature, notNilValue());

    id<XMPPStreamFeatureDelegate> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    //
    // Prepare Negotiation
    //

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];

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

    id<XMPPClientStreamManagement> sm = (id<XMPPClientStreamManagement>)feature;

    assertThatInteger(sm.numberOfSendStanzas, equalToInteger(0));
    assertThatInteger(sm.numberOfAcknowledgedStanzas, equalToInteger(0));

    PXDocument *stanza_1 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_2 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];
    PXDocument *stanza_3 = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"bar:baz" prefix:nil];

    [sm didSentStanza:stanza_1.root];
    [sm didSentStanza:stanza_2.root];
    [sm didSentStanza:stanza_3.root];

    assertThatInteger(sm.numberOfSendStanzas, equalToInteger(3));
    assertThatInteger(sm.numberOfAcknowledgedStanzas, equalToInteger(0));
    assertThat(sm.unacknowledgedStanzas, equalTo(@[ stanza_1.root, stanza_2.root, stanza_3.root ]));

    PXDocument *ack = [[PXDocument alloc] initWithElementName:@"a"
                                                    namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                       prefix:nil];
    [ack.root setValue:@"2" forAttribute:@"h"];

    expectation = [self expectationWithDescription:@"Expecting Acknowledgement"];
    [feature handleStanza:ack.root
               completion:^(NSError *error) {
                   [expectation fulfill];
               }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatInteger(sm.numberOfAcknowledgedStanzas, equalToInteger(2));
    assertThat(sm.unacknowledgedStanzas, equalTo(@[ stanza_3.root ]));
}

- (void)testClient_ReceviedStanzas
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

    id<XMPPClientStreamManagement> sm = client.streamManagement;
    assertThat(sm, notNilValue());

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

- (void)testClient_SentStanzas
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

    id<XMPPClientStreamManagement> sm = client.streamManagement;
    assertThat(sm, notNilValue());

    [self keyValueObservingExpectationForObject:sm
                                        keyPath:@"numberOfSendStanzas"
                                  expectedValue:@(1)];

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message"
                                                                namespace:@"jabber:client"
                                                                   prefix:nil];
    [messageDocument.root setStringValue:@"1"];
    [client handleStanza:messageDocument.root completion:nil];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatInteger(sm.numberOfAcknowledgedStanzas, equalToInteger(0));
    assertThat(sm.unacknowledgedStanzas, equalTo(@[ messageDocument.root ]));
}
@end
