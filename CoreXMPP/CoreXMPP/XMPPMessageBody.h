//
//  XMPPMessageBody.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

@interface XMPPMessageBody : PXElement
@property (nonatomic, readwrite, copy, nullable) NSLocale *locale;
@end
