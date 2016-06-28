//
//  XMPPInBandRegistrationTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
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
        assertThat([challenge registrationForm], isA([XMPPDataForm class]));
        assertThat([[challenge registrationForm] namespace], isNot(equalTo(@"jabber:iq:register")));
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
    form.namespace = @"jabber:iq:register";

    [self prepareFormResponseWithRegistrationForm:registrationForm error:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Receive Registration"];
    [givenVoid([self.delegate streamFeature:self.feature didReceiveRegistrationChallenge:anything()]) willDo:^id(NSInvocation *i) {

        id<XMPPRegistrationChallenge> challenge = [[i mkt_arguments] lastObject];
        assertThat(challenge, conformsTo(@protocol(XMPPRegistrationChallenge)));
        assertThat([challenge registrationForm], isA([XMPPDataForm class]));
        assertThat([[challenge registrationForm] namespace], equalTo(@"jabber:iq:register"));
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

#pragma mark -

- (void)prepareFormResponseWithRegistrationForm:(PXDocument *)registrationForm error:(NSError *)error
{
    [givenVoid([self.delegate streamFeature:self.feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *request = [[invocation mkt_arguments] lastObject];

        XCTAssertEqualObjects([request.root qualifiedName], PXQN(@"jabber:client", @"iq"));
        XCTAssertEqualObjects([request.root valueForAttribute:@"type"], @"get");
        XCTAssertEqualObjects([request.root valueForAttribute:@"to"], @"example.com");
        XCTAssertNotNil([request.root valueForAttribute:@"id"]);

        XCTAssertEqual([request.root numberOfElements], 1);
        if ([request.root numberOfElements] == 1) {
            PXElement *query = [request.root elementAtIndex:0];
            XCTAssertEqualObjects([query qualifiedName], PXQN(@"jabber:iq:register", @"query"));
        }

        PXDocument *response = nil;

        if (error) {
            response = [NSError IQResponseWithError:error];
            [response.root setValue:[request.root valueForAttribute:@"id"] forAttribute:@"id"];
        } else {
            response = [self registrationResponseWithRequest:request
                                            registrationForm:registrationForm];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.feature handleDocument:response error:nil];
        });

        return nil;
    }];
}

- (PXDocument *)registrationResponseWithRequest:(PXDocument *)request
                               registrationForm:(PXDocument *)registrationForm
{
    NSString *from = [request.root valueForAttribute:@"to"];
    NSString *IDString = [request.root valueForAttribute:@"id"];

    PXDocument *response = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *iq = response.root;

    [iq setValue:from forAttribute:@"from"];
    [iq setValue:IDString forAttribute:@"id"];
    [iq setValue:@"result" forAttribute:@"type"];

    PXElement *query = [iq addElementWithName:@"query" namespace:@"jabber:iq:register" content:nil];
    [query addElementWithName:@"instructions" namespace:@"jabber:iq:register" content:@"Please register."];
    [query addElementWithName:@"username" namespace:@"jabber:iq:register" content:nil];
    [query addElementWithName:@"password" namespace:@"jabber:iq:register" content:nil];
    [query addElementWithName:@"email" namespace:@"jabber:iq:register" content:nil];

    if (registrationForm) {
        [query addElement:registrationForm.root];
    }

    return response;
}

@end
