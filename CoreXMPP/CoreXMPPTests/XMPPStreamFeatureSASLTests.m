//
//  XMPPStreamFeatureSASLTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPStreamFeatureSASLTests : XMPPTestCase

@end

@implementation XMPPStreamFeatureSASLTests

- (void)testNameAndNamespace
{
    assertThat([XMPPStreamFeatureSASL name], equalTo(@"mechanisms"));
    assertThat([XMPPStreamFeatureSASL namespace], equalTo(XMPPStreamFeatureSASLNamespace));
}

- (void)testInitializer
{
    PXDocument *document = [self featureDocument];

    XMPPStreamFeatureSASL *feature = [[XMPPStreamFeatureSASL alloc] initWithConfiguration:document];

    assertThat(feature.mechanisms, contains(@"PLAIN", @"EXTERNAL", @"SCRAM-SHA-1", @"SCRAM-SHA-1-PLUS", nil));

    assertThatBool(feature.mandatory, isTrue());
    assertThatBool(feature.needsRestart, isTrue());
}

- (void)testSASLErrors
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"failure"
                                                         namespace:XMPPStreamFeatureSASLNamespace
                                                            prefix:nil];

    [document.root addElementWithName:@"account-disabled"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:nil];

    [document.root addElementWithName:@"text"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:@"Call 212-555-1212 for assistance."];

    NSError *error = [XMPPStreamFeatureSASL errorFromElement:document.root];

    assertThat(error, notNilValue());

    assertThat(error.domain, equalTo(XMPPStreamFeatureSASLErrorDomain));
    assertThatInteger(error.code, equalToInteger(XMPPStreamFeatureSASLErrorCodeAccountDisabled));
    assertThat([error localizedDescription], equalTo(@"Call 212-555-1212 for assistance."));
}

- (void)testUndefinedSASLError
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"failure"
                                                         namespace:XMPPStreamFeatureSASLNamespace
                                                            prefix:nil];

    [document.root addElementWithName:@"some-other-error"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:nil];

    NSError *error = [XMPPStreamFeatureSASL errorFromElement:document.root];

    assertThat(error, notNilValue());

    assertThat(error.domain, equalTo(XMPPStreamFeatureSASLErrorDomain));

    // Undefined erros should be treated as "not-authorized".
    // See: RFC 6120 - 6.5. SASL Errors
    assertThatInteger(error.code, equalToInteger(XMPPStreamFeatureSASLErrorCodeNotAuthorized));
}

