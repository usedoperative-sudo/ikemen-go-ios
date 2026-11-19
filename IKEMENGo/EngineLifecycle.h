//
//  EngineLifecycle.h
//  IKEMENGo
//
//  C-compatible bridge between the Go engine and the Objective-C app:
//   - IKSetEngineStarted: engine tells the app when rendering is ready.
//   - IKIsAppActive: engine polls UIKit directly so GPU recovery does not
//     depend on SDL lifecycle event delivery.
#ifndef IKEMENGO_ENGINE_LIFECYCLE_H
#define IKEMENGO_ENGINE_LIFECYCLE_H

#ifdef __cplusplus
extern "C" {
#endif

void IKSetEngineStarted(int started);
int IKIsAppActive(void);

#ifdef __cplusplus
}
#endif

#endif /* IKEMENGO_ENGINE_LIFECYCLE_H */
