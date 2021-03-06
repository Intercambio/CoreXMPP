//
//  XMPPDispatcher.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
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

@import Foundation;
@import XMPPFoundation;

#import <PureXML/PureXML.h>

#import "XMPPDispatcherImpl.h"
#import "XMPPError.h"

NSString *_Nonnull const XMPPDispatcherErrorDomain = @"XMPPDispatcherErrorDomain";

@interface XMPPDispatcherImplPendingSubmission : NSObject
@property (nonatomic, readonly) NSDate *timeout;
@property (nonatomic, readonly) PXDocument *document;
@property (nonatomic, readonly) void (^completion)(NSError *);
- (instancetype)initWithDocument:(PXDocument *)document timeout:(NSDate *)timeout completion:(void (^)(NSError *))completion;
@end

@interface XMPPDispatcherConnectionHandle : NSObject
@property (nonatomic, readonly) id<XMPPConnection> connection;
@property (nonatomic, readwrite) BOOL connected;
@property (nonatomic, readonly) NSMutableArray<XMPPDispatcherImplPendingSubmission *> *pendingSubmissions;
- (instancetype)initWithConnection:(id<XMPPConnection>)connection;
@end

@interface XMPPDispatcherImpl () {
    dispatch_queue_t _operationQueue;
    NSMapTable<XMPPJID *, XMPPDispatcherConnectionHandle *> *_connectionsByJID;
    NSHashTable *_handlers;
    NSMapTable *_handlersByQuery;
    NSMapTable *_responseHandlers;
}

@end

@implementation XMPPDispatcherImpl

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPDispatcher", DISPATCH_QUEUE_SERIAL);
        _connectionsByJID = [NSMapTable strongToStrongObjectsMapTable];
        _handlers = [NSHashTable weakObjectsHashTable];
        _handlersByQuery = [NSMapTable strongToWeakObjectsMapTable];
        _responseHandlers = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}

#pragma mark Manage Connections

- (NSDictionary *)connectionsByJID
{
    __block NSMutableDictionary *connectionsByJID = [[NSMutableDictionary alloc] init];
    dispatch_sync(_operationQueue, ^{
        [[_connectionsByJID dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(XMPPJID *jid,
                                                                                          XMPPDispatcherConnectionHandle *handle,
                                                                                          BOOL *stop) {
            [connectionsByJID setObject:handle.connection forKey:jid];
        }];
    });
    return connectionsByJID;
}

- (void)setConnection:(id<XMPPConnection>)connection forJID:(XMPPJID *)JID
{
    dispatch_sync(_operationQueue, ^{
        XMPPDispatcherConnectionHandle *handle = [_connectionsByJID objectForKey:[JID bareJID]];
        if (handle) {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeNoRoute
                                             userInfo:nil];
            for (XMPPDispatcherImplPendingSubmission *pending in handle.pendingSubmissions) {
                if (pending.completion) {
                    pending.completion(error);
                }
            }
        }

        if (connection) {
            connection.connectionDelegate = self;
            XMPPDispatcherConnectionHandle *handle = [[XMPPDispatcherConnectionHandle alloc] initWithConnection:connection];
            [_connectionsByJID setObject:handle forKey:[JID bareJID]];
        }
    });
}

- (void)removeConnectionForJID:(XMPPJID *)JID
{
    dispatch_sync(_operationQueue, ^{
        XMPPDispatcherConnectionHandle *handle = [_connectionsByJID objectForKey:[JID bareJID]];
        if (handle) {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeNoRoute
                                             userInfo:nil];
            for (XMPPDispatcherImplPendingSubmission *pending in handle.pendingSubmissions) {
                if (pending.completion) {
                    pending.completion(error);
                }
            }

            [_connectionsByJID removeObjectForKey:[JID bareJID]];

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                    [handler didDisconnect:[JID bareJID]];
                }
            });
        }
    });
}

