//
//  XMPPDataFormOption.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

@interface XMPPDataFormOption : PXElement

@property (nonatomic, readwrite) NSString *label;
@property (nonatomic, readwrite) id value;

@end
