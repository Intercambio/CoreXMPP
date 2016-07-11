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
    NSHashTable *_handlers;
    NSMapTable *_handlersByQuery;
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
        _handlers = [NSHashTable weakObjectsHashTable];
        _handlersByQuery = [NSMapTable strongToWeakObjectsMapTable];
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
            for (id<XMPPDispatcherHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPDispatcherHandler)]) {
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
        for (id<XMPPDispatcherHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPDispatcherHandler)]) {
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
            for (id<XMPPDispatcherHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPDispatcherHandler)]) {
                if ([handler respondsToSelector:@selector(didRemoveConnectionTo:)]) {
                    [handler didRemoveConnectionTo:JID];
                }
            }
        }
    });
}

#pragma mark Manage Handlers

- (void)addHandler:(id)handler
{
    [self addHandler:handler withIQQueryQNames:nil];
}

- (void)addHandler:(id)handler withIQQueryQNames:(NSArray *)queryQNames
{
    if ([handler conformsToProtocol:@protocol(XMPPDispatcherHandler)] ||
        [handler conformsToProtocol:@protocol(XMPPMessageHandler)] ||
        [handler conformsToProtocol:@protocol(XMPPPresenceHandler)] ||
        [handler conformsToProtocol:@protocol(XMPPIQHandler)]) {

        [_handlers addObject:handler];

        if ([queryQNames count] > 0 && [handler conformsToProtocol:@protocol(XMPPIQHandler)]) {
            for (PXQName *queryQName in queryQNames) {
                [_handlersByQuery setObject:handler forKey:queryQName];
            }
        }
    }
}

- (void)removeHandler:(id)handler
{
    dispatch_async(_operationQueue, ^{
        [_handlers removeObject:handler];

        NSMutableArray *keys = [[NSMutableArray alloc] init];
        for (PXQName *query in [_handlersByQuery keyEnumerator]) {
            if ([_handlersByQuery objectForKey:query] == handler) {
                [keys addObject:query];
            }
        }
        for (PXQName *query in keys) {
            [_handlersByQuery removeObjectForKey:query];
        }
    });
}

- (NSArray *)dispatcherHandlers
{
    __block NSArray *dispatcherHandlers = nil;
    dispatch_sync(_operationQueue, ^{
        dispatcherHandlers = [self xmpp_handlersConformingToProtocol:@protocol(XMPPDispatcherHandler)];
    });
    return dispatcherHandlers;
}

- (NSArray *)messageHandlers
{
    __block NSArray *messageHandlers = nil;
    dispatch_sync(_operationQueue, ^{
        messageHandlers = [self xmpp_handlersConformingToProtocol:@protocol(XMPPMessageHandler)];
    });
    return messageHandlers;
}

- (NSArray *)presenceHandlers
{
    __block NSArray *presenceHandlers = nil;
    dispatch_sync(_operationQueue, ^{
        presenceHandlers = [self xmpp_handlersConformingToProtocol:@protocol(XMPPPresenceHandler)];
    });
    return presenceHandlers;
}

- (NSDictionary *)IQHandlersByQuery
{
    __block NSDictionary *IQHandlerByQuery = nil;
    dispatch_sync(_operationQueue, ^{
        IQHandlerByQuery = [_handlersByQuery dictionaryRepresentation];
    });
    return IQHandlerByQuery;
}

- (NSArray *)xmpp_handlersConformingToProtocol:(Protocol *)protocol
{
    __block NSArray *handlers = nil;
    handlers = [[_handlers allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id _Nonnull evaluatedObject, NSDictionary<NSString *, id> *_Nullable bindings) {
                                           return [evaluatedObject conformsToProtocol:protocol];
                                       }]];
    return handlers;
}

#pragma mark Processing

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

#pragma mark XMPPConnectionDelegate

- (void)connection:(id<XMPPConnection>)connection didConnectTo:(XMPPJID *)JID resumed:(BOOL)resumed
{
    dispatch_async(_operationQueue, ^{
        if (connection == [_connectionsByJID objectForKey:[JID bareJID]]) {
            for (id<XMPPDispatcherHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPDispatcherHandler)]) {
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
            for (id<XMPPDispatcherHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPDispatcherHandler)]) {
                if ([handler respondsToSelector:@selector(didDisconnect:)]) {
                    [handler didDisconnect:JID];
                }
            }
        }
    });
}

