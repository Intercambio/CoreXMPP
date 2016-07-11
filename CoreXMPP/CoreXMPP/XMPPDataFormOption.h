//
//  XMPPDataFormOption.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

NS_SWIFT_NAME(DataFormOption)
@interface XMPPDataFormOption : PXElement

@property (nonatomic, readwrite) NSString *_Nullable label;
@property (nonatomic, readwrite) NSString *_Nullable value;

@end
