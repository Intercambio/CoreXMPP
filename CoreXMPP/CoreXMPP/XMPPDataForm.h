//
//  XMPPDataForm.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 26.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPDataFormField.h"

@class XMPPDataFormField;

typedef NS_ENUM(NSUInteger, XMPPDataFormType) {
    XMPPDataFormTypeUndefined,
    XMPPDataFormTypeCancel,
    XMPPDataFormTypeForm,
    XMPPDataFormTypeResult,
    XMPPDataFormTypeSubmit
};

@interface XMPPDataForm : PXElement

@property (nonatomic, readwrite) NSString *identifier;
@property (nonatomic, readwrite) XMPPDataFormType type;
@property (nonatomic, readwrite) NSString *title;
@property (nonatomic, readwrite) NSString *instructions;

#pragma mark Manage Fields
@property (nonatomic, readonly) NSArray<XMPPDataFormField *> *fields;
- (XMPPDataFormField *)addFieldWithType:(XMPPDataFormFieldType)type
                             identifier:(NSString *)identifier;
- (void)removeField:(XMPPDataFormField *)field;

- (XMPPDataFormField *)fieldWithIdentifier:(NSString *)identifier;
@end
