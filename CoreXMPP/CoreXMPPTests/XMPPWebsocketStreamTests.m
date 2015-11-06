//
//  XMPPWebsocketStreamTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import <CoreXMPP/CoreXMPP.h>

@interface XMPPWebsocketStreamTests : XCTestCase

@end

@implementation XMPPWebsocketStreamTests

#pragma mark Tests

- (void)testStreamManagement
{
    //
    // Create stream
    //
    
    NSDictionary *options = @{ XMPPWebsocketStreamURLKey: [NSURL URLWithString:@"ws://localhost:5280/xmpp"] };
    XMPPWebsocketStream *stream = [[XMPPWebsocketStream alloc] initWithHostname:@"localhost"
                                                                       language:@"en"
                                                                        options:options];
    XCTAssertNotNil(stream);
 
    //
    // Set delegate
    //
    
    id<XMPPStreamDelegate> delegate = mockProtocol(@protocol(XMPPStreamDelegate));
    stream.delegate = delegate;
    
    //
    // Open stream and wait until the stream has opened
    //
    
    [self keyValueObservingExpectationForObject:stream
                                        keyPath:@"state"
                                  expectedValue:@(XMPPStreamStateOpen)];
    
    [stream open];
    
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    
    //
    // Verify delegate calles
    //
    
    [verifyCount(delegate, times(1)) stream:stream
                              didOpenToHost:equalTo(@"localhost")
                               withStreamId:notNilValue()];
    
    delegate = mockProtocol(@protocol(XMPPStreamDelegate));
    stream.delegate = delegate;
    
    //
    // Close stream and wait until the stream has closed
    //
    
    [self keyValueObservingExpectationForObject:stream
                                        keyPath:@"state"
                                  expectedValue:@(XMPPStreamStateClosed)];
    
    [stream close];
    
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    
    //
    // Verify delegate calles
    //
    
    [verifyCount(delegate, times(1)) streamDidClose:stream];
}

@end
