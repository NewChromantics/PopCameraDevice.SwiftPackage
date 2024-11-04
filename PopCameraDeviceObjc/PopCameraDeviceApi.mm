#define DLL_EXPORT extern"C"
#include "PopCameraDevice_Osx/PopCameraDevice.h"

#import "include/PopCameraDeviceApi.h"
#import <Foundation/Foundation.h>
#include <array>
#include <iostream>
#include <mutex>	//	scoped_lock


DLL_EXPORT NSString*__nonnull PopCameraDeviceObjc_PeekNextFrame(int Instance,std::vector<char>& JsonBuffer);
FrameWithData*__nonnull PopCameraDeviceObjc_PopFrame(int Instance,int Plane0Size);


@implementation FrameWithData

@end



@implementation PopCameraDeviceInstanceWrapper
{
	int					instance;
	std::vector<char>	jsonBuffer;		//	allocate once!
	std::mutex			jsonBufferLock;	//	just in case something calls class this multiple times
}

- (id)init
{
	self = [super init];
	instance = PopCameraDevice_NullInstance;
	return self;
}

- (void)allocateWithSerial:(NSString*__nonnull)serial options:(NSDictionary*__nonnull)options error:(NSError**)throwError __attribute__((swift_error(nonnull_error)));
{
	*throwError = nil;
	try
	{
		@try
		{
			instance = PopCameraDeviceObjc_CreateCameraDevice( serial, options );
		}
		@catch (NSException* exception)
		{
			//*throwError = [NSError errorWithDomain:exception.reason code:0 userInfo:nil];
			throw std::runtime_error(exception.reason.UTF8String);
		}
	}
	catch (std::exception& e)
	{
		//*throwError = [NSError errorWithDomain:@"PopMp4 allocate" code:0 userInfo:nil];
		NSString* error = [NSString stringWithUTF8String:e.what()];
		*throwError = [NSError errorWithDomain:error code:0 userInfo:nil];
		//*throwError = GetError(exception);
	}
}

- (void)free
{
	PopCameraDevice_FreeCameraDevice(instance);
	instance = PopCameraDevice_NullInstance;
}


- (NSString*__nullable)peekNextFrameJson:(NSError**)throwError __attribute__((swift_error(nonnull_error)))
{
	*throwError = nil;
	try
	{
		@try
		{
			//	gr: cant set c++20 in swiftpackage!
			//std::scoped_lock Lock(jsonBufferLock);
			std::lock_guard<std::mutex> lock(jsonBufferLock);
			return PopCameraDeviceObjc_PeekNextFrame(instance, jsonBuffer);
		}
		@catch (NSException* exception)
		{
			//*throwError = [NSError errorWithDomain:exception.reason code:0 userInfo:nil];
			throw std::runtime_error(exception.reason.UTF8String);
		}
	}
	catch (std::exception& e)
	{
		NSString* error = [NSString stringWithUTF8String:e.what()];
		*throwError = [NSError errorWithDomain:error code:0 userInfo:nil];
	}
}

- (FrameWithData*__nonnull)popNextFrame:(int)Plane0Size error:(NSError**__nonnull)throwError __attribute__((swift_error(nonnull_error)));
{
	*throwError = nil;
	try
	{
		@try
		{
			return PopCameraDeviceObjc_PopFrame( instance, Plane0Size );
		}
		@catch (NSException* exception)
		{
			//*throwError = [NSError errorWithDomain:exception.reason code:0 userInfo:nil];
			throw std::runtime_error(exception.reason.UTF8String);
		}
	}
	catch (std::exception& e)
	{
		NSString* error = [NSString stringWithUTF8String:e.what()];
		*throwError = [NSError errorWithDomain:error code:0 userInfo:nil];
	}
}


@end


FrameWithData*__nonnull PopCameraDeviceObjc_PopFrame(int Instance,int Plane0Size)
{
	/*
	 Resource.meta = @(JsonBuffer.data());
	 if ( !Timeout )
	 Resource.data = [NSData dataWithBytes:DataBuffer.data() length:DataSize];
	 */
	//	todo: pool this
	std::vector<uint8_t> Plane0Buffer;
	Plane0Buffer.resize(Plane0Size);
	
	uint8_t *Plane0 = Plane0Buffer.data();
	//int32_t Plane0Size = 0;
	uint8_t *Plane1 = nullptr;
	int32_t Plane1Size = 0;
	uint8_t *Plane2 = nullptr;
	int32_t Plane2Size = 0;
	
	int FrameNumber = ::PopCameraDevice_PopNextFrame( Instance, nullptr, 0, Plane0, Plane0Size, Plane1, Plane1Size, Plane2, Plane2Size );
	if ( FrameNumber < 0 )
	{
		throw std::runtime_error("PopCameraDevice_PopNextFrame failed");
	}
	
	FrameWithData* Frame = [FrameWithData alloc];
	//Resource.meta = @("{}");
	Frame.plane0 = [NSData dataWithBytes:Plane0Buffer.data() length:Plane0Buffer.size()];
	
	return Frame;
}


