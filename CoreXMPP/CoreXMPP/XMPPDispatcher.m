//
//  XMPPDispatcher.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPDispatcher.h"
#import "XMPPError.h"
#import "XMPPJID.h"

@interface XMPPDispatcher () {
    dispatch_queue_t _operationQueue;
    NSMapTable *_connectionsByJID;
    NSHashTable *_messageHandlers;
    NSHashTable *_presenceHandlers;
    NSMapTable *_IQHandlersByQuery;
    NSMapTable *_responseHandlers;
}

@end

@implementation XMPPDispatcher

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPDispatcher", DISPATCH_QUEUE_SERIAL);

        _connectionsByJID = [NSMapTable strongToWeakObjectsMapTable];
        _messageHandlers = [NSHashTable weakObjectsHashTable];
        _presenceHandlers = [NSHashTable weakObjectsHashTable];
        _IQHandlersByQuery = [NSMapTable strongToWeakObjectsMapTable];
        _responseHandlers = [NSMapTable strongToStrongObjectsMapTable];
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
        BOOL replaceConnection = [_connectionsByJID objectForKey:[JID bareJID]] != nil;
        connection.connectionDelegate = self;
        [_connectionsByJID setObject:connection forKey:[JID bareJID]];
        if (replaceConnection == NO) {
            for (id<XMPPDispatcherHandler> handler in [self xmpp_dispatcherHandlers]) {
                if ([handler respondsToSelector:@selector(didAddConnectionTo:)]) {
                    [handler didAddConnectionTo:[JID bareJID]];
                }
            }
        }
    });
}

- (void)removeConnectionForJID:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        [_connectionsByJID removeObjectForKey:[JID bareJID]];
        for (id<XMPPDispatcherHandler> handler in [self xmpp_dispatcherHandlers]) {
            if ([handler respondsToSelector:@selector(didRemoveConnectionTo:)]) {
                [handler didRemoveConnectionTo:[JID bareJID]];
            }
        }
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
            for (id<XMPPDispatcherHandler> handler in [self xmpp_dispatcherHandlers]) {
                if ([handler respondsToSelector:@selector(didRemoveConnectionTo:)]) {
                    [handler didRemoveConnectionTo:JID];
                }
            }
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
            [_IQHandlersByQuery removeObjectForKey:query];
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

- (void)removeHandler:(id)handler
{
    dispatch_async(_operationQueue, ^{
        if ([_messageHandlers containsObject:handler]) {
            [_messageHandlers removeObject:handler];
        }

        if ([_presenceHandlers containsObject:handler]) {
            [_presenceHandlers removeObject:handler];
        }
        NSMutableArray *keys = [[NSMutableArray alloc] init];
        for (PXQName *query in [_IQHandlersByQuery keyEnumerator]) {
            if ([_IQHandlersByQuery objectForKey:query] == handler) {
                [keys addObject:query];
            }
        }
        for (PXQName *query in keys) {
            [_IQHandlersByQuery removeObjectForKey:query];
        }
    });
}

#pragma mark XMPPConnectionDelegate

- (void)connection:(id<XMPPConnection>)connection didConnectTo:(XMPPJID *)JID resumed:(BOOL)resumed
{
    dispatch_async(_operationQueue, ^{
        if (connection == [_connectionsByJID objectForKey:[JID bareJID]]) {
            for (id<XMPPDispatcherHandler> handler in [self xmpp_dispatcherHandlers]) {
                if ([handler respondsToSelector:@selector(didConnect:resumed:)]) {
                    [handler didConnect:JID resumed:resumed];
                }
            }
        }
    });
}

- (void)connection:(id<XMPPConnection>)connection didDisconnectFrom:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        if (connection == [_connectionsByJID objectForKey:[JID bareJID]]) {
            for (id<XMPPDispatcherHandler> handler in [self xmpp_dispatcherHandlers]) {
                if ([handler respondsToSelector:@selector(didDisconnect:)]) {
                    [handler didDisconnect:JID];
                }
            }
        }
    });
}

#pragma mark XMPPStanzaHandler

- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        NSError *error = nil;

        if ([document.root isEqual:PXQN(@"jabber:client", @"message")]) {

            for (id<XMPPMessageHandler> handler in _messageHandlers) {
                [handler handleMessage:document completion:nil];
            }

        } else if ([document.root isEqual:PXQN(@"jabber:client", @"presence")]) {

            for (id<XMPPPresenceHandler> handler in _presenceHandlers) {
                [handler handlePresence:document.root completion:nil];
            }

        } else if ([document.root isEqual:PXQN(@"jabber:client", @"iq")]) {

            NSString *type = [document.root valueForAttribute:@"type"];

            if ([type isEqualToString:@"set"] ||
                [type isEqualToString:@"get"]) {

                if (document.root.numberOfElements == 1) {
                    PXElement *query = [document.root elementAtIndex:0];
                    id<XMPPIQHandler> handler = [_IQHandlersByQuery objectForKey:query.qualifiedName];
                    if (handler) {
                        [handler handleIQRequest:document.root
                                         timeout:0
                                      completion:^(PXElement *response, NSError *error) {
                                          dispatch_async(_operationQueue, ^{
                                              if (error || ![document.root isEqual:PXQN(@"jabber:client", @"iq")]) {

                                                  NSString *from = [document.root valueForAttribute:@"from"];
                                                  NSString *to = [document.root valueForAttribute:@"to"];
                                                  NSString *requestID = [document.root valueForAttribute:@"id"];

                                                  if (from && requestID) {
                                                      PXElement *response = [NSError IQResponseWithError:error];

                                                      [response setValue:from forAttribute:@"to"];
                                                      [response setValue:requestID forAttribute:@"id"];

                                                      if (to)
                                                          [response setValue:to forAttribute:@"from"];

                                                      [self xmpp_routeStanza:response completion:nil];
                                                  }

                                              } else {
                                                  [self xmpp_routeStanza:response completion:nil];
                                              }
                                          });
                                      }];
                    } else {
                        NSString *from = [document.root valueForAttribute:@"from"];
                        NSString *to = [document.root valueForAttribute:@"to"];
                        NSString *requestID = [document.root valueForAttribute:@"id"];

                        if (from && requestID) {

                            NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                                                 code:XMPPStanzaErrorCodeItemNotFound
                                                             userInfo:nil];

                            PXElement *response = [NSError IQResponseWithError:error];

                            [response setValue:from forAttribute:@"to"];
                            [response setValue:requestID forAttribute:@"id"];

                            if (to)
                                [response setValue:to forAttribute:@"from"];

                            [self xmpp_routeStanza:response completion:nil];
                        }
                    }
                } else {
                    error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                code:XMPPDispatcherErrorCodeInvalidStanza
                                            userInfo:nil];
                }

            } else if ([type isEqualToString:@"result"] ||
                       [type isEqualToString:@"error"]) {

                XMPPJID *from = [XMPPJID JIDFromString:[document.root valueForAttribute:@"from"]];
                XMPPJID *to = [XMPPJID JIDFromString:[document.root valueForAttribute:@"to"]];
                NSString *requestID = [document.root valueForAttribute:@"id"];

                if (from && to && requestID) {
                    NSArray *key = @[ from, to, requestID ];
                    void (^completion)(PXElement *response, NSError *error) = [_responseHandlers objectForKey:key];

                    if (completion == nil) {
                        // Try bare JID
                        key = @[ from, [to bareJID], requestID ];
                        completion = [_responseHandlers objectForKey:key];
                    }

                    if (completion) {
                        [_responseHandlers removeObjectForKey:key];
                        completion(document.root, nil);
                    }
                }

            } else {
                error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                            code:XMPPDispatcherErrorCodeInvalidStanza
                                        userInfo:nil];
            }
        } else {
            error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                        code:XMPPDispatcherErrorCodeInvalidStanza
                                    userInfo:nil];
        }

        if (completion) {
            completion(error);
        }
    });
}

- (void)processPendingDocuments:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if (completion) {
            completion(nil);
        }
    });
}

#pragma mark XMPPMessageHandler

- (void)handleMessage:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if ([document.root isEqual:PXQN(@"jabber:client", @"message")]) {
            [self xmpp_routeDocument:document completion:completion];
        } else {
            if (completion) {
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeInvalidStanza
                                                 userInfo:nil];
                completion(error);
            }
        }
    });
}

