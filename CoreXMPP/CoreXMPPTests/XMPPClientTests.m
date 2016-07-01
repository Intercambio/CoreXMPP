//
//  XMPPClientTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPClientTests : XMPPTestCase
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

- (void)testRegisterAccount
{
    [DDLog setLevel:DDLogLevelAll forClassWithName:@"XMPPClient"];

    NSString *username = [[NSUUID UUID] UUIDString];
    NSString *password = @"123";

    NSDictionary *options = @{ XMPPClientOptionsResourceKey : @"bar" };

    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:options];
    client.needsRegistration = YES;

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    __block id<XMPPRegistrationChallenge> challenge = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Registration Challenge"];
    [givenVoid([delegate client:client didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {
        challenge = [[i mkt_arguments] lastObject];
        [expectation fulfill];
        return nil;
    }];

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    client.SASLDelegate = SASLDelegate;

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:username password:password completion:nil];
        return nil;
    }];

    [client connect];

    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    XCTAssertNotNil(challenge);
    if (challenge) {

        [self keyValueObservingExpectationForObject:client
                                            keyPath:@"state"
                                      expectedValue:@(XMPPClientStateConnected)];

        PXDocument *document = [challenge registrationForm];

        XMPPDataForm *form = (XMPPDataForm *)[document root];
        form.type = XMPPDataFormTypeSubmit;

        XMPPDataFormField *usernameField = [form fieldWithIdentifier:@"username"];
        XMPPDataFormField *passwordField = [form fieldWithIdentifier:@"password"];

        usernameField.value = username;
        passwordField.value = password;

        XCTestExpectation *expectation = [self expectationWithDescription:@"Register"];

        [challenge submitRegistration:document
                           completion:^(BOOL success, NSError *error) {
                               XCTAssertTrue(success);
                               XCTAssertNil(error);
                               [expectation fulfill];
                           }];

        [self waitForExpectationsWithTimeout:10.0 handler:nil];
    }
}

- (void)testConnectToServer
{
    NSDictionary *options = @{ XMPPClientOptionsResourceKey : @"bar" };

    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:options];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    client.SASLDelegate = SASLDelegate;

    id<XMPPConnectionDelegate> stanzaHandler = mockProtocol(@protocol(XMPPConnectionDelegate));
    client.connectionDelegate = stanzaHandler;

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:@"romeo" password:@"123" completion:nil];
        return nil;
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Ping .o0o. Pong
    //

    NSString *pingIQId = [[NSUUID UUID] UUIDString];

    PXDocument *ping = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    [ping.root setValue:pingIQId forAttribute:@"id"];
    [ping.root setValue:@"get" forAttribute:@"type"];
    [ping.root setValue:@"localhost" forAttribute:@"to"];
    [ping.root addElementWithName:@"ping" namespace:@"urn:xmpp:ping" content:nil];
    [client handleDocument:ping
                completion:^(NSError *error){

                }];

    [givenVoid([stanzaHandler processPendingDocuments:anything()]) willDo:^id(NSInvocation *invocation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];
            if (_completion) {
                _completion(nil);
            }
        });
        return nil;
    }];

    XCTestExpectation *waitForPong = [self expectationWithDescription:@"Wait for Pong"];
    [givenVoid([stanzaHandler handleDocument:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {
        PXDocument *pong = [[invocation mkt_arguments] firstObject];
        void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_completion) {
                _completion(nil);
            }
            if ([pong.root isKindOfClass:[PXElement class]] &&
                [[pong.root valueForAttribute:@"id"] isEqualToString:pingIQId]) {
                [waitForPong fulfill];
            }
        });
        return nil;
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    //
    // Send Message
    //

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    [messageDocument.root setValue:@"localhost" forAttribute:@"to"];

    XCTestExpectation *expectMessageAck = [self expectationWithDescription:@"Expect Ack"];
    [client handleDocument:messageDocument
                completion:^(NSError *error) {
                    [expectMessageAck fulfill];
                }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Disconnect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];
    [client disconnect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testResumeClient
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:nil];

    id<XMPPClientDelegate> delegate = nil;

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    client.SASLDelegate = SASLDelegate;

    id<XMPPConnectionDelegate> connectionDelegate = mockProtocol(@protocol(XMPPConnectionDelegate));
    client.connectionDelegate = connectionDelegate;

    [givenVoid([connectionDelegate processPendingDocuments:anything()]) willDo:^id(NSInvocation *invocation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];
            if (_completion) {
                _completion(nil);
            }
        });
        return nil;
    }];

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:@"romeo" password:@"123" completion:nil];
        return nil;
    }];

    //
    // Connect
    //

    delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [[givenVoid([delegate clientDidConnect:client resumedStream:NO]) withMatcher:isFalse() forArgument:1] willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Suspend
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];
    [client suspend];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Resume
    //

    delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    expectation = [self expectationWithDescription:@"Wait for Connect"];
    [[givenVoid([delegate clientDidConnect:client resumedStream:YES]) withMatcher:isTrue() forArgument:1] willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark -
#pragma mark Connection

- (void)testConnectClient
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<XMPPConnectionDelegate> connectionDelegate = mockProtocol(@protocol(XMPPConnectionDelegate));
    client.connectionDelegate = connectionDelegate;

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {

        // Send an empty feature element from the receiving entity to
        // the initiating entity after the stream has been opend.

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveDocument:doc];
    }];

    //
    // Connect & Disconnect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Disconnect"];
    [givenVoid([delegate clientDidDisconnect:client]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client disconnect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify
    //

    [verifyCount(delegate, times(1)) clientDidConnect:client resumedStream:NO];
    [verifyCount(delegate, times(1)) clientDidDisconnect:client];

    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateConnecting) forArgument:1] client:client didChangeState:XMPPClientStateConnecting];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateEstablished) forArgument:1] client:client didChangeState:XMPPClientStateEstablished];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateNegotiating) forArgument:1] client:client didChangeState:XMPPClientStateNegotiating];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateConnected) forArgument:1] client:client didChangeState:XMPPClientStateConnected];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateDisconnecting) forArgument:1] client:client didChangeState:XMPPClientStateDisconnecting];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateDisconnected) forArgument:1] client:client didChangeState:XMPPClientStateDisconnected];
}

