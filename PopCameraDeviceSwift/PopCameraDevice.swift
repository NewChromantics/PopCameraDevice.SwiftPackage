import SwiftUI
//import CoreMediaIO	//	macos
import CoreMedia	//	ios
import PopCameraDeviceCApi
import VideoToolbox
import Accelerate

#if canImport(UIKit)	//	ios
#else
public typealias UIImage = NSImage
#endif

public struct PopError : LocalizedError
{
	let error: String
	
	public init(_ description: String) {
		error = description
	}
	
	public var errorDescription: String? {
		error
	}
}

public func PixelBufferToNativeImage(_ pixelBuffer:CVPixelBuffer) throws -> UIImage
{
	let cg = try PixelBufferToCGImage(pixelBuffer)
#if os(iOS)
	let uiimage = UIImage(cgImage:cg)
#else
	//	zero = auto size
	let uiimage = NSImage(cgImage:cg, size:.zero)
#endif
	return uiimage
}

public func PixelBufferToSwiftImage(_ pixelBuffer:CVPixelBuffer) throws -> Image
{
	let nativeImage = try PixelBufferToNativeImage(pixelBuffer)
#if os(iOS)
	return try Image(uiImage: nativeImage )
#else
	return try Image(nsImage: nativeImage)
#endif
}


public func PixelBufferToCGImage(_ pb:CVPixelBuffer) throws -> CGImage
{
	var cgImage: CGImage?
	
	let InputWidth = CVPixelBufferGetWidth(pb)
	let InputHeight = CVPixelBufferGetHeight(pb)
	let InputFormatName = CVPixelBufferGetPixelFormatName(pixelBuffer:pb)
	let inputFormat = CVPixelBufferGetPixelFormatType(pb)

	//	ipad/ios18 can't auto convert kCVPixelFormatType_OneComponent32Float
	//	macos and iphone15 convert this into a red image
	//	using the accellerate framework may be a generic solution here
	/*
	if ( inputFormat == kCVPixelFormatType_OneComponent32Float )
	{
		var vimagebuffer = vImage_Buffer()
		var rgbCGImgFormat : vImage_CGImageFormat = vImage_CGImageFormat(
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			colorSpace: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo(rawValue:kCGBitmapByteOrder32Host.rawValue/* | kCGImageAlphaNoneSkipFirst.*/)
		)!
		
		/*
		func vImageBuffer_InitWithCVPixelBuffer(
			_ buffer: UnsafeMutablePointer<vImage_Buffer>,
			_ desiredFormat: UnsafeMutablePointer<vImage_CGImageFormat>,
			_ cvPixelBuffer: CVPixelBuffer,
			_ cvImageFormat: vImageCVImageFormat!,
			_ backgroundColor: UnsafePointer<CGFloat>!,
			_ flags: vImage_Flags
		) -> vImage_Error
		 */
		let backgroundColour : [CGFloat] = [1,1,1,1]
		//vImageCVImageFormatRef cvImgFormatRef;
		var cvImgFormatPtr : Unmanaged<vImageCVImageFormat> = vImageCVImageFormat_CreateWithCVPixelBuffer(pb)!
		var cvImgFormat : vImageCVImageFormat = cvImgFormatPtr.takeRetainedValue()
		let flags = vImage_Flags()
		let error = vImageBuffer_InitWithCVPixelBuffer( &vimagebuffer, &rgbCGImgFormat, pb, cvImgFormat, backgroundColour, flags )
		if ( error != 0 )
		{
			throw PopError("Failed to make vimage \(GetVideoToolboxError(OSStatus(error)))")
		}
	}
	*/
	
	let Result = VTCreateCGImageFromCVPixelBuffer( pb, options:nil, imageOut:&cgImage)

	if ( Result != 0 || cgImage == nil )
	{
		throw PopError("VideoToolbox failed to create CGImage (\(InputWidth)x\(InputHeight)[\(InputFormatName)]; \(GetVideoToolboxError(Result))")
	}
	return cgImage!
}


public func GetVersion() -> String
{
	let VersionThousand = PopCameraDevice_GetVersionThousand()
	let Major = (VersionThousand/1000/1000) % 1000;
	let Minor = (VersionThousand/1000) % 1000;
	let Patch = (VersionThousand) % 1000;
	return "\(Major).\(Minor).\(Patch)"
	
	//var Version = PopCameraDeviceObjc_GetVersion()
	//return Version
}


public struct StreamImageFormat
{
	public var width : UInt32
	public var height : UInt32
	public var pixelFormat : CMPixelFormatType // kCVPixelFormatType_32BGRA
	
	public init(width: UInt32, height: UInt32, pixelFormat: CMPixelFormatType)
	{
		self.width = width
		self.height = height
		self.pixelFormat = pixelFormat
	}
	
