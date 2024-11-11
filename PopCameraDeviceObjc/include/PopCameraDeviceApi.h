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



@interface FrameWithMeta : NSObject

@property int frameNumber;
@property NSString* /*__nonnull */metaJson;
//@property NSDictionary* __nonnull meta;

@end

@interface FrameWithData : NSObject

//@property NSString* __nonnull meta;
@property int frameNumber;
@property NSData* plane0;
@property NSData* plane1;
@property NSData* plane2;

@end

//	gr: switched to an objective c class so we can use attributes which allow swift to auto-throw
//		swift exceptions which can be easily caught
//	gr: to allocate in swift, this needs to inherit from NSObject, otherwise we get an exception with no information
@interface PopCameraDeviceInstanceWrapper : NSObject

@property int instance;

- (id)init;
- (void)allocateWithSerial:(NSString*__nonnull)serial options:(NSDictionary*__nonnull)options error:(NSError**__nonnull)throwError __attribute__((swift_error(nonnull_error)));
- (void)free;

//	null string returned means no frame pending
- (FrameWithMeta*__nullable)peekNextFrameJson:(NSError**__nonnull)throwError __attribute__((swift_error(nonnull_error)));
//	__nonnull seems to have objc-release problems when throwing
- (FrameWithData*__nullable)popNextFrame:(int)Plane0Size expectedFrameNumber:(int)expectedFrameNumber error:(NSError**__nonnull)throwError __attribute__((swift_error(nonnull_error)));

@end


//	some objective-c wrappers to the CAPI
DLL_EXPORT NSString*__nonnull PopCameraDeviceObjc_GetVersion();
DLL_EXPORT NSString*__nonnull PopCameraDeviceObjc_EnumCameraDevicesJson();
DLL_EXPORT int PopCameraDeviceObjc_CreateCameraDevice(NSString* Serial,NSDictionary* Options);