- (void)testFailedConnectionWithXMPPStreamError
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<XMPPConnectionDelegate> connectionDelegate = mockProtocol(@protocol(XMPPConnectionDelegate));
    client.connectionDelegate = connectionDelegate;

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"error"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        [doc.root addElementWithName:@"host-unknown"
                           namespace:@"urn:ietf:params:xml:ns:xmpp-streams"
                             content:nil];

        [stream receiveDocument:doc];
        [stream closeByPeer];
    }];

    //
    // Connect (with stream error)
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Error"];
    [givenVoid([delegate client:client didFailWithError:anything()]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify
    //

    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateConnecting) forArgument:1] client:client didChangeState:XMPPClientStateConnecting];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateDisconnected) forArgument:1] client:client didChangeState:XMPPClientStateDisconnected];

    [verifyCount(delegate, never()) clientDidConnect:client resumedStream:NO];
    [verifyCount(delegate, never()) clientDidDisconnect:client];

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verify(delegate) client:client didFailWithError:(id)captor];

    NSError *error = [captor value];
    assertThat(error.domain, equalTo(XMPPStreamErrorDomain));
    assertThatInteger(error.code, equalToInteger(XMPPStreamErrorCodeHostUnknown));
}

- (void)testFailedConnectionWithError
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    //
    // Send Features (after stream did open)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        NSError *error = [NSError errorWithDomain:@"testUnderlyingStreamErrors" code:123 userInfo:nil];
        [stream failWithError:error];
    }];

    //
    // Connect (with error)
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Error"];
    [givenVoid([delegate client:client didFailWithError:anything()]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Error
    //

    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateConnecting) forArgument:1] client:client didChangeState:XMPPClientStateConnecting];
    [[verifyCount(delegate, times(1)) withMatcher:equalToInteger(XMPPClientStateDisconnected) forArgument:1] client:client didChangeState:XMPPClientStateDisconnected];

    [verifyCount(delegate, never()) clientDidConnect:client resumedStream:NO];
    [verifyCount(delegate, never()) clientDidDisconnect:client];

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verify(delegate) client:client didFailWithError:(id)captor];

    NSError *error = [captor value];
    assertThat(error.domain, equalTo(@"testUnderlyingStreamErrors"));

    assertThatInteger(client.numberOfConnectionAttempts, equalToInteger(1));
    assertThat(client.recentError.domain, equalTo(@"testUnderlyingStreamErrors"));
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

    NSError *error = [NSError streamErrorFromElement:doc.root];

    assertThat(error, notNilValue());
    assertThat(error.domain, equalTo(XMPPStreamErrorDomain));
    assertThatInteger(error.code, equalToInteger(XMPPStreamErrorCodeSystemShutdown));
    assertThat([error localizedDescription], equalTo(@"Giving up!"));
    assertThat([error.userInfo objectForKey:XMPPErrorXMLDocumentKey], notNilValue());
}

