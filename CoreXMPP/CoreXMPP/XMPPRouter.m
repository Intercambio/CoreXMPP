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
    NSMapTable *_connectionsByJID;
    NSHashTable *_messageHandlers;
    NSHashTable *_presenceHandlers;
    NSMapTable *_IQHandlersByQuery;
    NSMapTable *_responseHandlers;
}

@end

@implementation XMPPRouter

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPRouter", DISPATCH_QUEUE_SERIAL);
        
        _connectionsByJID = [NSMapTable strongToWeakObjectsMapTable];
        _messageHandlers = [NSHashTable weakObjectsHashTable];
        _presenceHandlers = [NSHashTable weakObjectsHashTable];
        _IQHandlersByQuery = [NSMapTable strongToWeakObjectsMapTable];
        _responseHandlers = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

#pragma mark Manage Connections

- (NSDictionary *)connectionsByJID
{
    __block NSDictionary *connectionsByJID = nil;
    dispatch_sync(_operationQueue, ^{
        connectionsByJID = [_connectionsByJID dictionaryRepresentation];
    });
    return connectionsByJID;
}

- (void)setConnection:(id<XMPPConnection>)connection forJID:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        [_connectionsByJID setObject:connection forKey:[JID bareJID]];
    });
}

- (void)removeConnectionForJID:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        [_connectionsByJID removeObjectForKey:[JID bareJID]];
    });
}

- (void)removeConnection:(id<XMPPConnection>)connection
{
    dispatch_async(_operationQueue, ^{
        NSMutableArray *keys = [[NSMutableArray alloc] init];
        for (XMPPJID *JID in [_connectionsByJID keyEnumerator]) {
            if ([_connectionsByJID objectForKey:JID] == connection) {
                [keys addObject:JID];
            }
        }
        for (XMPPJID *JID in keys) {
            [_connectionsByJID removeObjectForKey:JID];
        }
    });
}

#pragma mark Manage Handlers

- (NSArray *)messageHandlers
{
    __block NSArray *messageHandlers = nil;
    dispatch_sync(_operationQueue, ^{
        messageHandlers = [_messageHandlers allObjects];
    });
    return messageHandlers;
}

- (void)addMessageHandler:(id<XMPPMessageHandler>)messageHandler
{
    dispatch_async(_operationQueue, ^{
        if (![_messageHandlers containsObject:messageHandler]) {
            [_messageHandlers addObject:messageHandler];
        }
    });
}

- (void)removeMessageHandler:(id<XMPPMessageHandler>)messageHandler
{
    dispatch_async(_operationQueue, ^{
        if ([_messageHandlers containsObject:messageHandler]) {
            [_messageHandlers removeObject:messageHandler];
        }
    });
}

- (NSArray *)presenceHandlers
{
    __block NSArray *presenceHandlers = nil;
    dispatch_sync(_operationQueue, ^{
        presenceHandlers = [_presenceHandlers allObjects];
    });
    return presenceHandlers;
}

- (void)addPresenceHandler:(id<XMPPPresenceHandler>)presenceHandler
{
    dispatch_async(_operationQueue, ^{
        if (![_presenceHandlers containsObject:presenceHandler]) {
            [_presenceHandlers addObject:presenceHandler];
        }
    });
}

- (void)removePresenceHandler:(id<XMPPPresenceHandler>)presenceHandler
{
    dispatch_async(_operationQueue, ^{
        if ([_presenceHandlers containsObject:presenceHandler]) {
            [_presenceHandlers removeObject:presenceHandler];
        }
    });
}

- (NSDictionary *)IQHandlersByQuery
{
    __block NSDictionary *IQHandlerByQuery = nil;
    dispatch_sync(_operationQueue, ^{
       IQHandlerByQuery = [_IQHandlersByQuery dictionaryRepresentation];
    });
    return IQHandlerByQuery;
}

- (void)setIQHandler:(id<XMPPIQHandler>)handler forQuery:(PXQName *)query
{
    dispatch_async(_operationQueue, ^{
        [_IQHandlersByQuery setObject:handler forKey:query];
    });
}

- (void)removeIQHandlerForQuery:(PXQName *)query
{
    dispatch_async(_operationQueue, ^{
        [_IQHandlersByQuery removeObjectForKey:query];
    });
}

- (void)removeIQHandler:(id<XMPPIQHandler>)handler
{
    dispatch_async(_operationQueue, ^{
        NSMutableArray *keys = [[NSMutableArray alloc] init];
        for (PXQName *query in [_IQHandlersByQuery keyEnumerator]) {
            if ([_IQHandlersByQuery objectForKey:query] == handler) {
                [keys addObject:query];
            }
        }
        for (PXQName *query in keys) {
            [_connectionsByJID removeObjectForKey:query];
        }
    });
}

- (NSUInteger)numberOfPendingIQResponses
{
    __block NSUInteger numberOfPendingIQResponses = 0;
    dispatch_sync(_operationQueue, ^{
        // Use the dictionary representation of the map table to
        // make sure, that nil objects are not counted.
        numberOfPendingIQResponses = [[_responseHandlers dictionaryRepresentation] count];
    });
    return numberOfPendingIQResponses;
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{

        if ([stanza isEqual:PXQN(@"jabber:client", @"message")]) {

            for (id<XMPPMessageHandler> handler in _messageHandlers) {
                [handler handleMessage:stanza];
            }

        } else if ([stanza isEqual:PXQN(@"jabber:client", @"presence")]) {

            for (id<XMPPPresenceHandler> handler in _presenceHandlers) {
                [handler handlePresence:stanza];
            }
            
        } else if ([stanza isEqual:PXQN(@"jabber:client", @"iq")]) {

            NSString *type = [stanza valueForAttribute:@"type"];

            if ([type isEqualToString:@"set"] ||
                [type isEqualToString:@"get"]) {

                if (stanza.numberOfElements == 1) {
                    PXElement *query = [stanza elementAtIndex:0];
                    id<XMPPIQHandler> handler = [_IQHandlersByQuery objectForKey:query.qualifiedName];
                    if (handler) {
                        [handler handleIQRequest:stanza resultHandler:self];
                    } else {
                        
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
                    id<XMPPIQHandler> handler = [_responseHandlers objectForKey:key];
                    if (handler) {
                        [handler handleIQResponse:stanza];
                        [_responseHandlers removeObjectForKey:key];
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
            [_responseHandlers setObject:resultHandler forKey:key];

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
        id<XMPPConnection> connection = [_connectionsByJID objectForKey:bareJID];
        if (connection) {
            [connection handleStanza:stanza];
        }

    } else {
        // ...
    }
}

@end