#pragma mark XMPPDocumentHandler

- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        NSError *error = nil;

        if ([document.root isEqual:PXQN(@"jabber:client", @"message")]) {

            for (id<XMPPMessageHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPMessageHandler)]) {
                [handler handleMessage:document completion:nil];
            }

        } else if ([document.root isEqual:PXQN(@"jabber:client", @"presence")]) {

            for (id<XMPPPresenceHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPPresenceHandler)]) {
                [handler handlePresence:document completion:nil];
            }

        } else if ([document.root isEqual:PXQN(@"jabber:client", @"iq")]) {

            NSString *type = [document.root valueForAttribute:@"type"];

            if ([type isEqualToString:@"set"] ||
                [type isEqualToString:@"get"]) {

                if (document.root.numberOfElements == 1) {
                    PXElement *query = [document.root elementAtIndex:0];
                    id<XMPPIQHandler> handler = [_handlersByQuery objectForKey:query.qualifiedName];
                    if (handler) {
                        [handler handleIQRequest:document
                                         timeout:0
                                      completion:^(PXDocument *response, NSError *error) {
                                          dispatch_async(_operationQueue, ^{
                                              if (error || ![document.root isEqual:PXQN(@"jabber:client", @"iq")]) {

                                                  NSString *from = [document.root valueForAttribute:@"from"];
                                                  NSString *to = [document.root valueForAttribute:@"to"];
                                                  NSString *requestID = [document.root valueForAttribute:@"id"];

                                                  if (from && requestID) {
                                                      PXDocument *response = [NSError IQResponseWithError:error];

                                                      [response.root setValue:from forAttribute:@"to"];
                                                      [response.root setValue:requestID forAttribute:@"id"];

                                                      if (to)
                                                          [response.root setValue:to forAttribute:@"from"];

                                                      [self xmpp_routeDocument:response completion:nil];
                                                  }

                                              } else {
                                                  [self xmpp_routeDocument:response completion:nil];
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

                            PXDocument *response = [NSError IQResponseWithError:error];

                            [response.root setValue:from forAttribute:@"to"];
                            [response.root setValue:requestID forAttribute:@"id"];

                            if (to)
                                [response.root setValue:to forAttribute:@"from"];

                            [self xmpp_routeDocument:response completion:nil];
                        }
                    }
                } else {
                    error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                code:XMPPDispatcherErrorCodeInvalidStanza
                                            userInfo:nil];
                }

            } else if ([type isEqualToString:@"result"] ||
                       [type isEqualToString:@"error"]) {

                XMPPJID *from = [[XMPPJID alloc] initWithString:[document.root valueForAttribute:@"from"]];
                XMPPJID *to = [[XMPPJID alloc] initWithString:[document.root valueForAttribute:@"to"]];
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

- (void)handlePresence:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if ([document.root isEqual:PXQN(@"jabber:client", @"presence")]) {
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

#pragma mark XMPPIQHandler

- (void)handleIQRequest:(PXDocument *)document
                timeout:(NSTimeInterval)timeout
             completion:(void (^)(PXDocument *, NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        NSString *type = [document.root valueForAttribute:@"type"];
        if ([document.root isEqual:PXQN(@"jabber:client", @"iq")] && ([type isEqualToString:@"get"] || [type isEqualToString:@"set"])) {

            NSString *requestId = [document.root valueForAttribute:@"id"];
            if (requestId == nil) {
                requestId = [[NSUUID UUID] UUIDString];
                [document.root setValue:requestId forAttribute:@"id"];
            }

            XMPPJID *from = [[XMPPJID alloc] initWithString:[document.root valueForAttribute:@"from"]];
            XMPPJID *to = [[XMPPJID alloc] initWithString:[document.root valueForAttribute:@"to"]] ?: [from bareJID];
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

            [self xmpp_routeDocument:document
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

- (void)xmpp_routeDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    XMPPJID *from = [[XMPPJID alloc] initWithString:[document.root valueForAttribute:@"from"]];
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
