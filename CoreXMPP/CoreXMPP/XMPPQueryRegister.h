//
//  XMPPQueryRegister.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 28.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

@interface XMPPQueryRegister : PXElement

@property (nonatomic, readwrite, copy) PXDocument *registrationForm;

@end
