//
//  XMPPConnection.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 26.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanzaHandler.h"

@protocol XMPPConnection <XMPPStanzaHandler>
@property (nonatomic, weak) id<XMPPStanzaHandler> stanzaHandler;
@end
