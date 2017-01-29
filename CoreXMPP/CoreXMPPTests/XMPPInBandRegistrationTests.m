//
//  XMPPInBandRegistrationTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
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

#import "XMPPInBandRegistration.h"
#import "XMPPTestCase.h"

@interface XMPPInBandRegistrationTests : XMPPTestCase
@property (nonatomic, strong) XMPPStreamFeature *feature;
@property (nonatomic, strong) id<XMPPStreamFeatureDelegateInBandRegistration> delegate;
@end

@implementation XMPPInBandRegistrationTests

- (void)setUp
{
    [super setUp];

    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"register"
                                                              namespace:@"http://jabber.org/features/iq-register"
                                                                 prefix:nil];
    self.feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    self.delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegateInBandRegistration));
    self.feature.delegate = self.delegate;
}

#pragma mark Test

- (void)testRequestRegistrationWithFields
{
    [self prepareFormResponseWithRegistrationForm:nil error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Receive Registration"];
    [givenVoid([self.delegate streamFeature:self.feature didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {

        id<XMPPRegistrationChallenge> challenge = [[i mkt_arguments] lastObject];
        assertThat(challenge, conformsTo(@protocol(XMPPRegistrationChallenge)));
        assertThat([[challenge registrationForm] root], isA([XMPPDataForm class]));
        assertThat([(XMPPDataForm *)[[challenge registrationForm] root] identifier], isNot(equalTo(@"jabber:iq:register")));
        [expectation fulfill];
        return nil;
    }];

    [self.feature beginNegotiationWithHostname:@"example.com"
                                       options:@{}];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRequestRegistrationWithForm
{
    PXDocument *registrationForm = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)registrationForm.root;
    form.identifier = @"jabber:iq:register";

    [self prepareFormResponseWithRegistrationForm:registrationForm error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Receive Registration"];
    [givenVoid([self.delegate streamFeature:self.feature didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {

        id<XMPPRegistrationChallenge> challenge = [[i mkt_arguments] lastObject];
        assertThat(challenge, conformsTo(@protocol(XMPPRegistrationChallenge)));
        assertThat([[challenge registrationForm] root], isA([XMPPDataForm class]));
        assertThat([(XMPPDataForm *)[[challenge registrationForm] root] identifier], equalTo(@"jabber:iq:register"));
        [expectation fulfill];
        return nil;
    }];

    [self.feature beginNegotiationWithHostname:@"example.com"
                                       options:@{}];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRequestRegistrationWithError
{
    NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                         code:XMPPStanzaErrorCodeNotAllowed
                                     userInfo:nil];

    [self prepareFormResponseWithRegistrationForm:nil error:error];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Receive Error"];
    [givenVoid([self.delegate streamFeature:self.feature didFailNegotiationWithError:anything()]) willDo:^id(NSInvocation *i) {
        [expectation fulfill];
        return nil;
    }];

    [self.feature beginNegotiationWithHostname:@"example.com"
                                       options:@{}];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubmitRegistrationWithFields
{
    [[self prepareFormResponseWithRegistrationForm:nil error:nil] willDo:^id(NSInvocation *invocation) {

        PXDocument *request = [[invocation mkt_arguments] lastObject];

        XCTAssertEqualObjects([request.root qualifiedName], PXQN(@"jabber:client", @"iq"));
        XCTAssertEqualObjects([request.root valueForAttribute:@"type"], @"set");
        XCTAssertEqualObjects([request.root valueForAttribute:@"to"], @"example.com");
        XCTAssertNotNil([request.root valueForAttribute:@"id"]);

        NSDictionary *ns = @{ @"register" : @"jabber:iq:register",
                              @"data" : @"jabber:x:data" };

        PXElement *formElement = [[request.root nodesForXPath:@"./register:query/data:x" usingNamespaces:ns] firstObject];
        XCTAssertNil(formElement);

        PXElement *usernameElement = [[request.root nodesForXPath:@"./register:query/register:username" usingNamespaces:ns] firstObject];
        XCTAssertNotNil(usernameElement);

        PXElement *passwordElement = [[request.root nodesForXPath:@"./register:query/register:password" usingNamespaces:ns] firstObject];
        XCTAssertNotNil(passwordElement);

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
            PXElement *iq = response.root;
            [iq setValue:@"result" forAttribute:@"type"];
            [iq setValue:[request.root valueForAttribute:@"id"] forAttribute:@"id"];
            [iq setValue:[request.root valueForAttribute:@"to"] forAttribute:@"from"];
            [self.feature handleDocument:response error:nil];
        });

        return nil;
    }];

    __block id<XMPPRegistrationChallenge> challenge = nil;
    XCTestExpectation *expectationChallenge = [self expectationWithDescription:@"Receive Challenge"];
    [givenVoid([self.delegate streamFeature:self.feature didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {
        challenge = [[i mkt_arguments] lastObject];
        [expectationChallenge fulfill];
        return nil;
    }];
    [self.feature beginNegotiationWithHostname:@"example.com" options:@{}];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XMPPDataForm *form = (XMPPDataForm *)[[challenge registrationForm] root];
    form.type = XMPPDataFormTypeSubmit;

    [[form fieldWithIdentifier:@"username"] setValue:JID(@"romeo@example.com")];
    [[form fieldWithIdentifier:@"password"] setValue:@"123"];
    [[form fieldWithIdentifier:@"email"] setValue:@"romeo@example.com"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Submit"];
    [challenge submitRegistration:form.document
                       completion:^(BOOL success, NSError *error) {
                           XCTAssertTrue(success);
                           XCTAssertNil(error);
                           [expectation fulfill];
                       }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubmitRegistrationWithForm
{
    PXDocument *registrationForm = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    [(XMPPDataForm *)(registrationForm.root) setIdentifier:@"jabber:iq:register"];

    [[self prepareFormResponseWithRegistrationForm:registrationForm error:nil] willDo:^id(NSInvocation *invocation) {

        PXDocument *request = [[invocation mkt_arguments] lastObject];

        XCTAssertEqualObjects([request.root qualifiedName], PXQN(@"jabber:client", @"iq"));
        XCTAssertEqualObjects([request.root valueForAttribute:@"type"], @"set");
        XCTAssertEqualObjects([request.root valueForAttribute:@"to"], @"example.com");
        XCTAssertNotNil([request.root valueForAttribute:@"id"]);

        NSDictionary *ns = @{ @"register" : @"jabber:iq:register",
                              @"data" : @"jabber:x:data" };

        PXElement *formElement = [[request.root nodesForXPath:@"./register:query/data:x" usingNamespaces:ns] firstObject];
        XCTAssertNotNil(formElement);

        dispatch_async(dispatch_get_main_queue(), ^{
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
            PXElement *iq = response.root;
            [iq setValue:@"result" forAttribute:@"type"];
            [iq setValue:[request.root valueForAttribute:@"id"] forAttribute:@"id"];
            [iq setValue:[request.root valueForAttribute:@"to"] forAttribute:@"from"];
            [self.feature handleDocument:response error:nil];
        });

        return nil;
    }];

    __block id<XMPPRegistrationChallenge> challenge = nil;
    XCTestExpectation *expectationChallenge = [self expectationWithDescription:@"Receive Challenge"];
    [givenVoid([self.delegate streamFeature:self.feature didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {
        challenge = [[i mkt_arguments] lastObject];
        [expectationChallenge fulfill];
        return nil;
    }];
    [self.feature beginNegotiationWithHostname:@"example.com" options:@{}];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XMPPDataForm *form = (XMPPDataForm *)[[challenge registrationForm] root];
    form.type = XMPPDataFormTypeSubmit;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Submit"];
    [challenge submitRegistration:form.document
                       completion:^(BOOL success, NSError *error) {
                           XCTAssertTrue(success);
                           XCTAssertNil(error);
                           [expectation fulfill];
                       }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubmitRegistrationWithError
{
    [[self prepareFormResponseWithRegistrationForm:nil error:nil] willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];

        XMPPIQStanza *request = (XMPPIQStanza *)document.root;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                                 code:XMPPStanzaErrorCodeNotAllowed
                                             userInfo:nil];
            XMPPIQStanza *response = [request responseWithError:error];
            [self.feature handleDocument:response.document error:nil];
        });

        return nil;
    }];

    __block id<XMPPRegistrationChallenge> challenge = nil;
    XCTestExpectation *expectationChallenge = [self expectationWithDescription:@"Receive Challenge"];
    [givenVoid([self.delegate streamFeature:self.feature didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {
        challenge = [[i mkt_arguments] lastObject];
        [expectationChallenge fulfill];
        return nil;
    }];
    [self.feature beginNegotiationWithHostname:@"example.com" options:@{}];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XMPPDataForm *form = (XMPPDataForm *)[[challenge registrationForm] root];
    form.type = XMPPDataFormTypeSubmit;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Submit"];
    [challenge submitRegistration:form.document
                       completion:^(BOOL success, NSError *error) {
                           XCTAssertFalse(success);
                           XCTAssertNotNil(error);
                           [expectation fulfill];
                       }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark -

- (MKTOngoingStubbing *)prepareFormResponseWithRegistrationForm:(PXDocument *)registrationForm error:(NSError *)error
{
    return [givenVoid([self.delegate streamFeature:self.feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];
        XMPPIQStanza *request = (XMPPIQStanza *)document.root;

        XCTAssertEqualObjects([request qualifiedName], PXQN(@"jabber:client", @"iq"));
        XCTAssertEqualObjects([request valueForAttribute:@"type"], @"get");
        XCTAssertEqualObjects([request valueForAttribute:@"to"], @"example.com");
        XCTAssertNotNil([request valueForAttribute:@"id"]);

        XCTAssertEqual([request numberOfElements], 1);
        if ([request numberOfElements] == 1) {
            PXElement *query = [request elementAtIndex:0];
            XCTAssertEqualObjects([query qualifiedName], PXQN(@"jabber:iq:register", @"query"));
        }

        XMPPIQStanza *response = nil;

        if (error) {
            response = [request responseWithError:error];
        } else {
            response = [self registrationResponseWithRequest:request
                                            registrationForm:registrationForm];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.feature handleDocument:response.document error:nil];
        });

        return nil;
    }];
}

- (XMPPIQStanza *)registrationResponseWithRequest:(XMPPIQStanza *)request
                                 registrationForm:(PXDocument *)registrationForm
{
    XMPPIQStanza *iq = [request response];

    PXElement *query = [iq addElementWithName:@"query" namespace:@"jabber:iq:register" content:nil];
    [query addElementWithName:@"instructions" namespace:@"jabber:iq:register" content:@"Please register."];
    [query addElementWithName:@"username" namespace:@"jabber:iq:register" content:nil];
    [query addElementWithName:@"password" namespace:@"jabber:iq:register" content:nil];
    [query addElementWithName:@"email" namespace:@"jabber:iq:register" content:nil];

    if (registrationForm) {
        [query addElement:registrationForm.root];
    }

    return iq;
}

@end
