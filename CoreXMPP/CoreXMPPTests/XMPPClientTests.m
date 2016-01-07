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

- (void)testConnectClientWithoutFeatureNegotiation
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
    
    XCTestExpectation *establishedConnectionExpectation = [self expectationWithDescription:@"Expect espablished Connection"];
    
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

@end
