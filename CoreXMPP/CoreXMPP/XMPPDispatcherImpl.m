//
//  XMPPDispatcher.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

@import Foundation;
@import XMPPFoundation;

#import <PureXML/PureXML.h>

#import "XMPPDispatcherImpl.h"
#import "XMPPError.h"

NSString *_Nonnull const XMPPDispatcherErrorDomain = @"XMPPDispatcherErrorDomain";

@interface XMPPDispatcherImpl_PendingSubmission : NSObject
@property (nonatomic, readwrite) NSDate *timeout;
@property (nonatomic, readwrite) PXDocument *document;
@property (nonatomic, readwrite) void (^completion)(NSError *);
@end

@implementation XMPPDispatcherImpl_PendingSubmission
@end

@interface XMPPDispatcherImpl () {
    dispatch_queue_t _operationQueue;
    NSMapTable *_offlineConnectionsByJID;
    NSMapTable *_onlineConnectionsByJID;
    NSMapTable *_pendingSubmissionsByConnection;
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

        _offlineConnectionsByJID = [NSMapTable strongToWeakObjectsMapTable];
        _onlineConnectionsByJID = [NSMapTable strongToWeakObjectsMapTable];
        _pendingSubmissionsByConnection = [NSMapTable weakToStrongObjectsMapTable];
        
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
        [connectionsByJID addEntriesFromDictionary:[_offlineConnectionsByJID dictionaryRepresentation]];
        [connectionsByJID addEntriesFromDictionary:[_onlineConnectionsByJID dictionaryRepresentation]];
    });
    return connectionsByJID;
}

- (void)setConnection:(id<XMPPConnection>)connection forJID:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        connection.connectionDelegate = self;
        [_onlineConnectionsByJID removeObjectForKey:JID];
        [_offlineConnectionsByJID setObject:connection forKey:[JID bareJID]];
        [_pendingSubmissionsByConnection setObject:[[NSMutableArray alloc] init] forKey:connection];
    });
}

- (void)removeConnectionForJID:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        [_offlineConnectionsByJID removeObjectForKey:[JID bareJID]];
        [_onlineConnectionsByJID removeObjectForKey:[JID bareJID]];
        for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
            [handler didDisconnect:[JID bareJID]];
        }
    });
}

- (void)removeConnection:(id<XMPPConnection>)connection
{
    dispatch_async(_operationQueue, ^{
        NSMutableSet *jids = [[NSMutableSet alloc] init];
        
        [[_onlineConnectionsByJID dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(XMPPJID *jid, id<XMPPConnection> onlineConnection, BOOL * _Nonnull stop) {
            if (onlineConnection == connection) {
                [_onlineConnectionsByJID removeObjectForKey:jid];
                [jids addObject:jid];
            }
        }];
        
        [[_offlineConnectionsByJID dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(XMPPJID *jid, id<XMPPConnection> offlineConnection, BOOL * _Nonnull stop) {
            if (offlineConnection == connection) {
                [_offlineConnectionsByJID removeObjectForKey:jid];
                [jids addObject:jid];
            }
        }];
        
        for (XMPPJID *jid in jids) {
            for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                [handler didDisconnect:jid];
            }
        }
    });
}

#pragma mark Manage Handlers

- (void)addHandler:(id)handler
{
    [self addHandler:handler withIQQueryQNames:nil features:nil];
}

- (void)addHandler:(id)handler withIQQueryQNames:(NSArray *)queryQNames features:(nullable NSArray<XMPPFeature *> *)features
{
    if ([handler conformsToProtocol:@protocol(XMPPConnectionHandler)] ||
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
        if (connection == [_offlineConnectionsByJID objectForKey:[JID bareJID]]) {
            
            [_offlineConnectionsByJID removeObjectForKey:[JID bareJID]];
            [_onlineConnectionsByJID setObject:connection forKey:[JID bareJID]];
            
            NSMutableArray *pendingSubmissions = [_pendingSubmissionsByConnection objectForKey:[JID bareJID]];
            for (XMPPDispatcherImpl_PendingSubmission *pendingSumbission in pendingSubmissions) {
                [connection handleDocument:pendingSumbission.document completion:pendingSumbission.completion];
            }
            [pendingSubmissions removeAllObjects];
            
            for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                [handler didConnect:JID resumed:resumed features:nil];
            }
        } else if (connection == [_onlineConnectionsByJID objectForKey:[JID bareJID]]) {
            for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                [handler didConnect:JID resumed:resumed features:nil];
            }
        }
    });
}

- (void)connection:(id<XMPPConnection>)connection didDisconnectFrom:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        if (connection == [_onlineConnectionsByJID objectForKey:[JID bareJID]]) {
            [_offlineConnectionsByJID setObject:connection forKey:[JID bareJID]];
            [_onlineConnectionsByJID removeObjectForKey:[JID bareJID]];
            for (id<XMPPConnectionHandler> handler in [self xmpp_handlersConformingToProtocol:@protocol(XMPPConnectionHandler)]) {
                [handler didDisconnect:JID];
            }
        }
    });
}

#pragma mark XMPPDocumentHandler

- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{

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
    XMPPJID *from = stanza.from;
    if (from) {
        
        XMPPJID *bareJID = [from bareJID];
        id<XMPPConnection> offlineConnection = [_onlineConnectionsByJID objectForKey:bareJID];
        id<XMPPConnection> onlineConnection = [_onlineConnectionsByJID objectForKey:bareJID];
        
        if (onlineConnection) {
            
            PXDocument *document = [[PXDocument alloc] initWithElement:stanza];
            [onlineConnection handleDocument:document completion:completion];
            
        } else if (offlineConnection) {
            
            NSMutableArray *submissions = [_pendingSubmissionsByConnection objectForKey:bareJID];
            
            NSTimeInterval timeout = 120.0;
            
            XMPPDispatcherImpl_PendingSubmission *pendingSubmission = [[XMPPDispatcherImpl_PendingSubmission alloc] init];
            pendingSubmission.timeout = [NSDate dateWithTimeIntervalSinceNow:timeout];
            pendingSubmission.document = [[PXDocument alloc] initWithElement:stanza];
            pendingSubmission.completion = completion;
            [submissions addObject:pendingSubmission];
            
            __weak typeof(self) _self = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), _operationQueue, ^{
                typeof(self) this = _self;
                [this xmpp_clearPendingSubmissions];
            });
            
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
    
    [[_pendingSubmissionsByConnection dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(id<XMPPConnection> connection,
                                                                                                    NSMutableArray *pendingSubmissions,
                                                                                                    BOOL *stop) {
        
        for (XMPPDispatcherImpl_PendingSubmission *pendingSumbission in [pendingSubmissions copy]) {
            if ([pendingSumbission.timeout timeIntervalSinceNow] <= 0) {
                if (pendingSumbission.completion) {
                    pendingSumbission.completion(error);
                }
                [pendingSubmissions removeObject:pendingSumbission];
            }
        }
    }];
}

@end
