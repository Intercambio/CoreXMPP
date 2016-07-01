//
//  XMPPDataFormField.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPDataFormOption.h"

typedef NS_ENUM(NSUInteger, XMPPDataFormFieldType) {
    XMPPDataFormFieldTypeUndefined,
    XMPPDataFormFieldTypeBoolean,
    XMPPDataFormFieldTypeFixed,
    XMPPDataFormFieldTypeHidden,
    XMPPDataFormFieldTypeJIDMulti,
    XMPPDataFormFieldTypeJIDSingle,
    XMPPDataFormFieldTypeListMulti,
    XMPPDataFormFieldTypeListSingle,
    XMPPDataFormFieldTypeTextMulti,
    XMPPDataFormFieldTypeTextPrivate,
    XMPPDataFormFieldTypeTextSingle
};

@interface XMPPDataFormField : PXElement

@property (nonatomic, readwrite) NSString *identifier;
@property (nonatomic, readwrite) XMPPDataFormFieldType type;
@property (nonatomic, readwrite) NSString *label;
@property (nonatomic, readwrite) NSString *text; // field description
@property (nonatomic, readwrite) BOOL required;

#pragma mark Manage Options
@property (nonatomic, readonly) NSArray<XMPPDataFormOption *> *options;
- (XMPPDataFormOption *)addOptionWithLabel:(NSString *)label;
- (void)removeOption:(XMPPDataFormOption *)option;

#pragma mark Manage Value
@property (nonatomic, readwrite) id value;

@end
