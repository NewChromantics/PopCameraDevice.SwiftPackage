#define DLL_EXPORT extern"C"
//#define DLL_EXPORT
//#include "../PopH264.xcframework/macos-arm64_x86_64/PopH264_Osx.framework/Versions/A/Headers/PopH264.h"
#include "PopCameraDevice_Osx/PopCameraDevice.h"

//#include "PopMp4.h"
#import "include/PopCameraDeviceApi.h"
#import <Foundation/Foundation.h>
#include <array>
#include <iostream>
#include <mutex>	//	scoped_lock

/*
NSString*__nonnull PopH264_PeekFrameJson(int Instance,std::vector<char>& JsonBuffer);



@implementation PopH264DecoderWrapper
{
	int					instance;
	std::vector<char>	jsonBuffer;		//	allocate once!
	std::mutex			jsonBufferLock;	//	just in case something calls class this multiple times
}

- (id)init
{
	self = [super init];
	instance = PopH264_NullInstance;
	return self;
}

- (void)allocate:(NSError**)throwError __attribute__((swift_error(nonnull_error)))
{
	*throwError = nil;
	try
	{
		@try
		{
			instance = PopH264_AllocDecoder();
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
	PopH264_DestroyDecoder(instance);
	//mInstance = PopMp4Decoder_NullInstance;
}


- (NSString*__nonnull)peekNextFrameJson:(NSError**)throwError __attribute__((swift_error(nonnull_error)))
{
	*throwError = nil;
	try
	{
		@try
		{
			//	gr: cant set c++20 in swiftpackage!
			//std::scoped_lock Lock(jsonBufferLock);
			std::lock_guard<std::mutex> lock(jsonBufferLock);
			return PopH264_PeekFrameJson(instance, jsonBuffer);
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

- (int)popNextFrame
{
	return PopH264_PopFrame( instance, nullptr, 0, nullptr, 0, nullptr, 0 );
}

- (void)pushData:(NSData*__nonnull)data frameNumber:(int32_t)frameNumber
{
	//uint8_t* DataAddress = reinterpret_cast<uint8_t*>(data.bytes);
	uint8_t* DataAddress = (uint8_t*)data.bytes;
	PopH264_PushData( instance, DataAddress, data.length, frameNumber);
}

- (void)pushEndOfFile
{
	PopH264_PushEndOfStream(instance);
}

@end



*/
//	to be visible in swift, the declaration is in header.
//	but all headers for swift are in C (despite objc types??) and are not mangled
//	therefore with mm (c++) the name needs unmangling
DLL_EXPORT NSString* PopCameraDevice_GetVersion_NSString()
{
	auto VersionThousand = PopCameraDevice_GetVersionThousand();
	//auto VersionThousand = 0;
	auto Major = (VersionThousand/1000/1000) % 1000;
	auto Minor = (VersionThousand/1000) % 1000;
	auto Patch = (VersionThousand) % 1000;
	return [NSString stringWithFormat:@"%d.%d.%d", Major, Minor, Patch ];
}


NSString*__nonnull PopCameraDevice_EnumCameraDevicesJsonNSString()
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


/*
DLL_EXPORT int PopH264_AllocDecoder()
{
	std::vector<char> ErrorBuffer(100*1024);

	//	gr: poph264 doesnt have a file loader
	NSDictionary* Options =
	@{
	};
	NSData* OptionsJsonData = [NSJSONSerialization dataWithJSONObject:Options options:NSJSONWritingPrettyPrinted error:nil];
	NSString* OptionsJsonString = [[NSString alloc] initWithData:OptionsJsonData encoding:NSUTF8StringEncoding];
	const char* OptionsJsonStringC = [OptionsJsonString UTF8String];

	auto Instance = ::PopH264_CreateDecoder( OptionsJsonStringC, ErrorBuffer.data(), ErrorBuffer.size() );

	//auto Error = [NSString stringWithUTF8String: ErrorBuffer.data()];
	auto Error = std::string( ErrorBuffer.data() );

	if ( !Error.empty() )
	//if ( Error.length > 0 )
		//@throw([NSException exceptionWithName:@"Error allocating MP4 decoder" reason:Error userInfo:nil]);
		throw std::runtime_error(Error);
	
	if ( Instance == PopH264_NullInstance )
		//@throw([NSException exceptionWithName:@"Error allocating MP4 decoder" reason:@"null returned" userInfo:nil]);
		throw std::runtime_error("Failed to allocate PopMp4 instance");
	
	return Instance;
}

DLL_EXPORT void PopH264_FreeDecoder(int Instance)
{
	::PopH264_FreeDecoder(Instance);
}



NSString*__nonnull PopH264_PeekFrameJson(int Instance,std::vector<char>& JsonBuffer)
{
	JsonBuffer.resize(2*1024*1024);
	PopH264_PeekFrame( Instance, JsonBuffer.data(), JsonBuffer.size() );
	
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

*/
