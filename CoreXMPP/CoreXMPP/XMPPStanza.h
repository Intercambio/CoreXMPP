//
//  XMPPStanza.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

@class XMPPJID;

@interface XMPPStanza : PXElement
@property (nonatomic, readwrite, copy, nullable) XMPPJID *to;
@property (nonatomic, readwrite, copy, nullable) XMPPJID *from;
@property (nonatomic, readwrite, copy, nullable) NSString *stanzaID;
@end
