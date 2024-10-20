// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription



let package = Package(
	name: "PopCameraDevice",
	
	platforms: [
		.iOS(.v15),
		.macOS(.v13)
	],
	

	products: [
		.library(
			name: "PopCameraDevice",
			targets: [
				"PopCameraDevice"
			]),
	],
	targets: [

		.target(
			name: "PopCameraDevice",
			/* include all targets where .h contents need to be accessible to swift */
			dependencies: ["PopCameraDeviceObjc","PopCameraDeviceFramework"],
			path: "./PopCameraDeviceSwift"
		),
		
		.binaryTarget(
					name: "PopCameraDeviceFramework",
					path: "PopCameraDevice.xcframework"
					//url: "https://github.com/NewChromantics/PopH264/releases/download/v1.3.41/PopH264.xcframework.zip",
					//checksum: "8a378470a2ab720f2ee6ecf4e7a5e202a3674660c31e43d95d672fe76d61d68c"
				),
		
		.target(
			name: "PopCameraDeviceObjc",
			dependencies: [],
			path: "./PopCameraDeviceObjc",
			//publicHeadersPath: ".",	//	not using include/ seems to have some errors resolving symbols? (this may before my extern c's)
			cxxSettings: [
				.headerSearchPath("./"),	//	this allows headers in same place as .cpp
				//.headerSearchPath("../PopCameraDevice.xcframework/ios-arm64/LibCpp.framework/Headers"),
				.headerSearchPath("../PopCameraDevice.xcframework/macos-arm64_x86_64/PopH264_Osx.framework/Versions/A/Headers/PopCameraDevice.h"),
			]
		)
		,
/*
		.testTarget(
			name: "PopH264Tests",
			dependencies: ["PopH264"]
		),
 */
	]
)
