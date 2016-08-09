//
//  XMPPPresenceStanza.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanza.h"

typedef NS_ENUM(NSUInteger, XMPPPresenceStanzaType) {
    XMPPPresenceStanzaTypeUndefined,
    XMPPPresenceStanzaTypeError,
    XMPPPresenceStanzaTypeProbe,
    XMPPPresenceStanzaTypeSubscribe,
    XMPPPresenceStanzaTypeSubscribed,
    XMPPPresenceStanzaTypeUnavailable,
    XMPPPresenceStanzaTypeUnsubscribe,
    XMPPPresenceStanzaTypeUnsubscribed
};

@interface XMPPPresenceStanza : XMPPStanza
+ (nonnull PXDocument *)documentWithPresenceFrom:(nullable XMPPJID *)from to:(nullable XMPPJID *)to;
@property (nonatomic, readwrite) XMPPPresenceStanzaType type;
@end
