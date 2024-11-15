import PopCameraDevice
//import Cocoa
import Foundation

/*
	currently a global manager/instance for tracking enumerated devices
*/
//	gr: this cannot be observed as a global, so add it in your app as a global then observe via environmental object
//@EnvironmentObject public var popCameraDeviceManager = PopCameraDeviceManager()


//	dont override this, or the observable object breaks
public final class PopCameraDeviceManager : NSObject, ObservableObject
{
	var enumDevicesThread : Task<Void,any Error>!

	@Published public var devices : [PopCameraDevice.EnumDeviceMeta] = []
	
	public var serialPrefixFilter : String
	
	public init(serialPrefixFilter:String="")
	{
		self.serialPrefixFilter = serialPrefixFilter
		super.init()
		self.enumDevicesThread = Task
		{
			try await self.WatchForNewDevicesThread()
		}
	}
	
	deinit
	{
		enumDevicesThread.cancel()
	}
	
	func WatchForNewDevicesThread() async throws
	{
		while ( true )
		{
			do
			{
				let Devices = try PopCameraDevice.EnumDevices(requireSerialPrefix: serialPrefixFilter)
				OnFoundDevices( Devices )
			}
			catch let error
			{
				print("Error enumerating devices; \(error.localizedDescription)")
			}

			//	will throw if task cancelled
			try await Task.sleep(for: .seconds(10))
		}
	}
	
	func OnFoundDevices(_ deviceMetas:[PopCameraDevice.EnumDeviceMeta])
	{
		//	gotta change observables on main thread
		DispatchQueue.main.async
		{
			self.devices = deviceMetas
		}
	}
}
