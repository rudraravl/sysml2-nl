package 'Synthetic Aperture Radar System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def RadarMode;
	attribute def StripMapMode :> RadarMode;
	attribute def SpotlightMode :> RadarMode;
	attribute def ScanSARMode :> RadarMode;
	
	attribute def PulseParameters {
		attribute pulseWidth : ISQ::TimeValue;
		attribute pulseRepetitionFrequency : ISQ::FrequencyValue;
		attribute carrierFrequency : ISQ::FrequencyValue;
		attribute bandwidth : ISQ::FrequencyValue;
		attribute chirpRate : Real;
	}
	
	attribute def TargetArea {
		attribute centerLatitude : Real;
		attribute centerLongitude : Real;
		attribute swathWidth : ISQ::LengthValue;
		attribute azimuthExtent : ISQ::LengthValue;
	}
	
	attribute def Complex {
		attribute real : Real;
		attribute imaginary : Real;
	}
	
	attribute def RawRadarData {
		attribute echoSignals : Complex;
		attribute timestamp : ISQ::TimeValue;
		attribute platformPosition : ISQ::LengthValue;
		attribute platformVelocity : ISQ::SpeedValue;
		attribute platformAttitude : Real;
	}
	
	attribute def ProcessedImageData {
		attribute imagePixels : Real;
		attribute rangeResolution : ISQ::LengthValue;
		attribute azimuthResolution : ISQ::LengthValue;
		attribute geolocation : Real;
		attribute signalToNoiseRatio : Real;
	}
	
	item def RFSignal {
		attribute frequency : ISQ::FrequencyValue;
		attribute power : ISQ::PowerValue;
		attribute phase : Real;
	}
	
	item def EchoData {
		attribute samples : Complex;
		attribute acquisitionTime : ISQ::TimeValue;
		attribute doppler : ISQ::FrequencyValue;
	}
	
	port def RFPort {
		out transmit : RFSignal;
		in receive : RFSignal;
	}
	
	port def DataPort {
		in rawDataIn : RawRadarData;
		out processedDataOut : ProcessedImageData;
	}
	
	port def PowerPort {
		in power : ISQ::PowerValue;
	}
	
	port def NavigationPort {
		out position : ISQ::LengthValue;
		out velocity : ISQ::SpeedValue;
		out attitude : Real;
	}
	
	action def TransmitPulse {
		in pulseParams : PulseParameters;
		in targetArea : TargetArea;
		out transmittedSignal : RFSignal;
	}
	
	action def ReceiveEchoes {
		in targetArea : TargetArea;
		in receivedSignal : RFSignal;
		out echoData : EchoData;
	}
	
	action def RecordPlatformMotion {
		out position : ISQ::LengthValue;
		out velocity : ISQ::SpeedValue;
		out attitude : Real;
	}
	
	action def PerformRangeCompression {
		in rawData : RawRadarData;
		in pulseParams : PulseParameters;
		out rangeCompressedData : Complex;
	}
	
	action def PerformAzimuthCompression {
		in rangeCompressedData : Complex;
		in platformMotion : ISQ::SpeedValue;
		out azimuthCompressedData : Complex;
	}
	
	action def ApplyMotionCompensation {
		in imageData : Complex;
		in platformPosition : ISQ::LengthValue;
		in platformAttitude : Real;
		out compensatedData : Complex;
	}
	
	action def GenerateImage {
		in compressedData : Complex;
		out image : ProcessedImageData;
	}
	
	action def CalibrateImage {
		in rawImage : ProcessedImageData;
		out calibratedImage : ProcessedImageData;
	}
	
	action def SARImagingCycle {
		in mode : RadarMode;
		in targetArea : TargetArea;
		in pulseParams : PulseParameters;
		in apertureSamples : Natural;
		out finalImage : ProcessedImageData;
		
		first start;
		
		then action collectAperture {
			in apertureSamples : Natural;
			in pulseParams : PulseParameters;
			in targetArea : TargetArea;
			out rawDataCollection : RawRadarData;
			
			action transmit : TransmitPulse {
				in pulseParams = collectAperture::pulseParams;
				in targetArea = collectAperture::targetArea;
				out transmittedSignal;
			}
			
			flow transmit.transmittedSignal to receive.receivedSignal;
			
			action receive : ReceiveEchoes {
				in targetArea = collectAperture::targetArea;
				in receivedSignal;
				out echoData;
			}
			
			flow receive.echoData to recordMotion;
			
			action recordMotion : RecordPlatformMotion {
				out position;
				out velocity;
				out attitude;
			}
			
			bind rawDataCollection = RawRadarData {
				echoSignals = receive.echoData.samples;
				timestamp = receive.echoData.acquisitionTime;
				platformPosition = recordMotion.position;
				platformVelocity = recordMotion.velocity;
				platformAttitude = recordMotion.attitude;
			};
		}
		
		flow collectAperture.rawDataCollection to processData.rawDataCollection;
		
		action processData {
			in rawDataCollection : RawRadarData;
			in pulseParams : PulseParameters;
			out processedImage : ProcessedImageData;
			
			action rangeCompress : PerformRangeCompression {
				in rawData = processData::rawDataCollection;
				in pulseParams = processData::pulseParams;
				out rangeCompressedData;
			}
			
			flow rangeCompress.rangeCompressedData to azimuthCompress.rangeCompressedData;
			
			action azimuthCompress : PerformAzimuthCompression {
				in rangeCompressedData;
				in platformMotion = processData::rawDataCollection.platformVelocity;
				out azimuthCompressedData;
			}
			
			flow azimuthCompress.azimuthCompressedData to motionCompensate.imageData;
			
			action motionCompensate : ApplyMotionCompensation {
				in imageData;
				in platformPosition = processData::rawDataCollection.platformPosition;
				in platformAttitude = processData::rawDataCollection.platformAttitude;
				out compensatedData;
			}
			
			flow motionCompensate.compensatedData to formImage.compressedData;
			
			action formImage : GenerateImage {
				in compressedData;
				out image;
			}
			
			flow formImage.image to calibrate.rawImage;
			
			action calibrate : CalibrateImage {
				in rawImage;
				out calibratedImage;
			}
			
			bind processedImage = calibrate.calibratedImage;
		}
		
		bind finalImage = processData.processedImage;
		
		then done;
	}
	
	part def Antenna {
		port rf : RFPort;
		port power : PowerPort;
		attribute antennaLength : ISQ::LengthValue;
		attribute beamWidth : Real;
		attribute gain : Real;
		attribute efficiency : Real;
	}
	
	part def TransmitReceiveModule {
		port radarPort : RFPort;
		port power : PowerPort;
		attribute operatingFrequency : ISQ::FrequencyValue;
		attribute transmitPower : ISQ::PowerValue;
		attribute receiverSensitivity : ISQ::PowerValue;
		attribute noiseFigure : Real;
		
		perform action transmit : TransmitPulse;
		perform action receive : ReceiveEchoes;
	}
	
	part def SignalProcessor {
		port dataInput : DataPort;
		port dataOutput : DataPort;
		port power : PowerPort;
		attribute processingCapacity : Real;
		attribute memorySize : Real;
		
		perform action rangeProcess : PerformRangeCompression;
		perform action azimuthProcess : PerformAzimuthCompression;
	}
	
	part def ImageFormationProcessor {
		port rawDataPort : DataPort;
		port imageOutputPort : DataPort;
		port power : PowerPort;
		attribute algorithmType : String;
		
		perform action motionCompensate : ApplyMotionCompensation;
		perform action formImage : GenerateImage;
		perform action calibrate : CalibrateImage;
	}
	
	part def PlatformNavigationSystem {
		port navigationPort : NavigationPort;
		port power : PowerPort;
		attribute positionAccuracy : ISQ::LengthValue;
		attribute velocityAccuracy : ISQ::SpeedValue;
		attribute attitudeAccuracy : Real;
		
		perform action recordMotion : RecordPlatformMotion;
	}
	
	part def DataStorage {
		port storagePort : DataPort;
		port power : PowerPort;
		attribute capacity : Real;
		attribute writeSpeed : Real;
		attribute readSpeed : Real;
	}
	
	part def PowerSupply {
		port powerOut : PowerPort;
		attribute busVoltage : ISQ::ElectricPotentialValue;
		attribute capacity : ISQ::EnergyValue;
		attribute maxPower : ISQ::PowerValue;
	}
	
	part def TimingUnit {
		port power : PowerPort;
		attribute clockStability : Real;
		attribute referenceFrequency : ISQ::FrequencyValue;
	}
	
	part def SyntheticApertureRadarSystem {
		doc /* A complete SAR system that collects coherent radar echoes over a synthetic aperture,
		       processes them into high-resolution imagery, and delivers the imagery to users. */
		
		part antenna : Antenna {
			attribute antennaLength = 3.0 [SI::m];
			attribute beamWidth = 0.05;
			attribute gain = 35.0;
			attribute efficiency = 0.7;
		}
		
		part transmitReceive : TransmitReceiveModule {
			attribute operatingFrequency = 9.6 [SI::GHz];
			attribute transmitPower = 1000.0 [SI::W];
			attribute receiverSensitivity = 1.0e-13 [SI::W];
			attribute noiseFigure = 3.0;
		}
		
		part signalProcessor : SignalProcessor {
			attribute processingCapacity = 1.0e9;
			attribute memorySize = 1.0e10;
		}
		
		part imageProcessor : ImageFormationProcessor {
			attribute algorithmType = "Range-Doppler Algorithm";
		}
		
		part navigation : PlatformNavigationSystem {
			attribute positionAccuracy = 0.1 [SI::m];
			attribute velocityAccuracy = 0.01 [SI::'m/s'];
			attribute attitudeAccuracy = 0.001;
		}
		
		part storage : DataStorage {
			attribute capacity = 1.0e12;
			attribute writeSpeed = 1.0e9;
			attribute readSpeed = 1.0e9;
		}
		
		part power : PowerSupply {
			attribute busVoltage = 28.0 [SI::V];
			attribute capacity = 5000.0 [SI::Wh];
			attribute maxPower = 2000.0 [SI::W];
		}
		
		part timing : TimingUnit {
			attribute clockStability = 1.0e-9;
			attribute referenceFrequency = 10.0 [SI::MHz];
		}
		
		connect transmitReceive.radarPort to antenna.rf;
		connect signalProcessor.dataInput to storage.storagePort;
		connect signalProcessor.dataOutput to imageProcessor.rawDataPort;
		
		connect power.powerOut to antenna.power;
		connect power.powerOut to transmitReceive.power;
		connect power.powerOut to signalProcessor.power;
		connect power.powerOut to imageProcessor.power;
		connect power.powerOut to navigation.power;
		connect power.powerOut to storage.power;
		connect power.powerOut to timing.power;
		
		perform action imagingOperation : SARImagingCycle;
	}
	
	part syntheticApertureRadar : SyntheticApertureRadarSystem;
	
	requirement def ImageQualityRequirement {
		doc /* The SAR system shall produce images with specified resolution and quality metrics. */
		
		require constraint resolutionRequirement {
			doc /* Spatial resolution shall be better than 1 meter in both range and azimuth. */
		}
		
		require constraint signalToNoiseRequirement {
			doc /* Image signal-to-noise ratio shall exceed 20 dB. */
		}
		
		require constraint geolocationAccuracy {
			doc /* Geolocation accuracy shall be better than 5 meters. */
		}
	}
	
	requirement def OperationalRequirement {
		doc /* The SAR system shall operate in multiple imaging modes across specified conditions. */
		
		require constraint modeRequirement {
			doc /* System shall support StripMap, Spotlight, and ScanSAR modes. */
		}
		
		require constraint swathRequirement {
			doc /* Swath width shall be configurable from 5 km to 100 km. */
		}
		
		require constraint weatherRequirement {
			doc /* System shall operate day and night in all weather conditions. */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The SAR system shall meet specified performance metrics. */
		
		require constraint dataRateRequirement {
			doc /* System shall process and store radar data at rates up to 1 Gbps. */
		}
		
		require constraint imagingTimeRequirement {
			doc /* Time from data collection to image formation shall be less than 60 seconds. */
		}
		
		require constraint powerRequirement {
			doc /* Total system power consumption shall not exceed 2000 W. */
		}
	}
	
	requirement sarSystemRequirements {
		doc /* Top-level requirements for the Synthetic Aperture Radar system.
		       The primary function is to collect coherent radar echoes from a moving platform
		       over a synthetic aperture, process them using advanced signal processing algorithms
		       to form high-resolution two-dimensional images of the terrain, and deliver
		       calibrated imagery products to users for analysis and interpretation. */
		
		subject syntheticApertureRadar;
		
		require imageQuality : ImageQualityRequirement;
		require operational : OperationalRequirement;
		require performance : PerformanceRequirement;
	}
}
