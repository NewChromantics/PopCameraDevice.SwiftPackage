import SwiftUI
import PopCameraDeviceObjc
import CoreMediaIO

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
	var Version = PopCameraDeviceObjc_GetVersion()
	return Version
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
	//	get json and decode to structs
	let json = PopCameraDeviceObjc_EnumCameraDevicesJson()
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
	var instanceWrapper : PopCameraDeviceInstanceWrapper	//	objc object
	var allocationError : String?

	public init(serial:String,options:[AnyHashable:Any])
	{
		do
		{
			instanceWrapper = PopCameraDeviceInstanceWrapper()
			/*
			let options : [AnyHashable:Any] = [
				//"Format":"Yuv_8_88"
				"Format":"RGB"
			]
			 */
			try instanceWrapper.allocate(withSerial: serial, options: options)
			var Version = GetVersion()
			print("Allocated instance \(instanceWrapper); PopCameraDevice version \(Version)")
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
		instanceWrapper.free()
	}
	
	public func PopNextFrame() throws -> Frame?
	{
		if let allocationError
		{
			throw PopError( allocationError )
		}
		
		do
		{
			var NextFrameMeta = try instanceWrapper.peekNextFrameJson()
			
			//	null json = no frame pending
			guard let NextFrameMeta else
			{
				return nil
			}
			
			let NextFrameMetaJsonData = NextFrameMeta.metaJson.data(using: .utf8)!
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
			var PoppedFrame = try instanceWrapper.popNextFrame(Plane0Size,expectedFrameNumber:NextFrameMeta.frameNumber)
			
			guard let PoppedFrame else
			{
				throw PopError("Wrongly got null frame back from popNextFrame when it should have thrown")
			}
			var frame = Frame(Meta: Meta, PixelData: PoppedFrame.plane0, FrameNumber:PoppedFrame.frameNumber)
			
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


