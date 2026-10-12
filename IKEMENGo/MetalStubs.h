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
//  exist at link time. MoltenVK would prefer this as a weak import, but the
//  linked ld64.lld supports neither -U nor -weak_import for a symbol that is
//  absent from the SDK, and -undefined dynamic_lookup risks a binary that dyld
//  may refuse to load. The remaining options were a stub class (this file) or
//  no binary at all.
//
//  This stub must never be dereferenced at runtime: MoltenVK's residency-set
//  path lives in MVKDevice::initQueues and is gated on BOTH Metal residency-set
//  support (iOS 17+) AND _isUsingMetalArgumentBuffers. main.m forces
//  MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0 (see IKApplyMoltenVKConfigOverrides),
//  which makes _isUsingMetalArgumentBuffers false on every device, so the stub
//  is never instantiated. Do not remove that env override without replacing this
//  class with a proper weak-import mechanism.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTLResidencySetDescriptor : NSObject

@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic) NSUInteger initialCapacity;

@end

NS_ASSUME_NONNULL_END