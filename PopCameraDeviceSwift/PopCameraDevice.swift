import SwiftUI
import CoreMediaIO
import PopCameraDeviceCApi


struct PopError : LocalizedError
{
	let error: String
	
	init(_ description: String) {
		error = description
	}
	
	var errorDescription: String? {
		error
	}
}


public func GetVersion() -> String
{
	let VersionThousand = PopCameraDeviceCApi.PopCameraDevice_GetVersionThousand()
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
	PopCameraDevice_EnumCameraDevicesJson(JsonBuffer, Int32(JsonBufferSize))
	let json = String(cString: JsonBuffer)
	JsonBuffer.deallocate()
	
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
	
	public func GetPixelFormat() throws ->CMPixelFormatType
	{
		switch Format
		{
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
}

public class PopCameraDeviceInstance
{
	var instance = Int32(PopCameraDeviceCApi.PopCameraDevice_NullInstance)
	
	//var instanceWrapper : PopCameraDeviceInstanceWrapper	//	objc object
	var allocationError : String?

	public init(serial:String,options:[String:Any])
	{
		do
		{
			let jsonData = try JSONSerialization.data(withJSONObject: options, options: JSONSerialization.WritingOptions.prettyPrinted)
			let json = NSString(data: jsonData as Data, encoding: NSUTF8StringEncoding)! as String
			
			/*
			let optionsJsonData = try? JSONEncoder().encode(options)
			{
				if let jsonString = String(data: jsonData, encoding: .utf8) {
					print(jsonString)
				}
			}
			 */
			
			//	gr: we can do ErrorBuffer as a string, and then get an unsafe pointer - but we need to generate a giant string first?
			let ErrorBufferSize = 1000
			var ErrorBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: ErrorBufferSize)
			//	init with terminator
			ErrorBuffer[0] = 0
			
			self.instance = PopCameraDeviceCApi.PopCameraDevice_CreateCameraDevice(serial, json, ErrorBuffer, Int32(ErrorBufferSize) )
			
			//	grab string & free the buffer we made
			let Error = String(cString: ErrorBuffer)
			ErrorBuffer.deallocate()
			if ( !Error.isEmpty )
			{
				throw PopError(Error)
			}
			
/*
			instanceWrapper = PopCameraDeviceInstanceWrapper()
			try instanceWrapper.allocate(withSerial: serial, options: options)
 */
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
		PopCameraDeviceCApi.PopCameraDevice_FreeCameraDevice(instance)
	}
	
	public func PopNextFrame() throws -> Frame?
	{
		if let allocationError
		{
			throw PopError( allocationError )
		}
		
		do
		{
			let JsonBufferSize = 1024 * 10
			
			let PeekMetaJsonBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: JsonBufferSize)
			//	init with terminator
			PeekMetaJsonBuffer[0] = 0
			
			let PeekFrameNumber = PopCameraDevice_PeekNextFrame( instance, PeekMetaJsonBuffer, Int32(JsonBufferSize) )
			//	grab string & free the buffer we made
			let NextFrameMetaJson = String(cString: PeekMetaJsonBuffer)
			if ( PeekFrameNumber < 0 )
			{
				return nil
			}
			
			/*
			var NextFrameMeta = try instanceWrapper.peekNextFrameJson()
			
			//	null json = no frame pending
			guard let NextFrameMeta else
			{
				return nil
			}
			*/
			let NextFrameMetaJsonData = NextFrameMetaJson.data(using: .utf8)!
			var Meta = try JSONDecoder().decode(FrameMeta.self, from: NextFrameMetaJsonData)
			
			/*
			//	convert depth plane
			if ( Meta.Planes?.first?.Format == "Depth16mm" )
			{
				let DepthPlane = Meta.Planes![0].ConvertDepth()
				Meta.Planes = [DepthPlane]
			}
			*/
			
			//	pop frame
			let Plane0Size : Int32 = Int32(Meta.Planes?.first?.DataSize ?? 0 )
			let Plane0Buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(Plane0Size))
			
			let PopMetaJsonBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: JsonBufferSize)
			//	init with terminator
			PopMetaJsonBuffer[0] = 0
			
			
			let PoppedFrameNumber = PopCameraDevice_PopNextFrame( instance, PopMetaJsonBuffer, Int32(JsonBufferSize), Plane0Buffer, Plane0Size, nil, 0, nil, 0)
			if ( PoppedFrameNumber != PeekFrameNumber )
			{
				throw PopError("Popped different frame to peek")
			}
			/*
			var PoppedFrame = try instanceWrapper.popNextFrame(Plane0Size,expectedFrameNumber:NextFrameMeta.frameNumber)
			
			guard let PoppedFrame else
			{
				throw PopError("Wrongly got null frame back from popNextFrame when it should have thrown")
			}
			*/
			//	gr: this is a copy, can we start with just Data?
			let Plane0Data = Data(bytes:Plane0Buffer,count:Int(Plane0Size))
			Plane0Buffer.deallocate()
			
			var frame = Frame(Meta: Meta, PixelData: Plane0Data, FrameNumber:PoppedFrameNumber)
			
			return frame
		}
		catch let error as Error
		{
			let OutputError = "Error getting next frame state; \(error.localizedDescription)"
			throw PopError( OutputError )
		}
	}
	/*
	//	returns frame number popped
	public func PopNextFrame() async throws -> Int
	{
		//	todo: get plane data!
		var NextFrame = try instanceWrapper.popNextFrame()
		return Int(NextFrame)
	}
*/
}


