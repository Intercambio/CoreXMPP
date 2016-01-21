//
//  XMPPPingModule.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPJID.h"
#import "XMPPStanza.h"
#import "XMPPServiceManager.h"

#import "XMPPPingModule.h"

@interface XMPPPingModule () {
    dispatch_queue_t _operationQueue;
}

@end

@implementation XMPPPingModule

+ (void)load
{
    [XMPPServiceManager registerModuleClass:[self class] forModuleType:@"XEP-0199"];
}

#pragma mark Life-cycle

- (instancetype)initWithDispatcher:(XMPPDispatcher *)dispatcher options:(NSDictionary *)options
{
    self = [super initWithDispatcher:dispatcher options:options];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPPingModule", DISPATCH_QUEUE_SERIAL);
        [dispatcher setIQHandler:self forQuery:PXQN(@"urn:xmpp:ping", @"ping")];
    }
    return self;
}

#pragma mark Send Ping

- (void)sendPingTo:(XMPPJID *)to from:(XMPPJID *)from timeout:(NSTimeInterval)timeout completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    dispatch_async(_operationQueue, ^{

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

        PXElement *iq = doc.root;
        [iq setValue:[to stringValue] forAttribute:@"to"];
        [iq setValue:[from stringValue] forAttribute:@"from"];
        [iq setValue:@"get" forAttribute:@"type"];

        NSString *requestID = [[NSUUID UUID] UUIDString];
        [iq setValue:requestID forAttribute:@"id"];

        [iq addElementWithName:@"ping" namespace:@"urn:xmpp:ping" content:nil];

        [self.dispatcher handleIQRequest:iq
                                 timeout:timeout
                              completion:^(PXElement *response, NSError *error) {
                                  if (completionHandler) {
                                      dispatch_async(_operationQueue, ^{
                                          if (error) {
                                              completionHandler(NO, error);
                                          } else {
                                              NSString *type = [response valueForAttribute:@"type"];
                                              if ([type isEqualToString:@"result"]) {
                                                  completionHandler(YES, nil);
                                              } else if ([type isEqualToString:@"error"]) {
                                                  NSError *error = [XMPPStanza errorFromStanza:response];
                                                  completionHandler(NO, error);
                                              }
                                          }
                                      });
                                  }
                              }];
    });
}

#pragma mark XMPPIQHandler

- (void)handleIQRequest:(PXElement *)stanza timeout:(NSTimeInterval)timeout completion:(void (^)(PXElement *, NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if ([stanza numberOfElements] == 1) {
            PXElement *ping = [stanza elementAtIndex:0];
            if ([ping isEqual:PXQN(@"urn:xmpp:ping", @"ping")]) {
                NSString *from = [stanza valueForAttribute:@"to"];
                NSString *to = [stanza valueForAttribute:@"from"];
                NSString *_id = [stanza valueForAttribute:@"id"];

                PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
                PXElement *response = doc.root;
                [response setValue:from forAttribute:@"from"];
                [response setValue:to forAttribute:@"to"];
                [response setValue:@"result" forAttribute:@"type"];
                [response setValue:_id forAttribute:@"id"];

                if (completion) {
                    completion(response, nil);
                }
            } else {
                // TODO: respond with error
            }
        }
    });
}

@end
