//
//  XMPPTestCase.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Security/Security.h>
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
}

- (void)setUp
{
    [super setUp];

    self.keyChainServiceName = [[NSUUID UUID] UUIDString];

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
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.keyChainServiceName forKey:(__bridge id)kSecAttrService];

    OSStatus errorcode = SecItemDelete((__bridge CFDictionaryRef)query);
    if (errorcode != errSecItemNotFound && errorcode != noErr) {
        XCTFail(@"Couldn't delete Keychain Items.");
    }

    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

@end