#pragma mark General Feature Negotiation

- (void)testVoluntaryFeatureWithoutRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;

        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [givenVoid([delegate clientDidConnect:client resumedStream:NO]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:(id)captor];

    XMPPStreamFeature *feature = [captor value];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testVoluntaryFeatureWithRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Send Features (after stream reset)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        [stream receiveDocument:doc];
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [givenVoid([delegate clientDidConnect:client resumedStream:NO]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:(id)captor];

    XMPPStreamFeature *feature = [captor value];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testVoluntaryFeatureWithFailure
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Feature (failure)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send failure response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"failure"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [givenVoid([delegate clientDidConnect:client resumedStream:NO]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [verifyCount(delegate, never()) client:client didFailToNegotiateFeature:anything() withError:anything()];
    [verifyCount(delegate, never()) client:client didNegotiateFeature:anything()];
}

- (void)testMandatoryFeatureWithoutRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [givenVoid([delegate clientDidConnect:client resumedStream:NO]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:(id)captor];

    XMPPStreamFeature *feature = [captor value];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testMandatoryFeatureWithRestart
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Feature (success)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Send Features (after stream reset)
    //

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];

        [stream receiveDocument:doc];
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [givenVoid([delegate clientDidConnect:client resumedStream:NO]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiation
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(1)) client:client didNegotiateFeature:(id)captor];

    XMPPStreamFeature *feature = [captor value];
    assertThat([[feature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[feature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testMandatoryFeatureWithFailure
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Feature (failure)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send failure response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"failure"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Connect (failure; stream will close)
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Disconnect"];
    [givenVoid([delegate client:client didFailWithError:notNilValue()]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
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
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    client.SASLDelegate = SASLDelegate;

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:@"romeo" password:@"123" completion:nil];
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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate SASL
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"auth"));
        assertThat(element.namespace, equalTo(@"urn:ietf:params:xml:ns:xmpp-sasl"));

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"urn:ietf:params:xml:ns:xmpp-sasl"
                                                                prefix:nil];
        [stream receiveDocument:response];
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

        [stream receiveDocument:doc];
    }];

    //
    // Negotiate Test Feature (success)
    //

    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"begin"));
        assertThat(element.namespace, equalTo(@"http://example.com/"));

        // Send success response

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:@"http://example.com/"
                                                                prefix:nil];
        [stream receiveDocument:response];
    }];

    //
    // Connect
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for Connect"];
    [givenVoid([delegate clientDidConnect:client resumedStream:NO]) willDo:^id(NSInvocation *inv) {
        [expectation fulfill];
        return nil;
    }];

    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Negotiated Features
    //

    HCArgumentCaptor *captor = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, times(2)) client:client didNegotiateFeature:(id)captor];

    XMPPStreamFeature *SASLFeature = [[captor allValues] firstObject];
    assertThat([[SASLFeature class] name], equalTo([XMPPStreamFeatureSASL name]));
    assertThat([[SASLFeature class] namespace], equalTo([XMPPStreamFeatureSASL namespace]));

    XMPPStreamFeature *TESTFeature = [[captor allValues] lastObject];
    assertThat([[TESTFeature class] name], equalTo([XMPPStreamFeatureStub name]));
    assertThat([[TESTFeature class] namespace], equalTo([XMPPStreamFeatureStub namespace]));
}

- (void)testUnsupportedSASLMechanism
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    client.SASLDelegate = SASLDelegate;

    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:anything()]) willDo:^id(NSInvocation *invocation) {
        SASLMechanismPLAIN *mechanism = [[invocation mkt_arguments] firstObject];
        [mechanism authenticateWithUsername:@"romeo" password:@"123" completion:nil];
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

        [stream receiveDocument:doc];
    }];

    //
    // Connect (failure; stream will close)
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [verify(delegate) client:client didFailToNegotiateFeature:anything() withError:anything()];
}

