//
//  XMPPRouter.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPJID.h"
#import "XMPPModule.h"
#import "XMPPRouter.h"

@interface XMPPRouter () {
    dispatch_queue_t _operationQueue;

    // Connections
    NSMutableArray *_connections;
    NSMapTable *_connectionByJID;

    // Modules
    NSMutableArray *_modules;
    NSMapTable *_modulesByIQQuery;

    // Response Handler
    NSMapTable *_responseHandler;
}

@end

@implementation XMPPRouter

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPRouter", DISPATCH_QUEUE_SERIAL);
        _modules = [[NSMutableArray alloc] init];
        _modulesByIQQuery = [NSMapTable strongToWeakObjectsMapTable];
        _connections = [[NSMutableArray alloc] init];
        _connectionByJID = [NSMapTable strongToWeakObjectsMapTable];
        _responseHandler = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

#pragma mark Manage Connections

- (NSArray *)connections
{
    __block NSArray *connections = nil;
    dispatch_sync(_operationQueue, ^{
        connections = [_connections copy];
    });
    return connections;
}

- (void)addConnection:(id<XMPPConnection>)connection
{
    dispatch_sync(_operationQueue, ^{
        [_connections addObject:connection];
        connection.router = self;
        for (XMPPJID *JID in connection.JIDs) {
            [_connectionByJID setObject:connection forKey:JID];
        }
    });
}

- (void)removeConnection:(id<XMPPConnection>)connection
{
    dispatch_sync(_operationQueue, ^{
        [_connections removeObject:connection];
        connection.router = nil;
    });
}

- (void)connection:(id<XMPPConnection>)connection didAddRoute:(XMPPJID *)JID
{
}

- (void)connection:(id<XMPPConnection>)connection didRemoveRoute:(XMPPJID *)JID
{
}

#pragma mark Manage Modules

- (NSArray *)modules
{
    __block NSArray *modules = nil;
    dispatch_sync(_operationQueue, ^{
        modules = [_modules copy];
    });
    return modules;
}

- (void)addModule:(XMPPModule *)module
{
    dispatch_sync(_operationQueue, ^{
        [_modules addObject:module];
        module.router = self;
    });
}

- (void)removeModule:(XMPPModule *)module
{
    dispatch_sync(_operationQueue, ^{
        [_modules removeObject:module];
        module.router = nil;
    });
}

- (void)setModule:(XMPPModule *)module forIQQuery:(PXQName *)query
{
    dispatch_sync(_operationQueue, ^{
        [_modulesByIQQuery setObject:module forKey:query];
    });
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{

        if ([stanza isEqual:PXQN(@"jabber:client", @"message")]) {

            for (XMPPModule *module in _modules) {
                if ([module conformsToProtocol:@protocol(XMPPMessageHandler)]) {
                    id<XMPPMessageHandler> handler = (id<XMPPMessageHandler>)module;
                    [handler handleMessage:stanza];
                }
            }

        } else if ([stanza isEqual:PXQN(@"jabber:client", @"presence")]) {

            for (XMPPModule *module in _modules) {
                if ([module conformsToProtocol:@protocol(XMPPPresenceHandler)]) {
                    id<XMPPPresenceHandler> handler = (id<XMPPPresenceHandler>)module;
                    [handler handlePresence:stanza];
                }
            }

        } else if ([stanza isEqual:PXQN(@"jabber:client", @"iq")]) {

            NSString *type = [stanza valueForAttribute:@"type"];

            if ([type isEqualToString:@"set"] ||
                [type isEqualToString:@"get"]) {

                if (stanza.numberOfElements == 1) {

                    PXElement *query = [stanza elementAtIndex:0];
                    XMPPModule *module = [_modulesByIQQuery objectForKey:query.qualifiedName];

                    if (module && [module conformsToProtocol:@protocol(XMPPIQHandler)]) {
                        id<XMPPIQHandler> handler = (id<XMPPIQHandler>)module;
                        [handler handleIQRequest:stanza resultHandler:self];
                    }

                } else {
                    // Invalid Stanza
                }

            } else if ([type isEqualToString:@"result"] ||
                       [type isEqualToString:@"error"]) {

                XMPPJID *from = [XMPPJID JIDFromString:[stanza valueForAttribute:@"from"]];
                XMPPJID *to = [XMPPJID JIDFromString:[stanza valueForAttribute:@"to"]];
                NSString *requestID = [stanza valueForAttribute:@"id"];

                if (from && to && requestID) {
                    NSArray *key = @[ from, to, requestID ];
                    id<XMPPIQHandler> handler = [_responseHandler objectForKey:key];
                    if (handler) {
                        [handler handleIQResponse:stanza];
                        [_responseHandler removeObjectForKey:key];
                    }
                }

            } else {
                // Invalid Stanza
            }

        } else {
            // Invalid Stanza
        }
    });
}

#pragma mark XMPPMessageHandler

- (void)handleMessage:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        if ([stanza isEqual:PXQN(@"jabber:client", @"message")]) {
            [self xmpp_routeStanza:stanza];
        } else {
            // ...
        }
    });
}

#pragma mark XMPPPresenceHandler

- (void)handlePresence:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        if ([stanza isEqual:PXQN(@"jabber:client", @"presence")]) {
            [self xmpp_routeStanza:stanza];
        } else {
            // ...
        }
    });
}

#pragma mark XMPPIQHandler

- (void)handleIQRequest:(PXElement *)stanza resultHandler:(id<XMPPIQHandler>)resultHandler
{
    dispatch_async(_operationQueue, ^{

        NSString *type = [stanza valueForAttribute:@"type"];
        XMPPJID *from = [XMPPJID JIDFromString:[stanza valueForAttribute:@"from"]];
        XMPPJID *to = [XMPPJID JIDFromString:[stanza valueForAttribute:@"to"]];

        if ([stanza isEqual:PXQN(@"jabber:client", @"iq")] && from != nil && to != nil && ([type isEqualToString:@"get"] || [type isEqualToString:@"set"])) {

            NSString *requestId = [stanza valueForAttribute:@"id"];
            if (requestId == nil) {
                requestId = [[NSUUID UUID] UUIDString];
                [stanza setValue:requestId forAttribute:@"id"];
            }

            NSArray *key = @[ to, from, requestId ];
            [_responseHandler setObject:resultHandler forKey:key];

            [self xmpp_routeStanza:stanza];
        } else {
            // ...
        }
    });
}

- (void)handleIQResponse:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        if ([stanza isEqual:PXQN(@"jabber:client", @"iq")]) {
            [self xmpp_routeStanza:stanza];
        } else {
            // ...
        }
    });
}

#pragma mark -

- (void)xmpp_routeStanza:(PXElement *)stanza
{
    XMPPJID *from = [XMPPJID JIDFromString:[stanza valueForAttribute:@"from"]];
    if (from) {

        XMPPJID *bareJID = [from bareJID];
        id<XMPPConnection> connection = [_connectionByJID objectForKey:bareJID];
        if (connection) {
            [connection handleStanza:stanza];
        }

    } else {
        // ...
    }
}

@end
