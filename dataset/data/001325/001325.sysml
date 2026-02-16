package 'Microfabrication System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def LayerData;
	attribute def BuildParameters;
	attribute def SystemReady;
	attribute def BuildComplete;
	attribute def EmergencyStop;
	
	part def LaserSource {
		attribute power : PowerValue;
		attribute wavelength : LengthValue;
		attribute beamDiameter : LengthValue;
		attribute pulseFrequency : FrequencyValue;
		port laserOutput;
		port powerControl;
	}
	
	part def OpticalSystem {
		attribute numericalAperture : Real;
		attribute focusDepth : LengthValue;
		attribute scanFieldSize : AreaValue;
		port beamInput;
		port focusedBeamOutput;
		port positionControl;
	}
	
	part def PrecisionStage {
		attribute travelRange : LengthValue;
		attribute positionResolution : LengthValue;
		attribute maxSpeed : SpeedValue;
		attribute currentPosition : LengthValue;
		port motionControl;
		port substrateMount;
	}
	
	part def MaterialSupplySystem {
		attribute resinType : String;
		attribute viscosity : Real;
		attribute flowRate : Real;
		port materialOutput;
		port levelSensor;
	}
	
	part def EnvironmentalChamber {
		attribute temperature : TemperatureValue;
		attribute humidity : Real;
		attribute inertGas : String;
		attribute pressure : PressureValue;
		port atmosphereControl;
	}
	
	part def ImagingSystem {
		attribute resolution : LengthValue;
		attribute magnification : Real;
		attribute captureRate : FrequencyValue;
		port imageOutput;
		port illumination;
	}
	
	part def ControlComputer {
		attribute processingPower : Real;
		attribute memoryCapacity : Real;
		port systemControl;
		port dataInterface;
		port userInterface;
	}
	
	action def InitializeSystem {
		in buildParams : BuildParameters;
		out systemStatus : SystemReady;
	}
	
	action def LoadDesignData {
		in modelFile : String;
		out layerSequence : LayerData[*];
		out totalLayers : Integer;
	}
	
	action def PositionStage {
		in targetZ : LengthValue;
		in currentZ : LengthValue;
		out newPosition : LengthValue;
	}
	
	action def DispenseMaterial {
		in layerThickness : LengthValue;
		in coverage : AreaValue;
		out materialReady : Boolean;
	}
	
	action def ExposurePattern {
		in layerData : LayerData;
		in laserPower : PowerValue;
		in exposureTime : TimeValue;
		out patternComplete : Boolean;
	}
	
	action def InspectLayer {
		in layerNumber : Integer;
		in expectedThickness : LengthValue;
		out qualityCheck : Boolean;
		out measuredThickness : LengthValue;
	}
	
	action def PostCure {
		in exposureDuration : TimeValue;
		in wavelength : LengthValue;
		out curingComplete : Boolean;
	}
	
	action def ExtractPart {
		out partReady : BuildComplete;
	}
	
	action def FabricateMicrostructure {
		in designModel : String;
		in materialType : String;
		in layerHeight : LengthValue;
		in laserPowerLevel : PowerValue;
		out completedStructure : BuildComplete;
		
		private attribute layerSequence : LayerData[*];
		private attribute totalLayers : Integer;
		private attribute currentLayerIndex : Integer := 1;
		private attribute stagePosition : LengthValue := 0.0[mm];
		
		first start;
		then action init : InitializeSystem {
			in buildParams;
			out systemStatus;
		}
		then action loadData : LoadDesignData {
			in modelFile = designModel;
			out layerSequence;
			out totalLayers;
		}
		then assign layerSequence := loadData.layerSequence;
		then assign totalLayers := loadData.totalLayers;
		then merge processNextLayer;
		
		action dispense : DispenseMaterial {
			in layerThickness = layerHeight;
			in coverage = 100.0[mm^2];
			out materialReady;
		}
		then action position : PositionStage {
			in targetZ = stagePosition;
			in currentZ = stagePosition;
			out newPosition;
		}
		then action expose : ExposurePattern {
			in layerData = layerSequence->at(currentLayerIndex);
			in laserPower = laserPowerLevel;
			in exposureTime = 0.5[s];
			out patternComplete;
		}
		then action inspect : InspectLayer {
			in layerNumber = currentLayerIndex;
			in expectedThickness = layerHeight;
			out qualityCheck;
			out measuredThickness;
		}
		then decide;
			if inspect.qualityCheck and currentLayerIndex < totalLayers then advance;
			if inspect.qualityCheck and currentLayerIndex >= totalLayers then finalize;
			if not inspect.qualityCheck then rework;
		
		action advance {
			then assign stagePosition := stagePosition + layerHeight;
			then assign currentLayerIndex := currentLayerIndex + 1;
			then processNextLayer;
		}
		
		action rework {
			then assign currentLayerIndex := currentLayerIndex;
			then processNextLayer;
		}
		
		action finalize {
			action cure : PostCure {
				in exposureDuration = 300.0[s];
				in wavelength = 365.0[nm];
				out curingComplete;
			}
			then action extract : ExtractPart {
				out partReady;
			}
			then assign completedStructure := extract.partReady;
			then done;
		}
	}
	
	part def MicrofabricationSystem {
		attribute buildVolume : VolumeValue;
		attribute minFeatureSize : LengthValue;
		attribute maxBuildRate : Real;
		
		part laser : LaserSource {
			attribute :>> power = 200.0[mW];
			attribute :>> wavelength = 780.0[nm];
			attribute :>> beamDiameter = 1.0[mm];
			attribute :>> pulseFrequency = 80.0[MHz];
		}
		
		part optics : OpticalSystem {
			attribute :>> numericalAperture = 1.4;
			attribute :>> focusDepth = 2.0[um];
			attribute :>> scanFieldSize = 500.0[um^2];
		}
		
		part stage : PrecisionStage {
			attribute :>> travelRange = 100.0[mm];
			attribute :>> positionResolution = 0.1[um];
			attribute :>> maxSpeed = 10.0[mm/s];
			attribute :>> currentPosition = 0.0[mm];
		}
		
		part materialSupply : MaterialSupplySystem {
			attribute :>> resinType = "photopolymer";
			attribute :>> viscosity = 50.0;
			attribute :>> flowRate = 0.1;
		}
		
		part chamber : EnvironmentalChamber {
			attribute :>> temperature = 293.15[K];
			attribute :>> humidity = 0.3;
			attribute :>> inertGas = "nitrogen";
			attribute :>> pressure = 101325.0[Pa];
		}
		
		part imaging : ImagingSystem {
			attribute :>> resolution = 0.5[um];
			attribute :>> magnification = 100.0;
			attribute :>> captureRate = 10.0[Hz];
		}
		
		part controller : ControlComputer {
			attribute :>> processingPower = 3.5;
			attribute :>> memoryCapacity = 32.0;
		}
		
		connect laser.laserOutput to optics.beamInput;
		connect optics.focusedBeamOutput to stage.substrateMount;
		connect materialSupply.materialOutput to stage.substrateMount;
		connect controller.systemControl to laser.powerControl;
		connect controller.systemControl to optics.positionControl;
		connect controller.systemControl to stage.motionControl;
		connect controller.systemControl to chamber.atmosphereControl;
		connect imaging.imageOutput to controller.dataInterface;
		
		perform action fabricate[*] ordered references fabricationProcess;
	}
	
	action fabricationProcess : FabricateMicrostructure {
		in designModel : String;
		in materialType : String;
		in layerHeight : LengthValue;
		in laserPowerLevel : PowerValue;
		out completedStructure : BuildComplete;
	}
	
	part microfabSystem : MicrofabricationSystem {
		attribute :>> buildVolume = 1000.0[mm^3];
		attribute :>> minFeatureSize = 0.2[um];
		attribute :>> maxBuildRate = 0.5;
	}
	
	requirement <'MF-REQ-001'> primaryFunctionRequirement {
		doc /* The microfabrication system shall construct three-dimensional 
		     microscale structures by selectively solidifying photosensitive 
		     material layer-by-layer using focused laser radiation with 
		     sub-micrometer precision. */
		
		subject microfabSystem;
		
		require constraint {
			microfabSystem.minFeatureSize <= 1.0[um]
		}
	}
	
	requirement <'MF-REQ-002'> resolutionRequirement {
		doc /* The system shall achieve a minimum feature resolution of 
		     200 nanometers in the lateral dimensions. */
		
		subject microfabSystem;
		
		require constraint {
			microfabSystem.minFeatureSize <= 0.2[um]
		}
		
		require constraint {
			microfabSystem.stage.positionResolution <= 0.1[um]
		}
	}
	
	requirement <'MF-REQ-003'> layerProcessRequirement {
		doc /* Each fabrication layer shall be deposited, exposed, and 
		     inspected sequentially before advancing to the next layer. */
		
		assume constraint {
			fabricationProcess.layerHeight > 0.0[um]
		}
		
		require constraint {
			fabricationProcess.layerHeight >= 0.1[um] and
			fabricationProcess.layerHeight <= 10.0[um]
		}
	}
	
	requirement <'MF-REQ-004'> environmentalRequirement {
		doc /* The build environment shall maintain controlled temperature 
		     and inert atmosphere to prevent material degradation and 
		     ensure process repeatability. */
		
		subject microfabSystem;
		
		require constraint {
			microfabSystem.chamber.temperature >= 288.15[K] and
			microfabSystem.chamber.temperature <= 298.15[K]
		}
		
		require constraint {
			microfabSystem.chamber.humidity <= 0.4
		}
	}
	
	requirement <'MF-REQ-005'> buildVolumeRequirement {
		doc /* The system shall provide a minimum build volume of 
		     1 cubic millimeter for fabricating functional microdevices. */
		
		subject microfabSystem;
		
		require constraint {
			microfabSystem.buildVolume >= 1.0[mm^3]
		}
	}
	
	requirement <'MF-REQ-006'> qualityAssuranceRequirement {
		doc /* Each fabricated layer shall be inspected for dimensional 
		     accuracy before proceeding to ensure structural integrity. */
		
		require constraint {
			microfabSystem.imaging.resolution <= 1.0[um]
		}
	}
}
