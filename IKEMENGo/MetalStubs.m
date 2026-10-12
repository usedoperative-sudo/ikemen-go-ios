//
//  MetalStubs.m
//  IKEMENGo
//
//  Stub symbols for the iOS 17-only Metal classes that the prebuilt MoltenVK
//  static library references (the iPhoneOS16.5 SDK lacks them). See the header
//  for why this is safe at runtime.
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