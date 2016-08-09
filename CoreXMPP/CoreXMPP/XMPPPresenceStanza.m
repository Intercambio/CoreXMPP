//
//  XMPPPresenceStanza.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPPresenceStanza.h"

@implementation XMPPPresenceStanza

+ (void)load
{
    [PXDocument registerElementClass:[XMPPPresenceStanza class]
                    forQualifiedName:PXQN(@"jabber:client", @"presence")];
}

+ (nonnull PXDocument *)documentWithPresenceFrom:(nullable XMPPJID *)from to:(nullable XMPPJID *)to
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"presence"
                                                         namespace:@"jabber:client"
                                                            prefix:nil];
    if ([document.root isKindOfClass:[XMPPPresenceStanza class]]) {
        XMPPPresenceStanza *presence = (XMPPPresenceStanza *)[document root];
        presence.from = from;
        presence.to = to;
        presence.stanzaID = [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    return document;
}

- (XMPPPresenceStanzaType)type
{
    NSString *typeString = [self valueForAttribute:@"type"];
    if ([typeString isEqualToString:@"error"]) {
        return XMPPPresenceStanzaTypeError;
    } else if ([typeString isEqualToString:@"probe"]) {
        return XMPPPresenceStanzaTypeProbe;
    } else if ([typeString isEqualToString:@"subscribe"]) {
        return XMPPPresenceStanzaTypeSubscribe;
    } else if ([typeString isEqualToString:@"subscribed"]) {
        return XMPPPresenceStanzaTypeSubscribed;
    } else if ([typeString isEqualToString:@"unavailable"]) {
        return XMPPPresenceStanzaTypeUnavailable;
    } else if ([typeString isEqualToString:@"unsubscribe"]) {
        return XMPPPresenceStanzaTypeUnsubscribe;
    } else if ([typeString isEqualToString:@"unsubscribed"]) {
        return XMPPPresenceStanzaTypeUnsubscribed;
    } else {
        return XMPPPresenceStanzaTypeUndefined;
    }
}

- (void)setType:(XMPPPresenceStanzaType)type
{
    NSString *typeString = nil;
    switch (type) {
    case XMPPPresenceStanzaTypeError:
        typeString = @"error";
        break;
    case XMPPPresenceStanzaTypeProbe:
        typeString = @"probe";
        break;
    case XMPPPresenceStanzaTypeSubscribe:
        typeString = @"subscribe";
        break;
    case XMPPPresenceStanzaTypeSubscribed:
        typeString = @"subscribed";
        break;
    case XMPPPresenceStanzaTypeUnavailable:
        typeString = @"unavailable";
        break;
    case XMPPPresenceStanzaTypeUnsubscribe:
        typeString = @"unsubscribe";
        break;
    case XMPPPresenceStanzaTypeUnsubscribed:
        typeString = @"unsubscribed";
        break;
    case XMPPPresenceStanzaTypeUndefined:
    default:
        break;
    }
    [self setValue:typeString forAttribute:@"type"];
}

@end