	public func AsString() -> String
	{
		return "PixelFormat^\(width)x\(height)"
	}
	
	public func GetFormatDescripton() -> CMVideoFormatDescription
	{
		var videoFormat : CMFormatDescription!
		let dims = CMVideoDimensions(width: Int32(self.width), height: Int32(self.height))
		CMVideoFormatDescriptionCreate(
			allocator: kCFAllocatorDefault,
			codecType: pixelFormat,
			width: dims.width,
			height: dims.height,
			extensions: nil,
			formatDescriptionOut: &videoFormat
		)
		
		return videoFormat
	}
}

public struct EnumDeviceMeta : Decodable
{
	public let Serial : String
	public let Formats : [String] = []
	
	public init(Serial: String)
	{
		self.Serial = Serial
	}

	public func GetStreamFormats() -> [StreamImageFormat]
	{
		//	todo: parse .Formats
		let RgbLow = StreamImageFormat(width: 320, height: 240, pixelFormat: kCMPixelFormat_24RGB )
		let RgbMed = StreamImageFormat(width: 640, height: 480, pixelFormat: kCMPixelFormat_24RGB )
		let YuvMed = StreamImageFormat(width: 640, height: 480, pixelFormat: kCMPixelFormat_422YpCbCr8_yuvs )
		return [RgbLow,RgbMed,YuvMed]
	}
	
	public func GetStreamDepthFormats() -> [StreamImageFormat]
	{
		let Depth = StreamImageFormat( width: 640, height: 480, pixelFormat: kCMPixelFormat_24RGB )
		return []
	}
}

public struct EnumMeta: Decodable
{
	public let Devices : [EnumDeviceMeta]
}


public func EnumDevices(requireSerialPrefix:String="") throws -> [EnumDeviceMeta]
{
	let JsonBufferSize = 1024 * 10
	let JsonBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: JsonBufferSize)
	defer
	{
		JsonBuffer.deallocate()
	}
	PopCameraDevice_EnumCameraDevicesJson(JsonBuffer, Int32(JsonBufferSize))
	let json = String(cString: JsonBuffer)
	
	//	get json and decode to structs
	//let json = PopCameraDeviceObjc_EnumCameraDevicesJson()
	let jsonData = json.data(using: .utf8)!
	print(json)
	let EnumMeta: EnumMeta = try JSONDecoder().decode(EnumMeta.self, from: jsonData)
	
	let FilteredDevices = EnumMeta.Devices.filter { deviceMeta in
		return deviceMeta.Serial.starts(with: requireSerialPrefix)
	}
	return FilteredDevices
}



public struct PlaneMeta: Decodable
{
	public let Channels : Int32
	public let DataSize : Int32
	public let Format : String	//	make this an enum
	public let Width : Int32
	public let Height : Int32
	public var BytesPerRow : Int {	return Int(Width * Height * Channels)	}	//	note: format may be non 1 byte
	
	public func GetPixelFormat() throws ->CMPixelFormatType
	{
		switch Format
		{
				//VideoToolbox failed to create CGImage; -12902 (bad param)
			//case "RGB":	return kCVPixelFormatType_24RGB
				
			//case "uyvy_8888":	return kCVPixelFormatType_422YpCbCr8;
				
			default:
				return kCVPixelFormatType_32BGRA
				throw PopError("Unhandled pixel format type \(Format)")
		}
	}
	
	public func GetStreamImageFormat() throws -> StreamImageFormat
	{
		return StreamImageFormat( width: UInt32(Width), height: UInt32(Height), pixelFormat: try GetPixelFormat() )
	}
	
	public func ConvertDepth() -> PlaneMeta
	{
		//	convert any "one channel" depth to its correct 2channel
		if ( self.Format != "Depth16mm" )
		{
			return self
		}
		let NewChannels = Int32(1)
		let NewWidth = Width / 2
		let NewHeight = Height / 2
		let DepthMeta = PlaneMeta(Channels: NewChannels, DataSize: self.DataSize, Format: self.Format, Width: NewWidth, Height: NewHeight)
		return DepthMeta
	}
}


public struct CameraMeta: Decodable
{
	public var HorizontalFov : Double? = nil
	public var VerticalFov : Double? = nil
}


public struct FrameMeta: Decodable
{
	public var Error : String? = nil
	public var Planes : [PlaneMeta]? = nil
	public var Camera : CameraMeta? = nil
	public var PendingFrames : Int? = nil
	public var SreamName : String? = nil

	public init(error:String?=nil)
	{
		Error = error
	}

}

public struct Frame
{
	public var Meta : FrameMeta
	public var PixelData : Data?
	public var FrameNumber : Int32
	public var width : Int { Int(Meta.Planes?.first?.Width ?? 0) }
	public var height : Int { Int(Meta.Planes?.first?.Height ?? 0) }

