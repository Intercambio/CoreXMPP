//
//  XMPPInBandRegistrationTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPInBandRegistrationTests : XMPPTestCase
@property (nonatomic, strong) XMPPStreamFeature *feature;
@property (nonatomic, strong) id<XMPPStreamFeatureDelegate> delegate;
@end

@implementation XMPPInBandRegistrationTests

- (void)setUp
{
    [super setUp];
    
    PXDocument *configuration = [[PXDocument alloc] initWithElementName:@"register"
                                                              namespace:@"http://jabber.org/features/iq-register"
                                                                 prefix:nil];
    self.feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
    self.delegate = mockProtocol(@protocol(XMPPStreamFeatureDelegate));
    self.feature.delegate = self.delegate;
}

#pragma mark Test

- (void)testRequestRegistrationFields
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Begin Negotiation"];
    [givenVoid([self.delegate streamFeature:self.feature handleDocument:anything()]) willDo:^id(NSInvocation *invocation) {
        
        PXDocument *document = [[invocation mkt_arguments] lastObject];
        
        XCTAssertEqualObjects([document.root qualifiedName], PXQN(@"jabber:client", @"iq"));
        XCTAssertEqualObjects([document.root valueForAttribute:@"type"], @"get");
        XCTAssertEqualObjects([document.root valueForAttribute:@"to"], @"example.com");
        
        XCTAssertEqual([document.root numberOfElements], 1);
        if ([document.root numberOfElements] == 1) {
            PXElement *query = [document.root elementAtIndex:0];
            XCTAssertEqualObjects([query qualifiedName], PXQN(@"jabber:iq:register", @"query"));
        }
        
        [expectation fulfill];
        return nil;
    }];
    
    [self.feature beginNegotiationWithHostname:@"example.com"
                                       options:@{}];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
