//
//  MetalStubs.h
//  IKEMENGo
//
//  MoltenVK 1.4.2 (prelinked, statically force-loaded into the app) refers to
//  MTLResidencySetDescriptor and its metaclass. These symbols were introduced
//  in the iOS 17 Metal API and do not exist in the iPhoneOS16.5 SDK tbd files,
//  so the Mach-O linker cannot resolve them.
//
//  We provide a real (if minimal) class definition here purely so the symbols
//  exist at link time. MoltenVK only exercises the residency-set code path
//  under `@available(iOS 17.0, ...)` checks, so on iOS 15/16 devices — the
//  target of this build — this stub is never instantiated.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTLResidencySetDescriptor : NSObject

@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic) NSUInteger initialCapacity;

@end

NS_ASSUME_NONNULL_END