//
//  XMPPStreamStanzaHandlerProxy.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPStanzaHandler.h"
#import "XMPPStream.h"

@interface XMPPStreamStanzaHandlerProxy : NSObject <XMPPStanzaHandler>
- (instancetype)initWithStream:(XMPPStream *)stream;
@property (nonatomic, readonly) XMPPStream *stream;
@end
