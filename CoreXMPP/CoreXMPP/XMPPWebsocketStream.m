//
//  XMPPWebsocketStream.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <SocketRocket/SRWebSocket.h>

#import "XMPPWebsocketStream.h"

NSString * const XMPPWebsocketStreamURLKey = @"XMPPWebsocketStreamURLKey";

@interface XMPPWebsocketStream () <SRWebSocketDelegate> {
    SRWebSocket *_websocket;
}

@end

@implementation XMPPWebsocketStream

@end