- (void)testPreferredSASLMechanismsNotSupported
{
    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{ XMPPClientOptionsPreferedSASLMechanismsKey : @[ @"SCRAM-SHA-1" ] }
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    client.SASLDelegate = SASLDelegate;

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

        [stream receiveDocument:doc];
    }];

    //
    // Connect (failure; stream will close)
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];
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
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<XMPPConnectionDelegate> connectionDelegate = mockProtocol(@protocol(XMPPConnectionDelegate));
    client.connectionDelegate = connectionDelegate;

    [givenVoid([connectionDelegate processPendingDocuments:anything()]) willDo:^id(NSInvocation *invocation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];
            if (_completion) {
                _completion(nil);
            }
        });
        return nil;
    }];

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveDocument:doc];
    }];

    //
    // Connect Client
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Receive Stanzas
    //

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    [messageDocument.root setStringValue:@"1"];
    [self.stream receiveDocument:messageDocument];

    PXDocument *presenceDocument = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    [presenceDocument.root setStringValue:@"2"];
    [self.stream receiveDocument:presenceDocument];

    PXDocument *IQDocument = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    [IQDocument.root setStringValue:@"3"];
    [self.stream receiveDocument:IQDocument];

    //
    // Receive Unsupported Element
    //

    PXDocument *document = [[PXDocument alloc] initWithElementName:@"foo" namespace:@"http://example.com/bar" prefix:nil];
    [document.root setStringValue:@"x"];
    [self.stream receiveDocument:document];

    //
    // Disconnect Client
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];
    [client disconnect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Verify Stanzas
    //

    HCArgumentCaptor *captoredDocuments = [[HCArgumentCaptor alloc] init];
    [verifyCount(connectionDelegate, atLeastOnce()) handleDocument:(id)captoredDocuments completion:anything()];

    NSArray *documents = [captoredDocuments allValues];
    assertThat(documents, hasCountOf(3));

    if ([documents count] == 3) {
        PXDocument *document = nil;

        document = documents[0];
        assertThat(document.root.name, equalTo(@"message"));
        assertThat(document.root.namespace, equalTo(@"jabber:client"));
        assertThat(document.root.stringValue, equalTo(@"1"));

        document = documents[1];
        assertThat(document.root.name, equalTo(@"presence"));
        assertThat(document.root.namespace, equalTo(@"jabber:client"));
        assertThat(document.root.stringValue, equalTo(@"2"));

        document = documents[2];
        assertThat(document.root.name, equalTo(@"iq"));
        assertThat(document.root.namespace, equalTo(@"jabber:client"));
        assertThat(document.root.stringValue, equalTo(@"3"));
    }

    //
    // Verify Unsupported Documents
    //

    captoredDocuments = [[HCArgumentCaptor alloc] init];
    [verifyCount(delegate, atLeastOnce()) client:client didReceiveUnsupportedDocument:(id)captoredDocuments];

    documents = [captoredDocuments allValues];
    assertThat(documents, hasCountOf(1));

    document = [documents firstObject];
    assertThat(document.root.name, equalTo(@"foo"));
    assertThat(document.root.namespace, equalTo(@"http://example.com/bar"));
    assertThat(document.root.stringValue, equalTo(@"x"));
}

- (void)testSendStanzas
{
    //
    // Prepare Client and Delegate
    //

    XMPPClient *client = [[XMPPClient alloc] initWithHostname:@"localhost"
                                                      options:@{}
                                                       stream:self.stream];

    id<XMPPClientDelegate> delegate = mockProtocol(@protocol(XMPPClientDelegate));
    client.delegate = delegate;

    id<XMPPConnectionDelegate> connectionDelegate = mockProtocol(@protocol(XMPPConnectionDelegate));
    client.connectionDelegate = connectionDelegate;

    [givenVoid([connectionDelegate processPendingDocuments:anything()]) willDo:^id(NSInvocation *invocation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^_completion)(NSError *error) = [[invocation mkt_arguments] lastObject];
            if (_completion) {
                _completion(nil);
            }
        });
        return nil;
    }];

    [self.stream onDidOpen:^(XMPPStreamStub *stream) {
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"features"
                                                        namespace:@"http://etherx.jabber.org/streams"
                                                           prefix:@"stream"];
        [stream receiveDocument:doc];
    }];

    //
    // Connect Client
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateConnected)];
    [client connect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    //
    // Receive Stanzas
    //

    PXDocument *messageDocument = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"message"));
        assertThat(element.namespace, equalTo(@"jabber:client"));
    }];
    [client handleDocument:messageDocument completion:nil];

    PXDocument *presenceDocument = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"presence"));
        assertThat(element.namespace, equalTo(@"jabber:client"));
    }];
    [client handleDocument:presenceDocument completion:nil];

    PXDocument *IQDocument = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    [self.stream onDidSendDocument:^(XMPPStreamStub *stream, PXDocument *document) {

        PXElement *element = document.root;
        assertThat(element.name, equalTo(@"iq"));
        assertThat(element.namespace, equalTo(@"jabber:client"));
    }];
    [client handleDocument:IQDocument completion:nil];

    //
    // Disconnect Client
    //

    [self keyValueObservingExpectationForObject:client
                                        keyPath:@"state"
                                  expectedValue:@(XMPPClientStateDisconnected)];
    [client disconnect];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end
