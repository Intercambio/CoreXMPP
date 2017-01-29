//
//  XMPPTestCase.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
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

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Security/Security.h>

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