- (void)removeConnection:(id<XMPPConnection>)connection
{
    dispatch_sync(_operationQueue, ^{

        [[_connectionsByJID dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(XMPPJID *JID,
                                                                                          XMPPDispatcherConnectionHandle *handle, BOOL *stop) {

            if (handle.connection == connection) {
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeNoRoute
                                                 userInfo:nil];
                for (XMPPDispatcherImplPendingSubmission *pending in handle.pendingSubmissions) {
                    if (pending.completion) {
                        pending.completion(error);
                    }
                }

                [_connectionsByJID removeObjectForKey:[JID bareJID]];

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                        [handler didDisconnect:[JID bareJID]];
                    }
                });
            }

        }];
    });
}

#pragma mark Manage Handlers

- (void)addHandler:(id)handler
{
    [self addHandler:handler withIQQueryQNames:nil features:nil];
}

- (void)addHandler:(id)handler withIQQueryQNames:(NSArray *)queryQNames features:(nullable NSArray<XMPPFeature *> *)features
{
    dispatch_sync(_operationQueue, ^{
        if ([handler conformsToProtocol:@protocol(XMPPHandler)]) {
            [_handlers addObject:handler];
            if ([queryQNames count] > 0 && [handler conformsToProtocol:@protocol(XMPPIQHandler)]) {
                for (PXQName *queryQName in queryQNames) {
                    [_handlersByQuery setObject:handler forKey:queryQName];
                }
            }
        }
    });
}

- (void)removeHandler:(id)handler
{
    dispatch_sync(_operationQueue, ^{
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
        dispatcherHandlers = [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)];
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
        XMPPDispatcherConnectionHandle *handle = [_connectionsByJID objectForKey:[JID bareJID]];
        if (handle && handle.connection == connection) {
            handle.connected = YES;
            for (XMPPDispatcherImplPendingSubmission *pending in handle.pendingSubmissions) {
                [connection handleDocument:pending.document completion:pending.completion];
            }
            [handle.pendingSubmissions removeAllObjects];
            for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                [handler didConnect:[JID bareJID] resumed:resumed features:nil];
            }
        }
    });
}

- (void)connection:(id<XMPPConnection>)connection didDisconnectFrom:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        XMPPDispatcherConnectionHandle *handle = [_connectionsByJID objectForKey:[JID bareJID]];
        if (handle && handle.connection == connection) {
            handle.connected = NO;
            for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                [handler didDisconnect:[JID bareJID]];
            }
        }
    });
}

#pragma mark XMPPDocumentHandler

- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        if (self.delegate) {
            id<XMPPDispatcherDelegate> delegate = self.delegate;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [delegate dispatcher:self didReceiveDocument:document];
            });
        }

        NSError *error = nil;

        if ([document.root isKindOfClass:[XMPPMessageStanza class]]) {

            XMPPMessageStanza *stanza = (XMPPMessageStanza *)document.root;

            for (id<XMPPMessageHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPMessageHandler)]) {
                [handler handleMessage:stanza completion:nil];
            }

        } else if ([document.root isKindOfClass:[XMPPPresenceStanza class]]) {

            XMPPPresenceStanza *stanza = (XMPPPresenceStanza *)document.root;

            for (id<XMPPPresenceHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPPresenceHandler)]) {
                [handler handlePresence:stanza completion:nil];
            }

        } else if ([document.root isKindOfClass:[XMPPIQStanza class]]) {

            XMPPIQStanza *stanza = (XMPPIQStanza *)document.root;

            NSString *type = [document.root valueForAttribute:@"type"];

            if ([type isEqualToString:@"set"] ||
                [type isEqualToString:@"get"]) {

                if (document.root.numberOfElements == 1) {
                    PXElement *query = [document.root elementAtIndex:0];
                    id<XMPPIQHandler> handler = [_handlersByQuery objectForKey:query.qualifiedName];
                    if (handler) {
                        [handler handleIQRequest:stanza
                                         timeout:0
                                      completion:^(XMPPIQStanza *response, NSError *error) {
                                          dispatch_async(_operationQueue, ^{
                                              if (error || ![document.root isEqual:PXQN(@"jabber:client", @"iq")]) {
                                                  XMPPIQStanza *response = [stanza responseWithError:error];
                                                  [self xmpp_routeDocument:response completion:nil];
                                              } else {
                                                  [self xmpp_routeDocument:response completion:nil];
                                              }
                                          });
                                      }];
                    } else {
                        NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                                             code:XMPPStanzaErrorCodeItemNotFound
                                                         userInfo:nil];
                        XMPPIQStanza *response = [stanza responseWithError:error];
                        [self xmpp_routeDocument:response completion:nil];
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

- (void)handleMessage:(XMPPMessageStanza *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_routeDocument:stanza completion:completion];
    });
}