	/*
	fileprivate extension CIImage {
		var image: Image? {
			let ciContext = CIContext()
			guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
			return Image(decorative: cgImage, scale: 1, orientation: .up)
		}
	}
	 */
	public func CreateSwiftImage() throws -> Image
	{
		let pixelBuffer = try CreateCoreVideoPixelBuffer()
		return try PixelBufferToSwiftImage(pixelBuffer)
	}
	
	public func CreateNativeImage() throws -> UIImage
	{
		let pixelBuffer = try CreateCoreVideoPixelBuffer()
		return try PixelBufferToNativeImage(pixelBuffer)
	}
	
	public func CreateCGImage() throws -> CGImage
	{
		let pixelBuffer = try CreateCoreVideoPixelBuffer()
		//	this causes a memmove - maybe there's faster straight-to-cgimage option
		let cg = try PixelBufferToCGImage(pixelBuffer)
		return cg
	}

	
	public func CreateCoreVideoPixelBuffer(pool:CVPixelBufferPool?=nil,poolAttributes:NSDictionary?=nil) throws -> CVPixelBuffer
	{
		guard var PixelData else
		{
			throw PopError("Missing pixels")
		}
		guard let plane0 = Meta.Planes?[0] else
		{
			throw PopError("Missing planes")
		}
		let allocator : CFAllocator? = nil
		let w = Int(plane0.Width)
		let h = Int(plane0.Height)
		let fmt : OSType = try plane0.GetPixelFormat()
		let PlaneCount = 1
		let pixelBufferAttributes : CFDictionary? = nil
		var pixelBufferMaybe : CVPixelBuffer!
		//try PixelData.withUnsafeMutableBytes	//	mutable if using CreateWithBytes
		try PixelData.withUnsafeBytes	//	mutable if using CreateWithBytes
		{
			(pixelBytes: UnsafePointer<UInt8>) /*-> Int*/ in
			
			//	CVPixelBufferCreateWithBytes points at original pointer, not a copy
			//	todo: use this and manage release with the release callback
			//let Result = CVPixelBufferCreateWithBytes( allocator, w, h, fmt, pixelBytes, plane0.BytesPerRow, nil, nil, pixelBufferAttributes, &pixelBufferMaybe )
			//CVPixelBufferCreateWithPlanarBytes( allocator, w, h, fmt, pixelBytes, PixelData.count, t, PlaneCount, ess: UnsafeMutablePointer<UnsafeMutableRawPointer?>, _ planeWidth: UnsafeMutablePointer<Int>, _ planeHeight: UnsafeMutablePointer<Int>, _ planeBytesPerRow: UnsafeMutablePointer<Int>, nil, nil, pixelBufferAttributes, pixelBufferMaybe ) -> CVReturn
			//	create empty buffer & copy into
			let Result = CVPixelBufferCreate( allocator, w, h, fmt, pixelBufferAttributes, &pixelBufferMaybe )
			if ( Result != 0 )
			{
				throw PopError("Failed to allocate pixel buffer; error=\(Result)")
			}
			guard let pixelBuffer = pixelBufferMaybe else
			{
				throw PopError("Failed to allocated pixel buffer, no error - null pixelbuffer")
			}
			CVPixelBufferLockBaseAddress(pixelBuffer, [])
			let destData = CVPixelBufferGetBaseAddress(pixelBuffer)
			
			let destDataSize = CVPixelBufferGetDataSize(pixelBuffer)
			let copySize = min( destDataSize, PixelData.count )
			destData?.copyMemory(from: pixelBytes, byteCount: copySize)
			CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
		}
		return pixelBufferMaybe!
	}
}

public class PopCameraDeviceInstance
{
	var instance = Int32(PopCameraDevice_NullInstance)
	var allocationError : String?

	static let JsonBufferSize = 1024 * 10
	private var PeekMetaJsonBuffer = Data(count: PopCameraDeviceInstance.JsonBufferSize )
	private var PopMetaJsonBuffer = Data(count: PopCameraDeviceInstance.JsonBufferSize )
	
