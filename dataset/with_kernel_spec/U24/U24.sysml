package 'MineCam System' {
	private import ScalarValues::*;
	private import ISQ::*;

	item def Scene;
	item def Data;
	item def RawImage;
	item def ProcessedImage :> Data;
	item def VideoFile :> Data;
	item def Command;
	item def Status;
	item def Electricity;

	attribute def StartSignal;
	attribute def SelfDiagnosticComplete;
	attribute def CapturePhotoCommand;
	attribute def RecordVideoCommand;
	attribute def StopRecordingCommand;
	attribute def ShutdownCommand;
	attribute def FaultSignal;
	attribute def ResetSignal;
	attribute def PhotoComplete;
	attribute def VideoComplete;

	port def EthernetPort {
		in item command : Command;
		out item data : Data;
		out item status : Status;
	}
	port def PowerPort {
		in item electricity : Electricity;
	}
	port def OpticalInPort {
		in item scene : Scene;
	}
	port def RawImageOutPort {
		out item image : RawImage;
	}
	port def RawImageInPort {
		in item image : RawImage;
	}
	port def ProcessedOutPort {
		out item data : ProcessedImage;
	}
	port def VideoOutPort {
		out item video : VideoFile;
	}
	port def DataInPort {
		in item data : Data;
	}
	port def PowerOutPort {
		out item electricity : Electricity;
	}

	action def RunSelfDiagnostic {
		out item result : Status;
	}
	action def ActivateLights;
	action def FocusLens;
	action def CaptureImage {
		out item raw : RawImage;
	}
	action def ProcessImage {
		in item raw : RawImage;
		out item processed : ProcessedImage;
	}
	action def CompressVideo {
		in item inputImage : ProcessedImage;
		out item outputVideo : VideoFile;
	}
	action def SaveData {
		in item data : Data;
	}
	action def TransmitData {
		in item data : Data;
		out item status : Status;
	}
	action def DistributePower;

	action def CapturePhotoSequence {
		action activateLights : ActivateLights;
		then action focusLens : FocusLens;
		then action captureImage : CaptureImage {
			out item raw;
		}
		then action processImage : ProcessImage {
			in item raw = captureImage.raw;
			out item processed;
		}
		then action saveData : SaveData {
			in item data = processImage.processed;
		}
		then action transmitData : TransmitData {
			in item data = processImage.processed;
			out item status;
		}
	}

	action def RecordVideoSequence {
		action activateLights : ActivateLights;
		then action focusLens : FocusLens;
		then action captureImage : CaptureImage {
			out item raw;
		}
		then action processImage : ProcessImage {
			in item raw = captureImage.raw;
			out item processed;
		}
		then action compressVideo : CompressVideo {
			in item inputImage = processImage.processed;
			out item outputVideo;
		}
		then action saveData : SaveData {
			in item data = compressVideo.outputVideo;
		}
		then action transmitData : TransmitData {
			in item data = compressVideo.outputVideo;
			out item status;
		}
	}

	state def MineCamStates;

	part def ProtectiveEnclosure {
		attribute ipRating : String = "IP68";
		attribute temperatureRange : String = "-20C to +60C";
		attribute vibrationResistance : String = "High";
	}

	part def ImageSensor {
		in port powerIn : PowerPort;
		out port imageOut : RawImageOutPort;
		perform action captureImage : CaptureImage;
	}

	part def OpticalSystem {
		in port powerIn : PowerPort;
		in port opticalIn : OpticalInPort;
		perform action focusLens : FocusLens;
	}

	part def IlluminationModule {
		in port powerIn : PowerPort;
		perform action activateLights : ActivateLights;
	}

	part def ImageProcessingUnit {
		in port powerIn : PowerPort;
		in port imageIn : RawImageInPort;
		out port processedOut : ProcessedOutPort;
		out port videoOut : VideoOutPort;
		perform action processImage : ProcessImage;
		perform action compressVideo : CompressVideo;
	}

	part def StorageUnit {
		in port powerIn : PowerPort;
		in port dataIn : DataInPort;
		perform action saveData : SaveData;
	}

	part def EthernetInterface {
		in port powerIn : PowerPort;
		in port dataIn : DataInPort;
		out port ethOut : EthernetPort;
		perform action transmitData : TransmitData;
	}

	part def PowerSupply {
		in port powerIn : PowerPort;
		out port powerOut : PowerOutPort;
		perform action distributePower : DistributePower;
	}

	part def SurfaceMonitoringStation {
		port ethPort : EthernetPort;
	}

	part def MineCam {
		port ethPort : EthernetPort;
		port powerIn : PowerPort;
		port opticalIn : OpticalInPort;
		exhibit state mineCamStates : MineCamStates;
		perform action capturePhoto : CapturePhotoSequence;
		perform action recordVideo : RecordVideoSequence;
		perform action selfDiagnostic : RunSelfDiagnostic;
	}

	part mineCam : MineCam {
		part enclosure : ProtectiveEnclosure;
		part sensor : ImageSensor;
		part optics : OpticalSystem;
		part lights : IlluminationModule;
		part processor : ImageProcessingUnit;
		part storage : StorageUnit;
		part ethernet : EthernetInterface;
		part power : PowerSupply;

		connection extPower from powerIn to power.powerIn;
		connection powerToSensor from power.powerOut to sensor.powerIn;
		connection powerToOptics from power.powerOut to optics.powerIn;
		connection powerToLights from power.powerOut to lights.powerIn;
		connection powerToProcessor from power.powerOut to processor.powerIn;
		connection powerToStorage from power.powerOut to storage.powerIn;
		connection powerToEthernet from power.powerOut to ethernet.powerIn;

		connection sceneToOptics from opticalIn to optics.opticalIn;
		connection sensorToProcessor from sensor.imageOut to processor.imageIn;
		connection processorToStorage from processor.processedOut to storage.dataIn;
		connection processorToEthernet from processor.processedOut to ethernet.dataIn;
		connection videoToStorage from processor.videoOut to storage.dataIn;
		connection videoToEthernet from processor.videoOut to ethernet.dataIn;
		connection ethernetToPort from ethernet.ethOut to ethPort;

		state mineCamStates : MineCamStates {
			entry; then off;
			state off;
			accept StartSignal then starting;
			state starting {
				entry action runDiagnostic : RunSelfDiagnostic;
			}
			accept SelfDiagnosticComplete then standby;
			state standby;
			accept CapturePhotoCommand then capturingPhoto;
			accept RecordVideoCommand then recordingVideo;
			accept ShutdownCommand then off;
			accept FaultSignal then fault;
			state capturingPhoto {
				entry action capturePhotoSeq : CapturePhotoSequence;
			}
			accept PhotoComplete then standby;
			state recordingVideo {
				entry action recordVideoSeq : RecordVideoSequence;
			}
			accept StopRecordingCommand then standby;
			accept VideoComplete then standby;
			state fault;
			accept ResetSignal then standby;
		}
	}

	part surfaceStation : SurfaceMonitoringStation;
	connection ethConn from mineCam.ethPort to surfaceStation.ethPort;

	requirement def R_IP68_Enclosure {
		doc /* The MineCam enclosure shall be rated IP68 for dust and water resistance. */
	}
	requirement def R_Ruggedized {
		doc /* The system shall withstand significant vibration and temperature fluctuations typical of underground mining. */
		attribute maxTemp : TemperatureValue;
		attribute minTemp : TemperatureValue;
		attribute maxVibration : Real;
	}
	requirement def R_CaptureCapability {
		doc /* The system shall capture high-quality still images and video sequences for safety inspections and geological assessment. */
	}
	requirement def R_IntegratedIllumination {
		doc /* The system shall provide integrated high-intensity illumination for operation in complete darkness. */
	}
	requirement def R_ImageProcessing {
		doc /* The onboard processor shall enhance image brightness and contrast, and compress image sequences into standard video files. */
	}
	requirement def R_DataManagement {
		doc /* Processed data shall be stored locally on an internal storage unit and simultaneously transmitted to a surface monitoring station via high-bandwidth Ethernet. */
	}
	requirement def R_RemoteControl {
		doc /* The MineCam shall support remote control for startup, self-diagnostics, photo capture, and video recording, returning to standby after each operation. */
	}

	satisfy R_IP68_Enclosure by mineCam.enclosure;
	satisfy R_Ruggedized by mineCam.enclosure;
	satisfy R_CaptureCapability by mineCam.sensor, mineCam.optics;
	satisfy R_IntegratedIllumination by mineCam.lights;
	satisfy R_ImageProcessing by mineCam.processor;
	satisfy R_DataManagement by mineCam.storage, mineCam.ethernet;
	satisfy R_RemoteControl by mineCam;
}
