package 'PushBroomScannerSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def ScanRate :> ISQ::FrequencyValue;
	attribute def GroundSampleDistance :> ISQ::LengthValue;
	attribute def SwathWidth :> ISQ::LengthValue;
	attribute def SpectralBandwidth :> ISQ::LengthValue;
	attribute def IntegrationTime :> ISQ::TimeValue;
	attribute def PixelCount :> Integer;
	attribute def RadianceLevel :> ISQ::PowerValue;
	
	item def ImageLine {
		attribute pixelValues : Real[*] ordered;
		attribute timestamp : ISQ::TimeValue;
		attribute lineNumber : Integer;
	}
	
	item def ImageSwath {
		attribute imageLines : ImageLine[*] ordered;
		attribute totalLines : Integer;
	}
	
	item def CalibrationData {
		attribute darkCurrent : Real[*];
		attribute gainCoefficients : Real[*];
		attribute offsetValues : Real[*];
	}
	
	item def ScanCommand {
		attribute startScan : Boolean;
		attribute stopScan : Boolean;
		attribute scanRate : ScanRate;
	}
	
	port def OpticalInputPort {
		in incomingRadiance : RadianceLevel;
	}
	
	port def ImageDataPort {
		out imageData : ImageSwath;
	}
	
	port def CommandPort {
		in commands : ScanCommand;
	}
	
	port def PowerPort {
		in voltage : ISQ::ElectricPotentialValue;
		in current : ISQ::ElectricCurrentValue;
	}
	
	part def OpticalAssembly {
		attribute focalLength : ISQ::LengthValue;
		attribute apertureDiameter : ISQ::LengthValue;
		attribute fieldOfView : Real;
		
		port opticalIn : OpticalInputPort;
		port focusedOutput;
	}
	
	part def LinearDetectorArray {
		attribute pixelCount : PixelCount;
		attribute pixelPitch : ISQ::LengthValue;
		attribute spectralResponse : SpectralBandwidth;
		attribute integrationTime : IntegrationTime;
		
		port focusedInput;
		port rawSignalOutput;
	}
	
	part def SignalProcessingUnit {
		attribute processingRate : ISQ::FrequencyValue;
		attribute bitDepth : Integer;
		
		port rawSignalInput;
		port calibrationInput;
		port processedDataOutput;
	}
	
	part def DataStorageUnit {
		attribute storageCapacity : Real;
		attribute writeSpeed : Real;
		
		port dataInput;
		port dataOutput : ImageDataPort;
	}
	
	part def CalibrationUnit {
		attribute calibrationInterval : ISQ::TimeValue;
		
		port calibrationOutput;
	}
	
	part def PlatformInterface {
		attribute platformVelocity : ISQ::SpeedValue;
		attribute platformAltitude : ISQ::LengthValue;
		
		port motionData;
	}
	
	action def CapturePhotons {
		in incomingLight : RadianceLevel;
		in integrationPeriod : IntegrationTime;
		out rawPixelData : Real[*];
	}
	
	action def ApplyCalibration {
		in rawData : Real[*];
		in calibration : CalibrationData;
		out calibratedData : Real[*];
	}
	
	action def FormImageLine {
		in calibratedPixels : Real[*];
		in lineIndex : Integer;
		in captureTime : ISQ::TimeValue;
		out imageLine : ImageLine;
	}
	
	action def AccumulateSwath {
		in imageLine : ImageLine;
		inout swathBuffer : ImageSwath;
	}
	
	action def PerformCalibration {
		out calibrationData : CalibrationData;
	}
	
	action def ContinuousPushBroomScanning {
		in scanCommand : ScanCommand;
		in platformVelocity : ISQ::SpeedValue;
		in incomingRadiance : RadianceLevel;
		out imageSwath : ImageSwath;
		
		private attribute currentCalibration : CalibrationData;
		private attribute lineCounter : Integer := 0;
		
		first start;
		then accept cmd : ScanCommand;
		
		then decide;
			if cmd.startScan then initializeScanning;
			else done;
		
		action initializeScanning {
			action calibrate : PerformCalibration {
				out calibrationData : CalibrationData;
			}
			then assign currentCalibration := calibrate.calibrationData;
		}
		
		then merge scanningLoop;
		
		action scanningLoop {
			action captureAndProcess {
				action capture : CapturePhotons {
					in incomingLight = incomingRadiance;
					in integrationPeriod = 0.001 [s];
					out rawPixelData : Real[*];
				}
				
				flow capture.rawPixelData to calibrateData.rawData;
				
				then action calibrateData : ApplyCalibration {
					in rawData : Real[*];
					in calibration = currentCalibration;
					out calibratedData : Real[*];
				}
				
				flow calibrateData.calibratedData to formLine.calibratedPixels;
				
				then action formLine : FormImageLine {
					in calibratedPixels : Real[*];
					in lineIndex = lineCounter;
					in captureTime = 0.001 [s];
					out imageLine : ImageLine;
				}
			}
			
			flow captureAndProcess.formLine.imageLine to accumulate.imageLine;
			
			then action accumulate : AccumulateSwath {
				in imageLine : ImageLine;
				inout swathBuffer = imageSwath;
			}
			
			then assign lineCounter := lineCounter + 1;
			then scanningLoop;
		}
	}
	
	state def ScannerOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign statusMessage := "Scanner Ready";
		}
		
		state calibrating {
			entry assign statusMessage := "Performing Calibration";
		}
		
		state scanning {
			entry assign statusMessage := "Active Scanning";
		}
		
		state storing {
			entry assign statusMessage := "Storing Image Data";
		}
		
		state fault {
			entry assign statusMessage := "Fault Detected";
		}
		
		transition powerOn
			first idle
			accept powerCommand : Boolean;
		
		transition startCalibration
			from idle to calibrating
			accept calibrationTrigger : Boolean;
		
		transition beginScanning
			from calibrating to scanning
			accept scanStart : Boolean;
		
		transition storeData
			from scanning to storing
			accept storeTrigger : Boolean;
		
		transition resumeScanning
			from storing to scanning
			accept continueScan : Boolean;
		
		transition stopScanning
			from scanning to idle
			accept scanStop : Boolean;
		
		transition errorDetected
			from scanning to fault
			accept errorSignal : Boolean;
		
		transition recover
			from fault to idle
			accept resetCommand : Boolean;
		
		private attribute statusMessage : String;
	}
	
	part def PushBroomScanner {
		doc /* 
		A push broom scanner is a remote sensing instrument that acquires imagery 
		by using the forward motion of its platform to sweep a linear detector array 
		across the target area, building up a two-dimensional image one line at a time.
		*/
		
		attribute groundSampleDistance : GroundSampleDistance;
		attribute swathWidth : SwathWidth;
		attribute scanRate : ScanRate;
		
		port opticalAperture : OpticalInputPort;
		port imageOutput : ImageDataPort;
		port commandInput : CommandPort;
		port powerInput : PowerPort;
		
		part optics : OpticalAssembly {
			attribute focalLength = 500.0 [mm];
			attribute apertureDiameter = 150.0 [mm];
			attribute fieldOfView = 12.0;
		}
		
		part detector : LinearDetectorArray {
			attribute pixelCount = 10000;
			attribute pixelPitch = 0.010 [mm];
			attribute spectralResponse = 0.0005 [mm];
			attribute integrationTime = 0.001 [s];
		}
		
		part processor : SignalProcessingUnit {
			attribute processingRate = 200.0 [MHz];
			attribute bitDepth = 14;
		}
		
		part storage : DataStorageUnit {
			attribute storageCapacity = 2000.0;
			attribute writeSpeed = 1000.0;
		}
		
		part calibration : CalibrationUnit {
			attribute calibrationInterval = 3600.0 [s];
		}
		
		part platformInterface : PlatformInterface {
			attribute platformVelocity = 7500.0 [m/s];
			attribute platformAltitude = 700000.0 [m];
		}
		
		connection opticsToDetector connect optics.focusedOutput to detector.focusedInput;
		connection detectorToProcessor connect detector.rawSignalOutput to processor.rawSignalInput;
		connection calibrationToProcessor connect calibration.calibrationOutput to processor.calibrationInput;
		connection processorToStorage connect processor.processedDataOutput to storage.dataInput;
		connection storageToOutput connect storage.dataOutput to imageOutput;
		
		perform action scanOperation : ContinuousPushBroomScanning {
			in scanCommand = commandInput.commands;
			in platformVelocity = platformInterface.platformVelocity;
			in incomingRadiance = opticalAperture.incomingRadiance;
			out imageSwath;
		}
		
		state operationalState : ScannerOperationalStates;
	}
	
	part pushBroomScannerSystem : PushBroomScanner {
		attribute groundSampleDistance = 10.0 [m];
		attribute swathWidth = 100000.0 [m];
		attribute scanRate = 1000.0 [Hz];
		
		perform scanOperation.scanningLoop.captureAndProcess.capture by detector;
		perform scanOperation.scanningLoop.captureAndProcess.calibrateData by processor;
		perform scanOperation.scanningLoop.captureAndProcess.formLine by processor;
		perform scanOperation.scanningLoop.accumulate by storage;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* 
		The push broom scanner shall continuously acquire high-resolution imagery 
		of the ground surface by utilizing the forward motion of the platform to 
		sweep a linear detector array across the terrain, producing contiguous 
		image swaths with specified spatial and radiometric resolution.
		*/
		
		subject pushBroomScannerSystem;
	}
	
	requirement def SpatialResolutionRequirement {
		doc /* 
		The scanner shall achieve a ground sample distance of 10 meters or better 
		at the nominal operational altitude.
		*/
		
		subject pushBroomScannerSystem;
		
		require constraint gsdConstraint {
			pushBroomScannerSystem.groundSampleDistance <= 10.0 [m]
		}
	}
	
	requirement def SwathCoverageRequirement {
		doc /* 
		The scanner shall provide a minimum swath width of 100 kilometers 
		to ensure adequate ground coverage per orbital pass.
		*/
		
		subject pushBroomScannerSystem;
		
		require constraint swathConstraint {
			pushBroomScannerSystem.swathWidth >= 100000.0 [m]
		}
	}
	
	requirement def DataAcquisitionRequirement {
		doc /* 
		The scanner shall acquire image lines at a rate sufficient to ensure 
		contiguous ground coverage given the platform velocity and required 
		ground sample distance.
		*/
		
		subject pushBroomScannerSystem;
		
		require constraint scanRateConstraint {
			pushBroomScannerSystem.scanRate >= 
				pushBroomScannerSystem.platformInterface.platformVelocity / 
				pushBroomScannerSystem.groundSampleDistance
		}
	}
	
	requirement <'PBSCAN-001'> primaryMissionRequirement : PrimaryFunctionRequirement {
		assume constraint platformStability {
			doc /* 
			The platform maintains stable attitude and velocity during 
			scanning operations with minimal vibration and pointing errors.
			*/
		}
		
		require SpatialResolutionRequirement;
		require SwathCoverageRequirement;
		require DataAcquisitionRequirement;
	}
	
	satisfy primaryMissionRequirement by pushBroomScannerSystem;
}
