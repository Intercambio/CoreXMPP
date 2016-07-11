//
//  XMPPDataFormField.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDataFormOption.h"
#import <PureXML/PureXML.h>

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
} NS_SWIFT_NAME(DataFormFieldType);

NS_SWIFT_NAME(DataFormField)
@interface XMPPDataFormField : PXElement

@property (nonatomic, readwrite) NSString *_Nullable identifier;
@property (nonatomic, readwrite) XMPPDataFormFieldType type;
@property (nonatomic, readwrite) NSString *_Nullable label;
@property (nonatomic, readwrite) NSString *_Nullable text; // field description
@property (nonatomic, readwrite) BOOL required;

#pragma mark Manage Options
@property (nonatomic, readonly) NSArray<XMPPDataFormOption *> *_Nonnull options;
- (nonnull XMPPDataFormOption *)addOptionWithLabel:(nonnull NSString *)label NS_SWIFT_NAME(addOption(label:));
- (void)removeOption:(nonnull XMPPDataFormOption *)option NS_SWIFT_NAME(remove(_:));

#pragma mark Manage Value
@property (nonatomic, readwrite) id _Nullable value;

@end