- (void)testSuccessfulNegotiation
{
    // Prepare the SASL Mechanism

    SASLMechanismPLAIN *mechanism = [[SASLMechanismPLAIN alloc] init];

    __block BOOL completionSuccess;
    __block NSError *completionError;

    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Authentication completion"];

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:mechanism]) willDo:^id(NSInvocation *invocation) {
        [mechanism authenticateWithUsername:@"romeo"
                                   password:@"123"
                                 completion:^(BOOL success, NSError *error) {
                                     completionSuccess = success;
                                     completionError = error;
                                     [completionExpectation fulfill];
                                 }];
        return nil;
    }];

    mechanism.delegate = SASLDelegate;

    // Create a feature with a list of mechanisms

    PXDocument *document = [self featureDocument];
    XMPPStreamFeatureSASL *feature = [[XMPPStreamFeatureSASL alloc] initWithConfiguration:document];

    id<XMPPStreamFeatureDelegateSASL> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateSASL));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    // Always retrun a PLAIN SASL mechanism if asked by the feature

    [given([delegate SASLMechanismForStreamFeature:feature supportedMechanisms:anything()]) willReturn:mechanism];

    // The feature should ask for authentication with a simple "auth" element. If the
    // element contains the base64 encoded credentials, the 'server' response
    // with a "success" element.

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        PXElement *element = [[invocation mkt_arguments] firstObject];

        //
        // validate the request
        //

        assertThat(element.name, equalTo(@"auth"));
        assertThat(element.namespace, equalTo(XMPPStreamFeatureSASLNamespace));

        assertThat([element valueForAttribute:@"mechanism"], equalTo(@"PLAIN"));

        // base64 encode credentials for "<NUL>romeo<NUL>123" are "AHJvbWVvADEyMw=="
        assertThat(element.stringValue, equalTo(@"AHJvbWVvADEyMw=="));

        //
        // post the response
        //

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"success"
                                                             namespace:XMPPStreamFeatureSASLNamespace
                                                                prefix:nil];

        NSError *error = nil;
        BOOL success = [feature handleDocument:response error:&error];
        XCTAssertTrue(success, @"Failed to handle document: %@", [error localizedDescription]);

        return nil;
    }];

    // Let the test wait until the feature did succeed

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting successfull negotiation"];

    [givenVoid([delegate streamFeatureDidSucceedNegotiation:feature]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];

    [feature beginNegotiationWithHostname:@"localhost" options:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    [verifyCount(delegate, times(1)) SASLMechanismForStreamFeature:feature supportedMechanisms:anything()];
    [verifyCount(delegate, times(1)) streamFeatureDidSucceedNegotiation:feature];
    [verifyCount(delegate, never()) streamFeature:feature didFailNegotiationWithError:anything()];
    [verifyCount(stanzaHandler, times(1)) handleStanza:anything() completion:anything()];

    assertThatBool(completionSuccess, isTrue());
    assertThat(completionError, nilValue());
}

- (void)testFailedNegotiation
{
    // Prepare the SASL Mechanism

    SASLMechanismPLAIN *mechanism = [[SASLMechanismPLAIN alloc] init];

    __block BOOL completionSuccess;
    __block NSError *completionError;

    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Authentication completion"];

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:mechanism]) willDo:^id(NSInvocation *invocation) {
        [mechanism authenticateWithUsername:@"romeo"
                                   password:@"123"
                                 completion:^(BOOL success, NSError *error) {
                                     completionSuccess = success;
                                     completionError = error;
                                     [completionExpectation fulfill];
                                 }];
        return nil;
    }];

    mechanism.delegate = SASLDelegate;

    // Create a feature with a list of mechanisms

    PXDocument *document = [self featureDocument];
    XMPPStreamFeatureSASL *feature = [[XMPPStreamFeatureSASL alloc] initWithConfiguration:document];

    id<XMPPStreamFeatureDelegateSASL> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateSASL));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    // Always retrun a PLAIN SASL mechanism if asked by the feature

    [given([delegate SASLMechanismForStreamFeature:feature supportedMechanisms:anything()]) willReturn:mechanism];

    // The feature should ask for authentication with a simple "auth" element.
    // In this case the credentials are treated as invalid and the 'server'
    // response with an "failure" with the error 'not-authorized'.

    [givenVoid([stanzaHandler handleStanza:anything() completion:anything()]) willDo:^id(NSInvocation *invocation) {

        //
        // post the response
        //

        PXDocument *response = [[PXDocument alloc] initWithElementName:@"failure"
                                                             namespace:XMPPStreamFeatureSASLNamespace
                                                                prefix:nil];

        [response.root addElementWithName:@"not-authorized"
                                namespace:XMPPStreamFeatureSASLNamespace
                                  content:nil];

        NSError *error = nil;
        BOOL success = [feature handleDocument:response error:&error];
        XCTAssertTrue(success, @"Failed to handle document: %@", [error localizedDescription]);

        return nil;
    }];

    // Let the test wait until the feature did fail

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting failed negotiation"];

    [givenVoid([delegate streamFeature:feature didFailNegotiationWithError:anything()]) willDo:^id(NSInvocation *invocation) {

        NSError *error = [[invocation mkt_arguments] lastObject];

        assertThat(error, notNilValue());
        assertThat(error.domain, equalTo(XMPPStreamFeatureSASLErrorDomain));
        assertThatInteger(error.code, equalToInteger(XMPPStreamFeatureSASLErrorCodeNotAuthorized));

        [expectation fulfill];
        return nil;
    }];

    [feature beginNegotiationWithHostname:@"localhost" options:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    [verifyCount(delegate, times(1)) SASLMechanismForStreamFeature:feature supportedMechanisms:anything()];
    [verifyCount(delegate, never()) streamFeatureDidSucceedNegotiation:feature];
    [verifyCount(delegate, times(1)) streamFeature:feature didFailNegotiationWithError:anything()];
    [verifyCount(stanzaHandler, times(1)) handleStanza:anything() completion:anything()];

    assertThatBool(completionSuccess, isFalse());
    assertThat(completionError.domain, equalTo(XMPPStreamFeatureSASLErrorDomain));
}