#pragma mark XMPPPresenceHandler

- (void)handlePresence:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if ([stanza isEqual:PXQN(@"jabber:client", @"presence")]) {
            [self xmpp_routeStanza:stanza completion:completion];
        } else {
            if (completion) {
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeInvalidStanza
                                                 userInfo:nil];
                completion(error);
            }
        }
    });
}

#pragma mark XMPPIQHandler

- (void)handleIQRequest:(PXElement *)stanza
                timeout:(NSTimeInterval)timeout
             completion:(void (^)(PXElement *, NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        NSString *type = [stanza valueForAttribute:@"type"];
        if ([stanza isEqual:PXQN(@"jabber:client", @"iq")] && ([type isEqualToString:@"get"] || [type isEqualToString:@"set"])) {

            NSString *requestId = [stanza valueForAttribute:@"id"];
            if (requestId == nil) {
                requestId = [[NSUUID UUID] UUIDString];
                [stanza setValue:requestId forAttribute:@"id"];
            }

            XMPPJID *from = [XMPPJID JIDFromString:[stanza valueForAttribute:@"from"]];
            XMPPJID *to = [XMPPJID JIDFromString:[stanza valueForAttribute:@"to"]] ?: [from bareJID];
            NSArray *key = @[ to ?: [NSNull null], from ?: [NSNull null], requestId ];

            if (completion) {
                [_responseHandlers setObject:completion forKey:key];
            }

            NSTimeInterval defaultTimeout = 60.0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout ?: defaultTimeout) * NSEC_PER_SEC)), _operationQueue, ^{
                void (^completion)(PXElement *response, NSError *error) = [_responseHandlers objectForKey:key];
                if (completion) {
                    [_responseHandlers removeObjectForKey:key];
                    NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                         code:XMPPDispatcherErrorCodeTimeout
                                                     userInfo:nil];
                    completion(nil, error);
                }
            });

            [self xmpp_routeStanza:stanza
                        completion:^(NSError *error) {
                            if (error) {
                                dispatch_async(_operationQueue, ^{
                                    void (^completion)(PXElement *response, NSError *error) = [_responseHandlers objectForKey:key];
                                    if (completion) {
                                        [_responseHandlers removeObjectForKey:key];
                                        completion(nil, error);
                                    }
                                });
                            }
                        }];

        } else {
            if (completion) {
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeInvalidStanza
                                                 userInfo:nil];
                completion(nil, error);
            }
        }
    });
}

#pragma mark -

- (NSArray *)xmpp_dispatcherHandlers
{
    NSMutableSet *handlers = [[NSMutableSet alloc] init];
    [handlers addObjectsFromArray:[_messageHandlers allObjects]];
    [handlers addObjectsFromArray:[_presenceHandlers allObjects]];
    [handlers addObjectsFromArray:[[_IQHandlersByQuery objectEnumerator] allObjects]];
    return [handlers allObjects];
}

- (void)xmpp_routeStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    XMPPJID *from = [XMPPJID JIDFromString:[stanza valueForAttribute:@"from"]];
    if (from) {
        XMPPJID *bareJID = [from bareJID];
        id<XMPPConnection> connection = [_connectionsByJID objectForKey:bareJID];
        if (connection) {
            PXDocument *document = [[PXDocument alloc] initWithElement:stanza];
            [connection handleDocument:document completion:completion];
        } else {
            if (completion) {
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeNoRoute
                                                 userInfo:nil];
                completion(error);
            }
        }
    } else {
        if (completion) {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeNoSender
                                             userInfo:nil];
            completion(error);
        }
    }
}

- (void)xmpp_routeDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    XMPPJID *from = [XMPPJID JIDFromString:[document.root valueForAttribute:@"from"]];
    if (from) {
        XMPPJID *bareJID = [from bareJID];
        id<XMPPConnection> connection = [_connectionsByJID objectForKey:bareJID];
        if (connection) {
            [connection handleDocument:document completion:completion];
        } else {
            if (completion) {
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeNoRoute
                                                 userInfo:nil];
                completion(error);
            }
        }
    } else {
        if (completion) {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeNoSender
                                             userInfo:nil];
            completion(error);
        }
    }
}

@end
