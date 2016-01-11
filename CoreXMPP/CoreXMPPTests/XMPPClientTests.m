//
//  XMPPClientTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import <CoreXMPP/CoreXMPP.h>
#import "XMPPStreamStub.h"
#import "XMPPStreamFeatureStub.h"

@interface XMPPClientTests : XCTestCase
@property (nonatomic, strong) XMPPStreamStub *stream;
@end

@implementation XMPPClientTests

- (void)setUp
{
    [super setUp];
    self.stream = [[XMPPStreamStub alloc] initWithHostname:@"localhost" options:nil];
}

- (void)tearDown
{
    self.stream = nil;
    [super tearDown];
}

#pragma mark Tests

#pragma mark Connection

- (void)testConnectClient
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {

        // Send an empty feature element from the receiving entity to
        // the initiating entity after the stream has been opend.

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveElement:doc.root];
    }];

    XCTestExpectation *establishedConnectionExpectation = [self expectationWithDescription:@"Expect established Connection"];

    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [establishedConnectionExpectation fulfill];
        return nil;
    }];

    [client connect];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Expect client to disconnect"];

    [givenVoid([delegate clientDidDisconnect:client]) willDo:^id(NSInvocation *invocation) {
        [expectDisconnect fulfill];
        return nil;
    }];

    [client disconnect];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark Stream Errors

- (void)testStreamErrorParsing
{
    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"error"
                                                    namespace:@"http://etherx.jabber.org/streams"
                                                       prefix:@"stream"];

    [doc.root addElementWithName:@"system-shutdown"
                       namespace:@"urn:ietf:params:xml:ns:xmpp-streams"
                         content:nil];

    [doc.root addElementWithName:@"text"
                       namespace:@"urn:ietf:params:xml:ns:xmpp-streams"
                         content:@"Giving up!"];

    [doc.root addElementWithName:@"test"
                       namespace:@"http://example.com"
                         content:@"… some data …"];

    NSError *error = [XMPPClient streamErrorFromElement:doc.root];

    assertThat(error, notNilValue());
    assertThat(error.domain, equalTo(XMPPClientStreamErrorDomain));
    assertThatInteger(error.code, equalToInteger(XMPPClientStreamErrorCodeSystemShutdown));
    assertThat([error localizedDescription], equalTo(@"Giving up!"));
    assertThat([error.userInfo objectForKey:XMPPClientStreamErrorXMLDocumentKey], notNilValue());
}

- (void)testXMLStreamErrors
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"error"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        [doc.root addElementWithName:@"system-shutdown"
                           namespace:@"urn:ietf:params:xml:ns:xmpp-streams"
                             content:nil];

        [stream receiveElement:doc.root];
    }];

    XCTestExpectation *waitForClose = [self expectationWithDescription:@"Expecting stream to close"];
    [self.stream onDidClose:^(XMPPStreamStub *stream) {
        [waitForClose fulfill];
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    //
    // Verify Error
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verify(delegate) client:client didFailWithError:(id)captor];

    NSError *error = [captor value];

    assertThat(error.domain, equalTo(XMPPClientStreamErrorDomain));
}

- (void)testUnderlyingStreamErrors
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        NSError *error = [NSError errorWithDomain:@"testUnderlyingStreamErrors" code:123 userInfo:nil];
        [stream failWithError:error];
    }];

    XCTestExpectation *waitForClose = [self expectationWithDescription:@"Expecting stream to close"];
    [self.stream onDidClose:^(XMPPStreamStub *stream) {
        [waitForClose fulfill];
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    //
    // Verify Error
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verify(delegate) client:client didFailWithError:(id)captor];

    NSError *error = [captor value];

    assertThat(error.domain, equalTo(@"testUnderlyingStreamErrors"));
}

#pragma mark General Feature Negotiation

- (void)testVoluntaryFeatureWithoutRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"no" forAttribute:@"mandatory"];
        [feature setValue:@"no" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];

        // Send new (empty) features

        PXDocument *features = [[PXDocument alloc] initWithElementName:@"features"
                                                             namespace:@"http://etherx.jabber.org/streams"
                                                                prefix:@"stream"];
        [stream receiveElement:features.root];
    }];

    //
    // Connect
    //

    XCTestExpectation *waitForConnection = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [waitForConnection fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:anything()];

    XMPPStreamFeature *feature = [client.negotiatedFeatures firstObject];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testVoluntaryFeatureWithRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"no" forAttribute:@"mandatory"];
        [feature setValue:@"yes" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];
    }];

    //
    // Send Features (after stream reset)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        [stream receiveElement:doc.root];
    }];

    //
    // Connect
    //

    XCTestExpectation *waitForConnection = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [waitForConnection fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:anything()];

    XMPPStreamFeature *feature = [client.negotiatedFeatures firstObject];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testVoluntaryFeatureWithFailure
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"no" forAttribute:@"mandatory"];
        [feature setValue:@"no" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Feature (failure)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send failure response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"failure"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];
    }];

    //
    // Connect (failure; stream will close)
    //

    XCTestExpectation *waitForStreamClose = [self expectationWithDescription:@"Expect Stream to close"];
    [self.stream onDidClose:^(XMPPStreamStub *stream) {
        [waitForStreamClose fulfill];
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    PXQName *featureQName = [[PXQName alloc] initWithName:[XMPPStreamFeatureStub name] namespace:[XMPPStreamFeatureStub namespace]];

    [verifyCount(delegate, times(1)) client:client didFailToNegotiateFeature:anything() withError:anything()];
    [verifyCount(delegate, never()) client:client didNegotiateFeature:equalTo(featureQName)];
}

- (void)testMandatoryFeatureWithoutRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"yes" forAttribute:@"mandatory"];
        [feature setValue:@"no" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];

        // Send new (empty) features

        PXDocument *features = [[PXDocument alloc] initWithElementName:@"features"
                                                             namespace:@"http://etherx.jabber.org/streams"
                                                                prefix:@"stream"];
        [stream receiveElement:features.root];
    }];

    //
    // Connect
    //

    XCTestExpectation *waitForConnection = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [waitForConnection fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:anything()];

    XMPPStreamFeature *feature = [client.negotiatedFeatures firstObject];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testMandatoryFeatureWithRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"yes" forAttribute:@"mandatory"];
        [feature setValue:@"yes" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];
    }];

    //
    // Send Features (after stream reset)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        [stream receiveElement:doc.root];
    }];

    //
    // Connect
    //

    XCTestExpectation *waitForConnection = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [waitForConnection fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:anything()];

    XMPPStreamFeature *feature = [client.negotiatedFeatures firstObject];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testMandatoryFeatureWithFailure
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"yes" forAttribute:@"mandatory"];
        [feature setValue:@"no" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Feature (failure)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send failure response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"failure"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];
    }];

    //
    // Connect (failure; stream will close)
    //

    XCTestExpectation *waitForStreamClose = [self expectationWithDescription:@"Expect Stream to close"];
    [self.stream onDidClose:^(XMPPStreamStub *stream) {
        [waitForStreamClose fulfill];
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    PXQName *featureQName = [[PXQName alloc] initWithName:[XMPPStreamFeatureStub name] namespace:[XMPPStreamFeatureStub namespace]];

    [verifyCount(delegate, times(1)) client:client didFailToNegotiateFeature:anything() withError:anything()];
    [verifyCount(delegate, never()) client:client didNegotiateFeature:equalTo(featureQName)];
}

#pragma mark SASL Ferature

- (void)testSASLFeature
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<SASLMechanismDelegatePLAIN> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegatePLAIN));
    client.SASLDelegate = SASLDelegate;

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:@"romeo" password:@"123"];
        return nil;
    }];

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *SASLFeature = [doc.root addElementWithName:[XMPPStreamFeatureSASL name]
                                                    namespace:[XMPPStreamFeatureSASL namespace]
                                                      content:nil];

        [SASLFeature addElementWithName:@"mechanism"
                              namespace:[XMPPStreamFeatureSASL namespace]
                                content:@"PLAIN"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate SASL
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"auth"));
        assertThat(element.namespace, equalTo(@"urn:ietf:params:xml:ns:xmpp-sasl"));

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"urn:ietf:params:xml:ns:xmpp-sasl"
                                                                prefix:nil];
        [stream receiveElement:response.root];
    }];

    //
    // Send Features (after stream reset)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        PXElement *feature = [doc.root addElementWithName:[XMPPStreamFeatureStub name]
                                                namespace:[XMPPStreamFeatureStub namespace]
                                                  content:nil];

        [feature setValue:@"yes" forAttribute:@"mandatory"];
        [feature setValue:@"no" forAttribute:@"needsRestart"];

        [stream receiveElement:doc.root];
    }];

    //
    // Negotiate Test Feature (success)
    //

    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveElement:response.root];

        // Send new (empty) features

        PXDocument *features = [[PXDocument alloc] initWithElementName:@"features"
                                                             namespace:@"http://etherx.jabber.org/streams"
                                                                prefix:@"stream"];
        [stream receiveElement:features.root];
    }];

    //
    // Connect
    //

    XCTestExpectation *waitForConnection = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [waitForConnection fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiated Features
    //

    [verifyCount(delegate, times(2)) client:client didNegotiateFeature:anything()];

    XMPPStreamFeature *SASLFeature = [client.negotiatedFeatures firstObject];
    assertThat([[SASLFeature class] name], equalTo([XMPPStreamFeatureSASL name]));
    assertThat([[SASLFeature class] namespace], equalTo([XMPPStreamFeatureSASL namespace]));

    XMPPStreamFeature *TESTFeature = [client.negotiatedFeatures lastObject];
    assertThat([[TESTFeature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[TESTFeature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testUnsupportedSASLMechanism
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];
    
    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;
    
    id<SASLMechanismDelegatePLAIN> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegatePLAIN));
    client.SASLDelegate = SASLDelegate;
    
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:@"romeo" password:@"123"];
        return nil;
    }];
    
    //
    // Send Features (after stream did open)
    //
    
    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        
        PXElement *SASLFeature = [doc.root addElementWithName:[XMPPStreamFeatureSASL name]
                                                    namespace:[XMPPStreamFeatureSASL namespace]
                                                      content:nil];
        
        [SASLFeature addElementWithName:@"mechanism"
                              namespace:[XMPPStreamFeatureSASL namespace]
                                content:@"X-TEST-AUTH"];
        
        [stream receiveElement:doc.root];
    }];
    
    //
    // Connect (failure; stream will close)
    //
    
    XCTestExpectation *waitForStreamClose = [self expectationWithDescription:@"Expect Stream to close"];
    [self.stream onDidClose:^(XMPPStreamStub *stream) {
        [waitForStreamClose fulfill];
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    
    [verify(delegate) client:client didFailToNegotiateFeature:anything() withError:anything()];
}

#pragma mark Sending & Receiving

- (void)testRecevieStanzas
{
    //
    // Prepare Client and Delegate
    //

    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveElement:doc.root];
    }];

    //
    // Connect Client
    //

    XCTestExpectation *establishedConnectionExpectation = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [establishedConnectionExpectation fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Receive Stanzas
    //

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    [messageDocument.root setStringValue:@"1"];
    [self.stream receiveElement:messageDocument.root];

    PXDocument *presenceDocument = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    [presenceDocument.root setStringValue:@"2"];
    [self.stream receiveElement:presenceDocument.root];

    PXDocument *IQDocument = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    [IQDocument.root setStringValue:@"3"];
    [self.stream receiveElement:IQDocument.root];

    //
    // Receive Unsupported Element
    //

    PXDocument *document = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"http://example.com/bar" prefix:nil];
    [document.root setStringValue:@"x"];
    [self.stream receiveElement:document.root];

    //
    // Disconnect Client
    //

    XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Expect client to disconnect"];
    [givenVoid([delegate clientDidDisconnect:client]) willDo:^id(NSInvocation *invocation) {
        [expectDisconnect fulfill];
        return nil;
    }];
    [client disconnect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Stanzas
    //

    HCArgumentCaptor *captoredStanzas = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, atLeastOnce()) client:client didReceiveStanza:(id)captoredStanzas];

    NSArray *stanzas = [captoredStanzas allValues];
    assertThat(stanzas, hasCountOf(3));

    if ([stanzas count] == 3) {
        PXElement *stanza = nil;

        stanza = stanzas[0];
        assertThat(stanza.name, equalTo(@"message"));
        assertThat(stanza.namespace, equalTo(@"jabber:client"));
        assertThat(stanza.stringValue, equalTo(@"1"));

        stanza = stanzas[1];
        assertThat(stanza.name, equalTo(@"presence"));
        assertThat(stanza.namespace, equalTo(@"jabber:client"));
        assertThat(stanza.stringValue, equalTo(@"2"));

        stanza = stanzas[2];
        assertThat(stanza.name, equalTo(@"iq"));
        assertThat(stanza.namespace, equalTo(@"jabber:client"));
        assertThat(stanza.stringValue, equalTo(@"3"));
    }

    //
    // Verify Unsupported Elements
    //

    HCArgumentCaptor *captoredElements = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, atLeastOnce()) client:client didReceiveUnsupportedElement:(id)captoredElements];

    NSArray *elements = [captoredElements allValues];
    assertThat(elements, hasCountOf(1));

    PXElement *element = [elements firstObject];
    assertThat(element.name, equalTo(@"foo"));
    assertThat(element.namespace, equalTo(@"http://example.com/bar"));
    assertThat(element.stringValue, equalTo(@"x"));
}

