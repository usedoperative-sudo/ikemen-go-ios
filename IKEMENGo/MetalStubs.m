//
//  MetalStubs.m
//  IKEMENGo
//
//  Stub symbols for the iOS 17-only Metal class that the prebuilt MoltenVK
//  static library references (the iPhoneOS16.5 SDK lacks it). See the header
//  for the safety argument: main.m's IKApplyMoltenVKConfigOverrides sets
//  MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0, so MoltenVK's _isUsingMetalArgumentBuffers
//  is always false and the residency-set code path that would instantiate this
//  class is never reached at runtime.
//

#import "MetalStubs.h"

@implementation MTLResidencySetDescriptor

- (instancetype)init {
    self = [super init];
    if (self) {
        _label = nil;
        _initialCapacity = 0;
    }
    return self;
}

@end