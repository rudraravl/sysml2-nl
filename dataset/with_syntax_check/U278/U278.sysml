package 'Laser Microtome System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LaserPowerCommand;
	attribute def StagePositionCommand;
	attribute def SectioningComplete;
	attribute def SystemInitialized;
	attribute def SafetyInterlock;
	
	item def TissueSample {
		attribute sampleWidth : ISQ::LengthValue;
		attribute sampleHeight : ISQ::LengthValue;
		attribute sampleDepth : ISQ::LengthValue;
		attribute frozen : Boolean;
	}
	
	item def TissueSection {
		attribute thickness : ISQ::LengthValue;
		attribute sectionNumber : Integer;
		attribute imageData : String;
	}
	
	port def LaserControlPort {
		in powerCommand : LaserPowerCommand;
		out powerStatus : ISQ::PowerValue;
	}
	
	port def StageControlPort {
		in positionCommand : StagePositionCommand;
		out currentPosition : ISQ::LengthValue;
	}
	
	port def OpticalPort {
		out laserBeam;
	}
	
	port def SampleMountPort {
		in sample : TissueSample;
		out section : TissueSection;
	}
	
	port def CoolingPort {
		in targetTemperature : ISQ::ThermodynamicTemperatureValue;
		out currentTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	part def UVLaserSource {
		attribute wavelength : ISQ::LengthValue;
		attribute maxPower : ISQ::PowerValue;
		attribute currentPower : ISQ::PowerValue;
		attribute pulseWidth : ISQ::TimeValue;
		port controlInput : LaserControlPort;
		port beamOutput : OpticalPort;
	}
	
	part def BeamSteeringOptics {
		attribute focusSpotSize : ISQ::LengthValue;
		attribute workingDistance : ISQ::LengthValue;
		port beamInput : OpticalPort;
		port focusedOutput : OpticalPort;
	}
	
	part def CryogenicStage {
		attribute positionX : ISQ::LengthValue;
		attribute positionY : ISQ::LengthValue;
		attribute positionZ : ISQ::LengthValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute positionAccuracy : ISQ::LengthValue;
		port motionControl : StageControlPort;
		port sampleMount : SampleMountPort;
		port cooling : CoolingPort;
	}
	
	part def CryoCoolingSystem {
		attribute coolingCapacity : ISQ::PowerValue;
		attribute minTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute stabilityTolerance : ISQ::ThermodynamicTemperatureValue;
		port thermalControl : CoolingPort;
	}
	
	part def ImagingCamera {
		attribute resolution : ISQ::LengthValue;
		attribute captureRate : Real;
		attribute fieldOfView : ISQ::LengthValue;
		port imageOutput;
	}
	
	part def VacuumSystem {
		attribute pressure : ISQ::PressureValue;
		attribute pumpingSpeed : ISQ::VolumeFlowRateValue;
	}
	
	part def SafetySystem {
		attribute interlockActive : Boolean;
		attribute enclosureClosed : Boolean;
		port safetyControl;
	}
	
	part def SystemController {
		attribute sectionThickness : ISQ::LengthValue;
		attribute scanSpeed : ISQ::SpeedValue;
		attribute numberOfSections : Integer;
		port laserControl : LaserControlPort;
		port stageControl : StageControlPort;
		port imagingControl;
		port safetyMonitor;
		perform action sectioningSequence[*] ordered references performSectioning;
	}
	
	part laserMicrotome {
		doc /* 
		 * A laser microtome system that performs high-precision, non-contact 
		 * sectioning of biological tissue samples using focused UV laser ablation 
		 * under cryogenic conditions, enabling three-dimensional reconstruction 
		 * through sequential imaging of thin sections.
		 */
		
		part uvLaser : UVLaserSource {
			attribute wavelength = 355.0 [SI::nm];
			attribute maxPower = 10.0 [SI::W];
			attribute currentPower = 0.0 [SI::W];
			attribute pulseWidth = 10.0 [SI::ns];
		}
		
		part optics : BeamSteeringOptics {
			attribute focusSpotSize = 5.0 [SI::'µm'];
			attribute workingDistance = 50.0 [SI::mm];
		}
		
		part stage : CryogenicStage {
			attribute positionX = 0.0 [SI::mm];
			attribute positionY = 0.0 [SI::mm];
			attribute positionZ = 0.0 [SI::mm];
			attribute temperature = 253.15 [SI::K];
			attribute positionAccuracy = 0.1 [SI::'µm'];
		}
		
		part coolingSystem : CryoCoolingSystem {
			attribute coolingCapacity = 500.0 [SI::W];
			attribute minTemperature = 233.15 [SI::K];
			attribute stabilityTolerance = 0.5 [SI::K];
		}
		
		part camera : ImagingCamera {
			attribute resolution = 0.5 [SI::'µm'];
			attribute captureRate = 10.0;
			attribute fieldOfView = 5.0 [SI::mm];
		}
		
		part vacuum : VacuumSystem {
			attribute pressure = 0.001 [SI::Pa];
			attribute pumpingSpeed = 100.0 [SI::'L/s'];
		}
		
		part safety : SafetySystem {
			attribute interlockActive = true;
			attribute enclosureClosed = true;
		}
		
		part controller : SystemController {
			attribute sectionThickness = 10.0 [SI::'µm'];
			attribute scanSpeed = 2.0 [SI::'mm/s'];
			attribute numberOfSections = 100;
		}
		
		connect uvLaser.beamOutput to optics.beamInput;
		connect optics.focusedOutput to stage.sampleMount;
		connect coolingSystem.thermalControl to stage.cooling;
		connect controller.laserControl to uvLaser.controlInput;
		connect controller.stageControl to stage.motionControl;
		connect controller.imagingControl to camera.imageOutput;
		connect controller.safetyMonitor to safety.safetyControl;
	}
	
	action def InitializeSystem {
		out systemReady : SystemInitialized;
	}
	
	action def CoolSample {
		in targetTemp : ISQ::ThermodynamicTemperatureValue;
		in currentTemp : ISQ::ThermodynamicTemperatureValue;
		out stabilizedTemp : ISQ::ThermodynamicTemperatureValue;
	}
	
	action def PositionStage {
		in targetX : ISQ::LengthValue;
		in targetY : ISQ::LengthValue;
		in targetZ : ISQ::LengthValue;
		out actualX : ISQ::LengthValue;
		out actualY : ISQ::LengthValue;
		out actualZ : ISQ::LengthValue;
	}
	
	action def AblateSection {
		in laserPower : ISQ::PowerValue;
		in scanSpeed : ISQ::SpeedValue;
		in sectionDepth : ISQ::LengthValue;
		out ablationComplete : SectioningComplete;
	}
	
	action def CaptureImage {
		in exposureTime : ISQ::TimeValue;
		out imageData : String;
	}
	
	action def AdvanceDepth {
		in incrementDepth : ISQ::LengthValue;
		in currentDepth : ISQ::LengthValue;
		out newDepth : ISQ::LengthValue;
	}
	
	action performSectioning : PerformSectioning {
		in sampleThickness : ISQ::LengthValue;
		in targetSectionThickness : ISQ::LengthValue;
		in totalSections : Integer;
		out generatedSections : TissueSection[*] := ( );
	}
	
	action def PerformSectioning {
		in sampleThickness : ISQ::LengthValue;
		in targetSectionThickness : ISQ::LengthValue;
		in totalSections : Integer;
		out generatedSections : TissueSection[*] := ( );
		
		private attribute currentDepth : ISQ::LengthValue := 0.0 [SI::'µm'];
		private attribute sectionCounter : Integer := 0;
		
		first start;
		then merge initialize;
		
		then action init : InitializeSystem {
			out systemReady;
		}
		
		then action coolDown : CoolSample {
			in targetTemp = 253.15 [SI::K];
			in currentTemp = 298.15 [SI::K];
			out stabilizedTemp;
		}
		
		then merge sectionLoop;
		
		then decide;
			if sectionCounter < totalSections then executeSection;
			if sectionCounter >= totalSections then completeProcess;
		
		action executeSection {
			first action position : PositionStage {
				in targetX = 0.0 [SI::mm];
				in targetY = 0.0 [SI::mm];
				in targetZ = currentDepth;
				out actualX;
				out actualY;
				out actualZ;
			}
			
			then action ablate : AblateSection {
				in laserPower = 8.0 [SI::W];
				in scanSpeed = 2.0 [SI::'mm/s'];
				in sectionDepth = targetSectionThickness;
				out ablationComplete;
			}
			
			then action capture : CaptureImage {
				in exposureTime = 0.1 [SI::s];
				out imageData;
			}
			
			then action advance : AdvanceDepth {
				in incrementDepth = targetSectionThickness;
				in currentDepth = performSectioning::currentDepth;
				out newDepth;
			}
			
			then assign performSectioning::currentDepth := advance.newDepth;
			then assign performSectioning::sectionCounter := performSectioning::sectionCounter + 1;
		}
		
		then sectionLoop;
		
		action completeProcess;
		
		then done;
	}
	
	state def LaserMicrotomeStates {
		entry; then idle;
		
		state idle {
			entry assign laserMicrotome.uvLaser.currentPower := 0.0 [SI::W];
		}
		accept SystemInitialized
		then cooling;
		
		state cooling {
			do action maintainCooling : CoolSample {
				in targetTemp = 253.15 [SI::K];
				in currentTemp = laserMicrotome.stage.temperature;
				out stabilizedTemp;
			}
		}
		if laserMicrotome.stage.temperature <= 255.15 [SI::K]
		then ready;
		
		state ready;
		accept LaserPowerCommand
		then sectioning;
		
		state sectioning {
			do action section : PerformSectioning {
				in sampleThickness = 1000.0 [SI::'µm'];
				in targetSectionThickness = 10.0 [SI::'µm'];
				in totalSections = 100;
				out generatedSections;
			}
		}
		accept SectioningComplete
		then imaging;
		
		state imaging {
			do action captureImage : CaptureImage {
				in exposureTime = 0.1 [SI::s];
				out imageData;
			}
		}
		then sectioning;
		
		accept SafetyInterlock
		then emergency;
		
		state emergency {
			entry assign laserMicrotome.uvLaser.currentPower := 0.0 [SI::W];
		}
		then idle;
	}
	
	requirement def SectionThicknessPrecision {
		doc /* 
		 * The laser microtome shall produce tissue sections with thickness 
		 * precision of +/- 0.5 micrometers from the commanded value.
		 */
		
		subject laserMicrotome;
		
		require constraint {
			laserMicrotome.controller.sectionThickness >= 1.0 [SI::'µm'] and
			laserMicrotome.controller.sectionThickness <= 100.0 [SI::'µm']
		}
	}
	
	requirement def CryogenicTemperatureControl {
		doc /* 
		 * The cryogenic stage shall maintain sample temperature at -20°C +/- 1°C 
		 * throughout the sectioning process to preserve tissue morphology.
		 */
		
		subject laserMicrotome.stage;
		
		require constraint {
			laserMicrotome.stage.temperature >= 252.15 [SI::K] and
			laserMicrotome.stage.temperature <= 254.15 [SI::K]
		}
	}
	
	requirement def LaserAblationCapability {
		doc /* 
		 * The UV laser source shall deliver focused energy at 355 nm wavelength 
		 * with minimum 5 W power for efficient tissue ablation.
		 */
		
		subject laserMicrotome.uvLaser;
		
		require constraint {
			laserMicrotome.uvLaser.wavelength == 355.0 [SI::nm] and
			laserMicrotome.uvLaser.maxPower >= 5.0 [SI::W]
		}
	}
	
	requirement def PositioningAccuracy {
		doc /* 
		 * The cryogenic stage shall achieve positioning accuracy better than 
		 * 0.5 micrometers in all three axes.
		 */
		
		subject laserMicrotome.stage;
		
		require constraint {
			laserMicrotome.stage.positionAccuracy <= 0.5 [SI::'µm']
		}
	}
	
	requirement def ImagingResolution {
		doc /* 
		 * The imaging camera shall capture section images with resolution 
		 * better than 1 micrometer for quality verification and reconstruction.
		 */
		
		subject laserMicrotome.camera;
		
		require constraint {
			laserMicrotome.camera.resolution <= 1.0 [SI::'µm']
		}
	}
	
	requirement def SafetyInterlockOperation {
		doc /* 
		 * The safety system shall immediately disable laser emission when 
		 * the protective enclosure is opened or interlock is triggered.
		 */
		
		subject laserMicrotome.safety;
		
		require constraint {
			laserMicrotome.safety.interlockActive == true implies
			laserMicrotome.uvLaser.currentPower == 0.0 [SI::W]
		}
	}
	
	requirement laserMicrotomeMission {
		doc /* 
		 * The laser microtome system shall perform automated, high-precision 
		 * sectioning of frozen biological tissue samples through sequential 
		 * UV laser ablation, maintaining cryogenic temperatures and capturing 
		 * high-resolution images of each section to enable three-dimensional 
		 * reconstruction and volumetric analysis of tissue architecture.
		 */
		
		assume constraint samplePrepared {
			doc /* A properly prepared and frozen tissue sample is mounted on the cryogenic stage. */
		}
		
		assume constraint systemCalibrated {
			doc /* The laser optics and stage positioning systems are calibrated and aligned. */
		}
		
		assume constraint vacuumEstablished {
			doc /* The vacuum chamber is evacuated to prevent frost formation. */
		}
		
		require thicknessPrecision : SectionThicknessPrecision;
		require temperatureControl : CryogenicTemperatureControl;
		require ablationCapability : LaserAblationCapability;
		require positioningAccuracy : PositioningAccuracy;
		require imagingResolution : ImagingResolution;
		require safetyInterlock : SafetyInterlockOperation;
	}
}
