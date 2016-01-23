//
//  XMPPWebsocketStreamTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPWebsocketStreamTests : XMPPTestCase

@end

@implementation XMPPWebsocketStreamTests

#pragma mark Tests

- (void)testOpenAndCloseStream
{
    //
    // Create stream
    //

    NSDictionary *options = @{};
    XMPPWebsocketStream *stream = [[XMPPWebsocketStream alloc] initWithHostname:@"localhost"
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

    XCTestExpectation *waitForOpen = [self expectationWithDescription:@"Open"];
    [givenVoid([delegate stream:stream didOpenToHost:equalTo(@"localhost") withStreamId:notNilValue()]) willDo:^id(NSInvocation *invocation) {
        [waitForOpen fulfill];
        return nil;
    }];
    [stream open];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Close stream and wait until the stream has closed
    //

    XCTestExpectation *waitForClose = [self expectationWithDescription:@"Close"];
    [givenVoid([delegate streamDidClose:stream]) willDo:^id(NSInvocation *invocation) {
        [waitForClose fulfill];
        return nil;
    }];
    [stream close];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Verify delegate calles
    //

    [verifyCount(delegate, times(1)) stream:stream
                              didOpenToHost:equalTo(@"localhost")
                               withStreamId:notNilValue()];

    [verifyCount(delegate, times(1)) streamDidClose:stream];
}

@end