- (void)testAbortedNegotiation
{
    // Prepare the SASL Mechanism

    SASLMechanismPLAIN *mechanism = [[SASLMechanismPLAIN alloc] init];

    __block BOOL completionSuccess;
    __block NSError *completionError;

    id<SASLMechanismDelegate> SASLDelegate = mockProtocol(@protocol(SASLMechanismDelegate));
    [givenVoid([SASLDelegate SASLMechanismNeedsCredentials:mechanism]) willDo:^id(NSInvocation *invocation) {
        [mechanism authenticateWithUsername:nil
                                   password:@"123"
                                 completion:^(BOOL success, NSError *error) {
                                     completionSuccess = success;
                                     completionError = error;
                                 }]; // Missing credentials will abort the negotiation
        return nil;
    }];

    mechanism.delegate = SASLDelegate;

    // Create a feature with a list of mechanisms

    PXDocument *document = [self featureDocument];
    XMPPStreamFeatureSASL *feature = [[XMPPStreamFeatureSASL alloc] initWithConfiguration:document];

    id<XMPPStreamFeatureDelegateSASL> delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateSASL));
    feature.delegate = delegate;

    id<XMPPStanzaHandler> stanzaHandler = mockProtocol(@protocol(XMPPStanzaHandler));
    feature.stanzaHandler = stanzaHandler;

    // Always retrun a PLAIN SASL mechanism if asked by the feature

    [given([delegate SASLMechanismForStreamFeature:feature supportedMechanisms:anything()]) willReturn:mechanism];

    // Let the test wait until the feature did abort

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expecting aborted negotiation"];

    [givenVoid([delegate streamFeature:feature didFailNegotiationWithError:anything()]) willDo:^id(NSInvocation *invocation) {

        NSError *error = [[invocation mkt_arguments] lastObject];

        assertThat(error, notNilValue());
        assertThat(error.domain, equalTo(XMPPStreamFeatureSASLErrorDomain));
        assertThatInteger(error.code, equalToInteger(XMPPStreamFeatureSASLErrorCodeAborted));

        [expectation fulfill];
        return nil;
    }];

    [feature beginNegotiationWithHostname:@"localhost" options:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    [verifyCount(delegate, times(1)) SASLMechanismForStreamFeature:feature supportedMechanisms:anything()];
    [verifyCount(delegate, never()) streamFeatureDidSucceedNegotiation:feature];
    [verifyCount(delegate, times(1)) streamFeature:feature didFailNegotiationWithError:anything()];

    [verifyCount(stanzaHandler, never()) handleStanza:anything() completion:anything()];

    assertThatBool(completionSuccess, isFalse());
    assertThat(completionError.domain, equalTo(SASLMechanismErrorDomain));
}

#pragma mark -

- (PXDocument *)featureDocument
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"mechanisms"
                                                         namespace:XMPPStreamFeatureSASLNamespace
                                                            prefix:nil];

    [document.root addElementWithName:@"mechanism"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:@"PLAIN"];

    [document.root addElementWithName:@"mechanism"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:@"EXTERNAL"];

    [document.root addElementWithName:@"mechanism"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:@"SCRAM-SHA-1"];

    [document.root addElementWithName:@"mechanism"
                            namespace:XMPPStreamFeatureSASLNamespace
                              content:@"SCRAM-SHA-1-PLUS"];

    return document;
}

@end
