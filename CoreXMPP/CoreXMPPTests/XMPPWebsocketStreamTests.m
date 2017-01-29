//
//  XMPPWebsocketStreamTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.11.15.
//  Copyright © 2015 Tobias Kräntzer. 
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

- (void)testCloseByRemotePeer
{
    // Setup a stream to a unknow host (foo.bar). In this case the server will
    // send a stream error and will close the stream immediately without
    // waiting for the closing element by the local peer.

    NSDictionary *options = @{ XMPPWebsocketStreamURLKey : [NSURL URLWithString:@"ws://localhost:5280/xmpp"] };
    XMPPWebsocketStream *stream = [[XMPPWebsocketStream alloc] initWithHostname:@"foo.bar"
                                                                        options:options];

    id<XMPPStreamDelegate> delegate = mockProtocol(@protocol(XMPPStreamDelegate));
    stream.delegate = delegate;

    [givenVoid([delegate stream:stream didReceiveDocument:anything()]) willDo:^id(NSInvocation *invocation) {

        PXDocument *document = [[invocation mkt_arguments] lastObject];
        PXElement *element = document.root;
        NSError *error = [NSError streamErrorFromElement:element];

        assertThat(error, notNilValue());
        assertThat(error.domain, equalTo(XMPPStreamErrorDomain));
        assertThatInteger(error.code, equalToInteger(XMPPStreamErrorCodeHostUnknown));

        // If the client detects an stream error, it will clsoe the stream. This should not result
        // into timing issues with the server (who will be the first closing the stream).

        [stream close];
        return nil;
    }];

    XCTestExpectation *waitForClose = [self expectationWithDescription:@"Close"];
    [givenVoid([delegate streamDidClose:stream]) willDo:^id(NSInvocation *invocation) {
        [waitForClose fulfill];
        return nil;
    }];
    [stream open];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    //
    // Verify delegate calles
    //

    [verifyCount(delegate, times(1)) stream:stream
                              didOpenToHost:anything()
                               withStreamId:notNilValue()];

    [verifyCount(delegate, times(1)) streamDidClose:stream];
}

@end
