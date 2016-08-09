//
//  XMPPIQStanza.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPIQStanza.h"

@implementation XMPPIQStanza

+ (void)load
{
    [PXDocument registerElementClass:[XMPPIQStanza class]
                    forQualifiedName:PXQN(@"jabber:client", @"iq")];
}

+ (nonnull PXDocument *)documentWithIQFrom:(nullable XMPPJID *)from to:(nullable XMPPJID *)to
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"iq"
                                                         namespace:@"jabber:client"
                                                            prefix:nil];
    if ([document.root isKindOfClass:[XMPPIQStanza class]]) {
        XMPPIQStanza *iq = (XMPPIQStanza *)[document root];
        iq.from = from;
        iq.to = to;
        iq.stanzaID = [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    return document;
}

- (XMPPIQStanzaType)type
{
    NSString *typeString = [self valueForAttribute:@"type"];
    if ([typeString isEqualToString:@"get"]) {
        return XMPPIQStanzaTypeGet;
    } else if ([typeString isEqualToString:@"set"]) {
        return XMPPIQStanzaTypeSet;
    } else if ([typeString isEqualToString:@"error"]) {
        return XMPPIQStanzaTypeError;
    } else if ([typeString isEqualToString:@"result"]) {
        return XMPPIQStanzaTypeResult;
    } else {
        return XMPPIQStanzaTypeUndefined;
    }
}

- (void)setType:(XMPPIQStanzaType)type
{
    NSString *typeString = nil;
    switch (type) {
    case XMPPIQStanzaTypeGet:
        typeString = @"get";
        break;
    case XMPPIQStanzaTypeSet:
        typeString = @"set";
        break;
    case XMPPIQStanzaTypeError:
        typeString = @"error";
        break;
    case XMPPIQStanzaTypeResult:
        typeString = @"result";
        break;
    case XMPPIQStanzaTypeUndefined:
    default:
        break;
    }
    [self setValue:typeString forAttribute:@"type"];
}

@end
