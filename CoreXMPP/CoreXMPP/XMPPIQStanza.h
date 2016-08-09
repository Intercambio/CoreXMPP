//
//  XMPPIQStanza.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanza.h"

typedef NS_ENUM(NSUInteger, XMPPIQStanzaType) {
    XMPPIQStanzaTypeUndefined,
    XMPPIQStanzaTypeGet,
    XMPPIQStanzaTypeSet,
    XMPPIQStanzaTypeResult,
    XMPPIQStanzaTypeError
};

@interface XMPPIQStanza : XMPPStanza
+ (nonnull PXDocument *)documentWithIQFrom:(nullable XMPPJID *)from to:(nullable XMPPJID *)to;
@property (nonatomic, readwrite) XMPPIQStanzaType type;
@end