#pragma mark XMPPPresenceHandler

- (void)handlePresence:(XMPPPresenceStanza *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_routeDocument:stanza completion:completion];
    });
}

#pragma mark XMPPIQHandler

- (void)handleIQRequest:(XMPPIQStanza *)request
                timeout:(NSTimeInterval)timeout
             completion:(void (^)(XMPPIQStanza *, NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        if (request.type == XMPPIQStanzaTypeSet || request.type == XMPPIQStanzaTypeGet) {

            NSString *requestId = request.identifier;
            if (requestId == nil) {
                requestId = [[NSUUID UUID] UUIDString];
                request.identifier = requestId;
            }

            XMPPJID *from = request.from;
            XMPPJID *to = request.to ?: [from bareJID];
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

            [self xmpp_routeDocument:request
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

- (void)xmpp_routeDocument:(XMPPStanza *)stanza completion:(void (^)(NSError *))completion
{

    if (self.delegate) {
        PXDocument *document = [[PXDocument alloc] initWithElement:stanza];
        id<XMPPDispatcherDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [delegate dispatcher:self willSendDocument:document];
        });
    }

    XMPPJID *from = stanza.from;
    if (from) {

        XMPPJID *bareJID = [from bareJID];

        XMPPDispatcherConnectionHandle *handle = [_connectionsByJID objectForKey:bareJID];
        if (handle) {
            PXDocument *document = [[PXDocument alloc] initWithElement:stanza];
            if (handle.connected) {

                [handle.connection handleDocument:document completion:completion];
            } else {
                NSTimeInterval timeout = 120.0;
                NSDate *date = [NSDate dateWithTimeIntervalSinceNow:timeout];
                XMPPDispatcherImplPendingSubmission *pending = [[XMPPDispatcherImplPendingSubmission alloc] initWithDocument:document
                                                                                                                     timeout:date
                                                                                                                  completion:completion];
                [handle.pendingSubmissions addObject:pending];

                __weak typeof(self) _self = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), _operationQueue, ^{
                    typeof(self) this = _self;
                    [this xmpp_clearPendingSubmissions];
                });
            }
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

- (void)xmpp_clearPendingSubmissions
{
    NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                         code:XMPPDispatcherErrorCodeNoRoute
                                     userInfo:nil];

    [[_connectionsByJID dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(XMPPJID *jid, XMPPDispatcherConnectionHandle *handle, BOOL *_Nonnull stop) {
        for (XMPPDispatcherImplPendingSubmission *pending in [handle.pendingSubmissions copy]) {
            if ([pending.timeout timeIntervalSinceNow] <= 0) {
                if (pending.completion) {
                    pending.completion(error);
                }
                [handle.pendingSubmissions removeObject:pending];
            }
        }
    }];
}

@end

@implementation XMPPDispatcherConnectionHandle
- (instancetype)initWithConnection:(id<XMPPConnection>)connection
{
    self = [super init];
    if (self) {
        _connection = connection;
        _connected = NO;
        _pendingSubmissions = [[NSMutableArray alloc] init];
    }
    return self;
}
@end

@implementation XMPPDispatcherImplPendingSubmission
- (instancetype)initWithDocument:(PXDocument *)document timeout:(NSDate *)timeout completion:(void (^)(NSError *))completion
{
    self = [super init];
    if (self) {
        _document = document;
        _timeout = timeout;
        _completion = completion;
    }
    return self;
}
@end
