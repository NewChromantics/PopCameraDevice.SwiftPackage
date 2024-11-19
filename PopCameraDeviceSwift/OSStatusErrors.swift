import VideoToolbox



public func GetOSError(_ status:OSStatus) -> String
{
	let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo:nil)
	return error.localizedDescription
}

public func GetVideoToolboxError(_ status:OSStatus) -> String
{
	switch status
	{
		case kVTAllocationFailedErr:	return "kVTAllocationFailedErr"
		case kVTColorCorrectionImageRotationFailedErr:	return "kVTColorCorrectionImageRotationFailedErr"
		case kVTColorCorrectionPixelTransferFailedErr:	return "kVTColorCorrectionPixelTransferFailedErr"
		case kVTColorSyncTransformConvertFailedErr:	return "kVTColorSyncTransformConvertFailedErr"
		case kVTCouldNotCreateColorCorrectionDataErr:	return "kVTCouldNotCreateColorCorrectionDataErr"
		case kVTCouldNotCreateInstanceErr:	return "kVTCouldNotCreateInstanceErr"
		case kVTCouldNotFindTemporalFilterErr:	return "kVTCouldNotFindTemporalFilterErr"
		case kVTCouldNotFindVideoDecoderErr:	return "kVTCouldNotFindVideoDecoderErr"
		case kVTCouldNotFindVideoEncoderErr:	return "kVTCouldNotFindVideoEncoderErr"
		case kVTCouldNotOutputTaggedBufferGroupErr:	return "kVTCouldNotOutputTaggedBufferGroupErr"
		case kVTFormatDescriptionChangeNotSupportedErr:	return "kVTFormatDescriptionChangeNotSupportedErr"
		case kVTFrameSiloInvalidTimeRangeErr:	return "kVTFrameSiloInvalidTimeRangeErr"
		case kVTFrameSiloInvalidTimeStampErr:	return "kVTFrameSiloInvalidTimeStampErr"
		case kVTImageRotationNotSupportedErr:	return "kVTImageRotationNotSupportedErr"
		case kVTInsufficientSourceColorDataErr:	return "kVTInsufficientSourceColorDataErr"
		case kVTInvalidSessionErr:	return "kVTInvalidSessionErr"
		case kVTMultiPassStorageIdentifierMismatchErr:	return "kVTMultiPassStorageIdentifierMismatchErr"
		case kVTMultiPassStorageInvalidErr:	return "kVTMultiPassStorageInvalidErr"
		case kVTParameterErr:	return "kVTParameterErr"
		case kVTPixelRotationNotSupportedErr:	return "kVTPixelRotationNotSupportedErr"
		case kVTPixelTransferNotPermittedErr:	return "kVTPixelTransferNotPermittedErr"
		case kVTPixelTransferNotSupportedErr:	return "kVTPixelTransferNotSupportedErr"
		case kVTPropertyNotSupportedErr:	return "kVTPropertyNotSupportedErr"
		case kVTPropertyReadOnlyErr:	return "kVTPropertyReadOnlyErr"
		case kVTSessionMalfunctionErr:	return "kVTSessionMalfunctionErr"
		case kVTVideoDecoderAuthorizationErr:	return "kVTVideoDecoderAuthorizationErr"
		case kVTVideoDecoderBadDataErr:	return "kVTVideoDecoderBadDataErr"
		case kVTVideoDecoderCallbackMessagingErr:	return "xxxx"
		case kVTVideoDecoderMalfunctionErr:	return "xxxx"
		case kVTVideoDecoderNeedsRosettaErr:	return "xxxx"
		case kVTVideoDecoderNotAvailableNowErr:	return "xxxx"
		case kVTVideoDecoderReferenceMissingErr:	return "xxxx"
		case kVTVideoDecoderRemovedErr:	return "xxxx"
		case kVTVideoDecoderUnknownErr:	return "xxxx"
		case kVTVideoDecoderUnsupportedDataFormatErr:	return "xxxx"
		case kVTVideoEncoderAuthorizationErr:	return "xxxx"
		case kVTVideoEncoderMVHEVCVideoLayerIDsMismatchErr:	return "xxxx"
		case kVTVideoEncoderMalfunctionErr:	return "xxxx"
		case kVTVideoEncoderNeedsRosettaErr:	return "xxxx"
		case kVTVideoEncoderNotAvailableNowErr:	return "xxxx"
		case kVTCouldNotFindExtensionErr:	return "xxxx"
		case kVTExtensionConflictErr:	return "xxxx"
		case kVTExtensionDisabledErr:	return "xxxx"
		default: return GetOSError(status)
	}
}

