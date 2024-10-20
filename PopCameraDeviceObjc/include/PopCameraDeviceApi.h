#pragma once
/*
 
 objective-c api for swift to get to access to low level c++ stuff
 
*/
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

//	linkage from swift needs to not have extern"C" and does no mangling.
//	objective-c mangles the name so this needs to be extern"C"
#if !defined(DLL_EXPORT)
#define DLL_EXPORT
#endif

/*

//	gr: switched to an objective c class so we can use attributes which allow swift to auto-throw
//		swift exceptions which can be easily caught
//	gr: to allocate in swift, this needs to inherit from NSObject, otherwise we get an exception with no information
@interface PopH264DecoderWrapper : NSObject

@property int instance;

- (id)init;
- (void)allocate:(NSError**)throwError __attribute__((swift_error(nonnull_error)));
- (void)free;
//- (NSString*__nonnull)getDecoderStateJson:(NSError**)throwError __attribute__((swift_error(nonnull_error)));
- (NSString*__nonnull)peekNextFrameJson:(NSError**)throwError __attribute__((swift_error(nonnull_error)));
- (int)popNextFrame;
- (void)pushData:(NSData*__nonnull)data frameNumber:(int32_t)frameNumber;
- (void)pushEndOfFile;

@end
*/

//	some objective-c wrappers to the CAPI
DLL_EXPORT NSString*__nonnull PopCameraDevice_GetVersion_NSString();
//DLL_EXPORT int PopCameraDevice_AllocDecoder();
//DLL_EXPORT void PopH264_FreeDecoder(int Instance);
DLL_EXPORT NSString*__nonnull PopCameraDevice_EnumCameraDevicesJsonNSString();