	public init(serial:String,options:[String:Any])
	{
		do
		{
			let jsonData = try JSONSerialization.data(withJSONObject: options, options: JSONSerialization.WritingOptions.prettyPrinted)
			let json = NSString(data: jsonData as Data, encoding: NSUTF8StringEncoding)! as String
			
			//	gr: we can do ErrorBuffer as a string, and then get an unsafe pointer - but we need to generate a giant string first?
			let ErrorBufferSize = 1000
			var ErrorBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: ErrorBufferSize)
			defer
			{
				ErrorBuffer.deallocate()
			}
			//	init with terminator
			ErrorBuffer[0] = 0
			
			self.instance = PopCameraDevice_CreateCameraDevice(serial, json, ErrorBuffer, Int32(ErrorBufferSize) )
			
			//	grab string & free the buffer we made
			let Error = String(cString: ErrorBuffer)
			if ( !Error.isEmpty )
			{
				throw PopError(Error)
			}
			
			if ( instance == PopCameraDevice_NullInstance )
			{
				throw PopError("Failed to allocated instance (no error)")
			}
		
			var Version = GetVersion()
			print("Allocated instance \(instance); PopCameraDevice version \(Version)")
		}
		catch
		{
			allocationError = error.localizedDescription
		}
	}
	
	deinit
	{
		Free()
	}
	
	public func Free()
	{
		PopCameraDevice_FreeCameraDevice(instance)
	}
	
	func PeekFrameNumberAndMeta() throws -> (Int32,FrameMeta)?
	{
		let PeekMetaJsonBufferSize = Int32(PeekMetaJsonBuffer.count)
		var (PeekFrameNumber,FrameMetaJson) = PeekMetaJsonBuffer.withUnsafeMutableBytes 
		{
			(JsonBuffer8:UnsafeMutablePointer<CChar>) in
			//	init with terminator
			JsonBuffer8[0] = 0
			var FrameNumber = PopCameraDevice_PeekNextFrame( instance, JsonBuffer8, PeekMetaJsonBufferSize )
			let FrameMetaJson = String(cString: JsonBuffer8)
			return (FrameNumber,FrameMetaJson)
		}
		
		//	gr: this is returning negative number - internally stored as 64bit
		//		the popcamera api needs to change to either return 32bit numbers (fraught with problems)
		//		or api return 64bit and application deal with it
		let InvalidFrameNumber = PeekFrameNumber == -1
		PeekFrameNumber = PeekFrameNumber & 0x7fffffff
		
		//	decode meta
		var Meta : FrameMeta? = nil
		
		do
		{
			//	grab string & free the buffer we made
			let NextFrameMetaJsonData = FrameMetaJson.data(using: .utf8)!
			Meta = try JSONDecoder().decode(FrameMeta.self, from: NextFrameMetaJsonData)
			if let error = Meta!.Error
			{
				throw PopError("Popped frame error \(error)")
			}
		}
		catch let error
		{
			//	failed to decode json, but that's fine if nothing was popped (assuming nothing written to buffer)
			if ( !InvalidFrameNumber )
			{
				throw error
			}
		}
		
		if ( InvalidFrameNumber )
		{
			return nil
		}
		
		guard let Meta else
		{
			throw PopError("Failed to decode frame's meta")
		}		
		return (PeekFrameNumber,Meta)
	}
	
	public func PopNextFrame() throws -> Frame?
	{
		if let allocationError
		{
			throw PopError( allocationError )
		}
		
		do
		{
			guard let (PeekFrameNumber,Meta) = try PeekFrameNumberAndMeta() else
			{
				return nil
			}
			
			//	pop frame
			let PopMetaJsonBufferCount = Int32(PopMetaJsonBuffer.count)
			var PoppedPlane0Buffer = try PopMetaJsonBuffer.withUnsafeMutableBytes 
			{
				(PopMetaJsonBuffer8:UnsafeMutablePointer<CChar>) in
				//	init with terminator
				PopMetaJsonBuffer8[0] = 0
				
				let Plane0Size : Int32 = Int32(Meta.Planes?.first?.DataSize ?? 0 )
				var Plane0Buffer = Data(count: Int(Plane0Size))
				var PoppedFrameNumber = Plane0Buffer.withUnsafeMutableBytes 
				{
					(Plane0Buffer8:UnsafeMutablePointer<UInt8>) in
					var PoppedFrameNumber = PopCameraDevice_PopNextFrame( instance, PopMetaJsonBuffer8, PopMetaJsonBufferCount, Plane0Buffer8, Plane0Size, nil, 0, nil, 0)
					let PoppedMeta = String(cString: PopMetaJsonBuffer8)
					return PoppedFrameNumber
				}

				PoppedFrameNumber = PoppedFrameNumber & 0x7fffffff
				if ( PoppedFrameNumber != PeekFrameNumber )
				{
					throw PopError("Popped different frame to peek")
				}
				
				return Plane0Buffer
			}

			let Plane0Data = PoppedPlane0Buffer
			var frame = Frame(Meta: Meta, PixelData: Plane0Data, FrameNumber:PeekFrameNumber )
			
			return frame
		}
		catch let error as Error
		{
			let OutputError = "Error getting next frame state; \(error.localizedDescription)"
			throw PopError( OutputError )
		}
	}

}


