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
#import "XMPPIQHandlerProxy.h"

#import "XMPPPingModule.h"

@interface XMPPPingModule () {
    dispatch_queue_t _operationQueue;
    NSMutableDictionary *_pendingResponseHandler;
}

@end

@implementation XMPPPingModule

#pragma mark Life-cycle

- (instancetype)initWithDispatcher:(XMPPDispatcher *)dispatcher options:(NSDictionary *)options
{
    self = [super initWithDispatcher:dispatcher options:options];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPPingModule", DISPATCH_QUEUE_SERIAL);
        _pendingResponseHandler = [[NSMutableDictionary alloc] init];
        [dispatcher setIQHandler:self forQuery:PXQN(@"urn:xmpp:ping", @"ping")];
    }
    return self;
}

- (void)dealloc
{
    [_pendingResponseHandler removeAllObjects];
}

#pragma mark Send Ping

- (void)sendPingTo:(XMPPJID *)to from:(XMPPJID *)from timeout:(NSTimeInterval)timeout completionHandler:(void(^)(BOOL success, NSError *error))completionHandler
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
        
        XMPPIQHandlerProxy *proxy = [[XMPPIQHandlerProxy alloc] init];
        proxy.handler = self;
        proxy.context = completionHandler;
        
        [_pendingResponseHandler setObject:proxy forKey:requestID];
        
        if (timeout > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), _operationQueue, ^{
                void(^_completionHandler)(BOOL success, NSError *error) = [self xmpp_popResponseHandlerForID:requestID];
                if (_completionHandler) {
                    NSError *error = nil; // timeout error
                    _completionHandler(NO, error);
                }
            });
        }
        
        [self.dispatcher handleIQRequest:iq resultHandler:proxy];
    });
}

#pragma mark XMPPIQHandler

- (void)handleIQRequest:(PXElement *)stanza resultHandler:(id<XMPPIQHandler>)resultHandler
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
                
                [resultHandler handleIQResponse:response];
            }
        }
    });
}

- (void)handleIQResponse:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        NSString *responseID = [stanza valueForAttribute:@"id"];
        
        void(^_completionHandler)(BOOL success, NSError *error) = [self xmpp_popResponseHandlerForID:responseID];
        if (_completionHandler) {
            NSString *type = [stanza valueForAttribute:@"type"];
            if ([type isEqualToString:@"result"]) {
                _completionHandler(YES, nil);
            } else if ([type isEqualToString:@"error"]) {
                NSError *error = [XMPPStanza errorFromStanza:stanza];
                _completionHandler(NO, error);
            }
        }
    });
}

#pragma mark -

- (void(^)(BOOL, NSError *))xmpp_popResponseHandlerForID:(NSString *)responseID
{
    XMPPIQHandlerProxy *proxy = [_pendingResponseHandler objectForKey:responseID];
    if (proxy) {
        [_pendingResponseHandler removeObjectForKey:responseID];
    }
    return proxy.context;
}

@end