- (void)testSendStanzas
{
    //
    // Prepare Client and Delegate
    //

    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{XMPPClientOptionsStreamKey : self.stream}];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveElement:doc.root];
    }];

    //
    // Connect Client
    //

    XCTestExpectation *establishedConnectionExpectation = [self expectationWithDescription:@"Expect established Connection"];
    [givenVoid([delegate clientDidConnect:client]) willDo:^id(NSInvocation *invocation) {
        [establishedConnectionExpectation fulfill];
        return nil;
    }];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Receive Stanzas
    //

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {
        assertThat(element.name, equalTo(@"message"));
        assertThat(element.namespace, equalTo(@"jabber:client"));
    }];
    [client sendStanza:messageDocument.root];

    PXDocument *presenceDocument = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {
        assertThat(element.name, equalTo(@"presence"));
        assertThat(element.namespace, equalTo(@"jabber:client"));
    }];
    [client sendStanza:presenceDocument.root];

    PXDocument *IQDocument = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    [self.stream onDidSendElement:^(XMPPStreamStub *stream, PXElement *element) {
        assertThat(element.name, equalTo(@"iq"));
        assertThat(element.namespace, equalTo(@"jabber:client"));
    }];
    [client sendStanza:IQDocument.root];

    //
    // Disconnect Client
    //

    XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Expect client to disconnect"];
    [givenVoid([delegate clientDidDisconnect:client]) willDo:^id(NSInvocation *invocation) {
        [expectDisconnect fulfill];
        return nil;
    }];
    [client disconnect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end
