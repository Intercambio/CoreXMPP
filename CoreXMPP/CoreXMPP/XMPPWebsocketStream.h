//
//  XMPPWebsocketStream.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStream.h"
#import <Foundation/Foundation.h>

extern NSString *const XMPPWebsocketStreamURLKey NS_SWIFT_NAME(WebsocketStreamURLKey);

NS_SWIFT_NAME(WebsocketStream)
@interface XMPPWebsocketStream : XMPPStream

@end