//	to be visible in swift, the declaration is in header.
//	but all headers for swift are in C (despite objc types??) and are not mangled
//	therefore with mm (c++) the name needs unmangling
DLL_EXPORT NSString* PopCameraDeviceObjc_GetVersion()
{
	auto VersionThousand = PopCameraDevice_GetVersionThousand();
	//auto VersionThousand = 0;
	auto Major = (VersionThousand/1000/1000) % 1000;
	auto Minor = (VersionThousand/1000) % 1000;
	auto Patch = (VersionThousand) % 1000;
	return [NSString stringWithFormat:@"%d.%d.%d", Major, Minor, Patch ];
}


NSString*__nonnull PopCameraDeviceObjc_EnumCameraDevicesJson()
{
	std::vector<char> JsonBuffer;
	JsonBuffer.resize(2*1024*1024);
	PopCameraDevice_EnumCameraDevicesJson( JsonBuffer.data(), JsonBuffer.size() );
	
	auto Length = std::strlen(JsonBuffer.data());
	if ( Length > 512*1024 )
	{
		auto LengthKb = Length / 1024;
		std::cerr << "Warning; PopCameraDevice_EnumCameraDevicesJson json is " << LengthKb << "kb" << std::endl;
	}
	auto Json = [NSString stringWithUTF8String: JsonBuffer.data()];
	//auto JsonData = [NSData dataWithBytes:JsonBuffer.data() length:JsonBuffer.size()];
	auto JsonData = [NSData dataWithBytes:JsonBuffer.data() length:Length];
	
	NSError* JsonParseError = nil;
	auto Dictionary = [NSJSONSerialization JSONObjectWithData:JsonData options:NSJSONReadingMutableContainers error:&JsonParseError];
	
	//return Dictionary;
	return Json;
}



DLL_EXPORT int PopCameraDeviceObjc_CreateCameraDevice(NSString* Serial,NSDictionary* Options=@{})
{
	std::vector<char> ErrorBuffer(100*1024);
/*
	NSDictionary* Options =
	@{
	};
 */
	NSData* OptionsJsonData = [NSJSONSerialization dataWithJSONObject:Options options:NSJSONWritingPrettyPrinted error:nil];
	NSString* OptionsJsonString = [[NSString alloc] initWithData:OptionsJsonData encoding:NSUTF8StringEncoding];
	const char* OptionsJsonStringC = [OptionsJsonString UTF8String];
	const char* NameStringC = [Serial UTF8String];

	auto Instance = ::PopCameraDevice_CreateCameraDevice(NameStringC, OptionsJsonStringC, ErrorBuffer.data(), ErrorBuffer.size() );

	//auto Error = [NSString stringWithUTF8String: ErrorBuffer.data()];
	auto Error = std::string( ErrorBuffer.data() );

	if ( !Error.empty() )
	//if ( Error.length > 0 )
		//@throw([NSException exceptionWithName:@"Error allocating MP4 decoder" reason:Error userInfo:nil]);
		throw std::runtime_error(Error);
	
	if ( Instance == PopCameraDevice_NullInstance )
		//@throw([NSException exceptionWithName:@"Error allocating MP4 decoder" reason:@"null returned" userInfo:nil]);
		throw std::runtime_error("Failed to allocate PopCameraDevice instance");
	
	return Instance;
}

DLL_EXPORT NSString*__nullable PopCameraDeviceObjc_PeekNextFrame(int Instance,std::vector<char>& JsonBuffer)
{
	JsonBuffer.resize(2*1024*1024);
	int NextFrame = PopCameraDevice_PeekNextFrame( Instance, JsonBuffer.data(), JsonBuffer.size() );
	
	//	no frame
	//	gr: if there's an error (bad instance) do we get -1 AND some data?
	if ( NextFrame == -1 )
		return nil;
	
	auto Length = std::strlen(JsonBuffer.data());
	if ( Length > 512*1024 )
	{
		auto LengthKb = Length / 1024;
		std::cerr << "Warning; PopMp4_GetDecoderState json is " << LengthKb << "kb" << std::endl;
	}
	auto Json = [NSString stringWithUTF8String: JsonBuffer.data()];
	//auto JsonData = [NSData dataWithBytes:JsonBuffer.data() length:JsonBuffer.size()];
	auto JsonData = [NSData dataWithBytes:JsonBuffer.data() length:Length];

	NSError* JsonParseError = nil;
	auto Dictionary = [NSJSONSerialization JSONObjectWithData:JsonData options:NSJSONReadingMutableContainers error:&JsonParseError];
	
	//return Dictionary;
	return Json;
}
