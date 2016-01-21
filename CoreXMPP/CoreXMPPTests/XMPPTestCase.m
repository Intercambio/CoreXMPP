//
//  XMPPTestCase.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPTestCase.h"

@implementation XMPPTestCase

+ (void)load
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]]; // TTY = Xcode console
    [DDLog addLogger:[DDASLLogger sharedInstance]]; // ASL = Apple System Logs
}

+ (void)initialize
{
    for (NSString *name in [DDLog registeredClassNames]) {
        [DDLog setLevel:DDLogLevelOff forClassWithName:name];
    }
    [DDLog setLevel:DDLogLevelAll forClassWithName:@"XMPPWebsocketStream"];
}

- (void)setUp
{
    [super setUp];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"localhost"] && [request.URL.path isEqualToString:@"/.well-known/host-meta"];
    }
        withStubResponse:^OHHTTPStubsResponse *_Nonnull(NSURLRequest *_Nonnull request) {

            PXDocument *hostMetadata = [[PXDocument alloc] initWithElementName:@"XRD"
                                                                     namespace:@"http://docs.oasis-open.org/ns/xri/xrd-1.0"
                                                                        prefix:nil];

            PXElement *link = [hostMetadata.root addElementWithName:@"Link"
                                                          namespace:@"http://docs.oasis-open.org/ns/xri/xrd-1.0"
                                                            content:nil];

            [link setValue:@"urn:xmpp:alt-connections:websocket" forAttribute:@"rel"];
            [link setValue:@"ws://localhost:5280/xmpp" forAttribute:@"href"];

            return [OHHTTPStubsResponse responseWithData:[hostMetadata data]
                                              statusCode:200
                                                 headers:@{}];
        }];
}

- (void)tearDown
{
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

@end
