package ContrastEnhancedUltrasoundSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def MicrobubbleContrast {
		attribute concentration : Real;
		attribute particleSize : LengthValue;
		attribute shellType : String;
	}
	
	item def UltrasoundPulse {
		attribute frequency : FrequencyValue;
		attribute acousticPower : PowerValue;
		attribute mechanicalIndex : Real;
	}
	
	item def EchoSignal {
		attribute amplitude : Real;
		attribute timeOfFlight : TimeValue;
		attribute phaseShift : Real;
	}
	
	item def EnhancedImage {
		attribute contrastRatio : Real;
		attribute spatialResolution : LengthValue;
		attribute frameNumber : Integer;
		attribute timestamp : TimeValue;
	}
	
	item def InjectionCommand {
		attribute targetDose : VolumeValue;
		attribute injectionRate : Real;
	}
	
	port def AcousticPort {
		out item transmittedPulse : UltrasoundPulse;
		in item receivedEcho : EchoSignal;
	}
	
	port def ContrastDeliveryPort {
		out item contrastBolus : MicrobubbleContrast;
	}
	
	port def ImagePort {
		out item diagnosticImage : EnhancedImage;
	}
	
	part def UltrasoundTransducer {
		port acousticInterface : AcousticPort;
		
		attribute operatingFrequency : FrequencyValue;
		attribute maxPower : PowerValue;
		
		action def TransmitPulse {
			in frequency : FrequencyValue;
			in power : PowerValue;
			out pulse : UltrasoundPulse;
		}
		
		action def ReceiveEcho {
			in echo : EchoSignal;
			out signalStrength : Real;
		}
	}
	
	part def ContrastInjector {
		port deliveryPort : ContrastDeliveryPort;
		
		attribute maxDosage : VolumeValue;
		attribute currentDosage : VolumeValue;
		
		action def DeliverContrast {
			in command : InjectionCommand;
			out contrast : MicrobubbleContrast;
		}
	}
	
	part def SignalProcessor {
		attribute gainLevel : Real;
		attribute filterBandwidth : FrequencyValue;
		
		action def ProcessEcho {
			in rawSignal : EchoSignal;
			in contrastPresent : Boolean;
			out processedSignal : Real;
		}
		
		action def IsolateMicrobubbleSignal {
			in signal : Real;
			out bubbleResponse : Real;
		}
	}
	
	part def ImageReconstructor {
		port imageOutput : ImagePort;
		
		attribute scanLines : Integer;
		attribute frameRate : FrequencyValue;
		
		action def ReconstructImage {
			in signalData : Real;
			out rawImage : EnhancedImage;
		}
		
		action def ApplyContrastEnhancement {
			in baseImage : EnhancedImage;
			in bubbleData : Real;
			out enhancedImage : EnhancedImage;
		}
	}
	
	part def VascularTissue {
		attribute bloodFlowVelocity : Real;
		attribute vesselDiameter : LengthValue;
		attribute perfusionRate : Real;
		
		action def InteractWithContrast {
			in contrast : MicrobubbleContrast;
			in ultrasound : UltrasoundPulse;
			out enhancedEcho : EchoSignal;
		}
	}
	
	part def Operator;
	
	action def PerformCEUSImaging {
		first start;
		
		then action prepareContrast {
			in dosage : VolumeValue;
			out contrastReady : MicrobubbleContrast;
		}
		
		then action injectContrast {
			in contrast : MicrobubbleContrast;
			out contrastDelivered : Boolean;
		}
		
		then merge acquisitionLoop;
		
		then action transmitUltrasound {
			in frequency : FrequencyValue;
			in power : PowerValue;
			out pulse : UltrasoundPulse;
		}
		
		then action receiveEnhancedEcho {
			in pulse : UltrasoundPulse;
			in contrastPresent : Boolean;
			out echo : EchoSignal;
		}
		
		then action processSignal {
			in echo : EchoSignal;
			out processedData : Real;
		}
		
		then action reconstructImage {
			in data : Real;
			out image : EnhancedImage;
		}
		
		then decide;
			if reconstructImage.image.contrastRatio >= 3.0 then completeAcquisition;
			if reconstructImage.image.contrastRatio < 3.0 then acquisitionLoop;
		
		action completeAcquisition;
		then done;
	}
	
	part ceusSystem {
		part transducer : UltrasoundTransducer {
			attribute :>> operatingFrequency = 3.5 [SI::MHz];
			attribute :>> maxPower = 1.2 [SI::W];
		}
		
		part injector : ContrastInjector {
			attribute :>> maxDosage = 5.0 [SI::mL];
			attribute :>> currentDosage = 0.0 [SI::mL];
		}
		
		part processor : SignalProcessor {
			attribute :>> gainLevel = 45.0;
			attribute :>> filterBandwidth = 2.0 [SI::MHz];
		}
		
		part reconstructor : ImageReconstructor {
			attribute :>> scanLines = 128;
			attribute :>> frameRate = 25.0 [SI::Hz];
		}
		
		part targetTissue : VascularTissue {
			attribute :>> bloodFlowVelocity = 8.0;
			attribute :>> vesselDiameter = 3.0 [SI::mm];
			attribute :>> perfusionRate = 0.8;
		}
		
		part operator : Operator;
		
		connect injector.deliveryPort to targetTissue;
		connect transducer.acousticInterface to targetTissue;
		connect targetTissue to transducer.acousticInterface;
		connect transducer to processor;
		connect processor to reconstructor;
		
		perform action imagingProcedure : PerformCEUSImaging;
	}
	
	occurrence def CEUSProcedure {
		ref operator : Operator;
		ref system : ceusSystem;
		ref tissue : VascularTissue;
		
		message injectionCmd of InjectionCommand
			from operator to system.injector.deliveryPort;
		
		then item contrastFlow of MicrobubbleContrast
			from system.injector.deliveryPort to tissue;
		
		then item pulseTransmission of UltrasoundPulse
			from system.transducer.acousticInterface to tissue;
		
		then item echoReturn of EchoSignal
			from tissue to system.transducer.acousticInterface;
		
		then item imageData of EnhancedImage
			from system.reconstructor.imageOutput to operator;
	}
	
	requirement def ImagingPerformanceRequirement;
	requirement def SafetyRequirement;
	requirement def ContrastSensitivityRequirement;
	
	requirement <'CEUS-001'> spatialResolution : ImagingPerformanceRequirement {
		doc /* The system shall provide spatial resolution better than 0.5 mm at depths up to 15 cm. */
		
		subject system : ceusSystem;
		
		require constraint {
			system.reconstructor.imageOutput.diagnosticImage.spatialResolution <= 0.5 [SI::mm]
		}
	}
	
	requirement <'CEUS-002'> contrastDetection : ContrastSensitivityRequirement {
		doc /* The system shall detect microbubble contrast agents at concentrations down to 0.01 mg/mL. */
		
		subject system : ceusSystem;
		
		require constraint {
			system.injector.deliveryPort.contrastBolus.concentration >= 0.01
		}
	}
	
	requirement <'CEUS-003'> frameRate : ImagingPerformanceRequirement {
		doc /* The system shall maintain a frame rate of at least 20 Hz during contrast imaging. */
		
		subject system : ceusSystem;
		
		require constraint {
			system.reconstructor.frameRate >= 20.0 [SI::Hz]
		}
	}
	
	requirement <'CEUS-004'> acousticSafety : SafetyRequirement {
		doc /* The system shall operate with mechanical index below 0.5 to ensure patient safety and microbubble stability. */
		
		subject system : ceusSystem;
		
		require constraint {
			system.transducer.acousticInterface.transmittedPulse.mechanicalIndex <= 0.5
		}
	}
	
	requirement <'CEUS-MISSION'> primaryFunction : ImagingPerformanceRequirement {
		doc /* The contrast-enhanced ultrasound system shall visualize tissue perfusion and vascularity 
		       by administering microbubble contrast agents and processing their acoustic response 
		       to generate high-contrast diagnostic images of blood flow and microvasculature. */
		
		assume constraint contrastAvailable {
			doc /* Microbubble contrast agent is prepared and available for injection. */
		}
		
		assume constraint patientReady {
			doc /* Patient is positioned and target anatomy is accessible. */
		}
		
		require spatialResolution;
		require contrastDetection;
		require frameRate;
		require acousticSafety;
	}
}
