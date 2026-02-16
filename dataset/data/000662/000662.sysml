package 'Laser Scalpel System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LaserMode;
	attribute def CuttingMode :> LaserMode;
	attribute def CoagulationMode :> LaserMode;
	attribute def StandbyMode :> LaserMode;
	attribute def OffMode :> LaserMode;
	
	attribute def SafetyState;
	attribute def InterlockEngaged :> SafetyState;
	attribute def InterlockDisengaged :> SafetyState;
	
	attribute def LaserPowerLevel :> ISQ::PowerValue;
	
	attribute def LaserWavelength :> ISQ::LengthValue;
	
	attribute def OperatingTemperature :> ISQ::ThermodynamicTemperatureValue;
	
	attribute def PulseDuration :> ISQ::TimeValue;
	
	attribute def CoolantFlowRate :> ISQ::VolumeFlowRateValue;
	
	port def PowerSupplyPort {
		out voltage : ISQ::ElectricPotentialDifferenceValue;
		out current : ISQ::ElectricCurrentValue;
	}
	
	port def LaserControlPort {
		in modeCommand : LaserMode;
		in powerLevel : LaserPowerLevel;
		in safetyInterlock : SafetyState;
		out actualMode : LaserMode;
		out actualPower : LaserPowerLevel;
		out statusMessage : String;
	}
	
	port def LaserBeamPort {
		out beamPower : LaserPowerLevel;
		out wavelength : LaserWavelength;
		out pulseWidth : PulseDuration;
	}
	
	port def CoolingPort {
		in flowRate : CoolantFlowRate;
		out temperature : OperatingTemperature;
	}
	
	port def FiberOpticPort {
		in beamPower : LaserPowerLevel;
		out deliveredPower : LaserPowerLevel;
	}
	
	part def LaserGenerator {
		attribute nominalWavelength : LaserWavelength;
		attribute maximumPower : LaserPowerLevel;
		attribute efficiency : Real;
		
		port powerInput : PowerSupplyPort;
		port controlInterface : LaserControlPort;
		port beamOutput : LaserBeamPort;
		port coolingInterface : CoolingPort;
		
		part laserDiodeArray {
			attribute numberOfDiodes : Integer;
			attribute diodeTemperature : OperatingTemperature;
		}
		
		part opticalCavity {
			attribute cavityLength : ISQ::LengthValue;
			attribute reflectivity : Real;
		}
		
		part beamShaper {
			attribute beamQuality : Real;
		}
	}
	
	part def OpticalDeliverySystem {
		port beamInput : LaserBeamPort;
		port fiberOutput : FiberOpticPort;
		
		part articulatedArm {
			attribute numberOfSegments : Integer;
			attribute totalLength : ISQ::LengthValue;
			attribute mirrorReflectivity : Real;
		}
		
		part fiberOpticCable {
			attribute coreSize : ISQ::LengthValue;
			attribute transmissionEfficiency : Real;
			attribute bendRadius : ISQ::LengthValue;
		}
		
		part collimatingLens {
			attribute focalLength : ISQ::LengthValue;
		}
	}
	
	part def SurgicalHandpiece {
		port fiberInput : FiberOpticPort;
		port coolingInput : CoolingPort;
		
		attribute weight : ISQ::MassValue;
		attribute length : ISQ::LengthValue;
		
		part focusingOptics {
			attribute spotSize : ISQ::LengthValue;
			attribute workingDistance : ISQ::LengthValue;
		}
		
		part aimingBeam {
			attribute aimingWavelength : LaserWavelength;
			attribute aimingPower : LaserPowerLevel;
		}
		
		part contactTipSensor {
			attribute tissueContact : Boolean;
		}
	}
	
	part def ControlConsole {
		port userInterface : LaserControlPort;
		port laserControl : LaserControlPort;
		port safetyMonitoring : LaserControlPort;
		
		part microprocessor {
			attribute clockSpeed : ISQ::FrequencyValue;
			attribute memorySize : String;
		}
		
		part touchscreenDisplay {
			attribute screenSize : ISQ::LengthValue;
			attribute resolution : String;
		}
		
		part footPedal {
			attribute pedalPosition : Real;
			attribute activationThreshold : Real;
		}
		
		part audioFeedback {
			attribute volume : Real;
		}
	}
	
	part def SafetyInterlockSystem {
		port safetyInput : LaserControlPort;
		port safetyOutput : LaserControlPort;
		
		part doorSwitch {
			attribute doorClosed : Boolean;
		}
		
		part keySwitch {
			attribute keyInserted : Boolean;
			attribute keyPosition : String;
		}
		
		part emergencyStopButton {
			attribute buttonPressed : Boolean;
		}
		
		part remoteInterlock {
			attribute externalInterlockActive : Boolean;
		}
	}
	
	part def ThermalManagementSystem {
		port coolingOutput : CoolingPort;
		port powerInput : PowerSupplyPort;
		
		attribute reservoirCapacity : ISQ::VolumeValue;
		
		part coolantPump {
			attribute pumpFlowRate : CoolantFlowRate;
			attribute pumpPressure : ISQ::PressureValue;
		}
		
		part heatExchanger {
			attribute thermalCapacity : ISQ::PowerValue;
			attribute exchangerEfficiency : Real;
		}
		
		part temperatureSensor {
			attribute measuredTemperature : OperatingTemperature;
			attribute sensorAccuracy : ISQ::TemperatureValue;
		}
		
		part coolantReservoir {
			attribute currentLevel : ISQ::VolumeValue;
		}
	}
	
	action def CheckSafetyInterlocks {
		in doorClosed : Boolean;
		in keyInserted : Boolean;
		in emergencyStop : Boolean;
		in externalInterlock : Boolean;
		out safeToOperate : Boolean;
	}
	
	action def SetLaserParameters {
		in requestedMode : LaserMode;
		in requestedPower : LaserPowerLevel;
		in safetyStatus : SafetyState;
		out configuredMode : LaserMode;
		out configuredPower : LaserPowerLevel;
	}
	
	action def MonitorCoolingSystem {
		in currentTemperature : OperatingTemperature;
		in maxTemperature : OperatingTemperature;
		in flowRate : CoolantFlowRate;
		out coolingAdequate : Boolean;
	}
	
	action def DeliverLaserEnergy {
		in operatingMode : LaserMode;
		in powerLevel : LaserPowerLevel;
		in pulseDuration : PulseDuration;
		in tissueContact : Boolean;
		out energyDelivered : ISQ::EnergyValue;
		out tissueEffect : String;
	}
	
	state def LaserSystemStates {
		entry; then powerOff;
		
		state powerOff;
		
		state initialization {
			do action systemSelfTest;
			do action calibrateSensors;
		}
		
		state standby;
		
		state ready;
		
		state cutting {
			do action deliverCuttingEnergy;
		}
		
		state coagulation {
			do action deliverCoagulationEnergy;
		}
		
		state fault {
			do action logFaultCondition;
		}
		
		transition powerOff_to_init
			first powerOff
			accept powerOnCommand
			then initialization;
		
		transition init_to_standby
			first initialization
			if selfTestPassed
			then standby;
		
		transition init_to_fault
			first initialization
			if not selfTestPassed
			then fault;
		
		transition standby_to_ready
			first standby
			accept interlockEngaged : SafetyState
			if interlockEngaged == InterlockEngaged
			then ready;
		
		transition ready_to_cutting
			first ready
			accept modeCommand : LaserMode
			if modeCommand == CuttingMode and safetyOk
			then cutting;
		
		transition ready_to_coagulation
			first ready
			accept modeCommand : LaserMode
			if modeCommand == CoagulationMode and safetyOk
			then coagulation;
		
		transition cutting_to_ready
			first cutting
			accept footPedalRelease
			then ready;
		
		transition coagulation_to_ready
			first coagulation
			accept footPedalRelease
			then ready;
		
		transition ready_to_standby
			first ready
			accept interlockDisengaged : SafetyState
			if interlockDisengaged == InterlockDisengaged
			then standby;
		
		transition any_to_fault
			first standby
			accept faultDetected
			then fault;
		
		transition fault_to_powerOff
			first fault
			accept systemReset
			if faultCleared
			then powerOff;
		
		attribute safetyOk : Boolean;
		attribute selfTestPassed : Boolean;
		attribute faultCleared : Boolean;
	}
	
	action def PerformSurgicalIncision {
		in targetTissueType : String;
		in incisionDepth : ISQ::LengthValue;
		in incisionLength : ISQ::LengthValue;
		out procedureComplete : Boolean;
		out totalEnergyDelivered : ISQ::EnergyValue;
		
		first start;
		
		then action initializeSystem {
			action performSafetyCheck : CheckSafetyInterlocks {
				in doorClosed;
				in keyInserted;
				in emergencyStop;
				in externalInterlock;
				out safeToOperate;
			}
			then action checkCooling : MonitorCoolingSystem {
				in currentTemperature;
				in maxTemperature;
				in flowRate;
				out coolingAdequate;
			}
		}
		
		then decide safetyDecision;
			if initializeSystem.performSafetyCheck.safeToOperate and 
			   initializeSystem.checkCooling.coolingAdequate 
			then configureSystem;
			if not (initializeSystem.performSafetyCheck.safeToOperate and 
			        initializeSystem.checkCooling.coolingAdequate)
			then abortProcedure;
		
		action configureSystem {
			action selectMode {
				in tissueType = targetTissueType;
				out selectedMode : LaserMode;
				out selectedPower : LaserPowerLevel;
			}
			then action setParameters : SetLaserParameters {
				in requestedMode = selectMode.selectedMode;
				in requestedPower = selectMode.selectedPower;
				in safetyStatus;
				out configuredMode;
				out configuredPower;
			}
		}
		
		then merge beginIncision;
		
		then action performIncision : DeliverLaserEnergy {
			in operatingMode = configureSystem.setParameters.configuredMode;
			in powerLevel = configureSystem.setParameters.configuredPower;
			in pulseDuration;
			in tissueContact;
			out energyDelivered;
			out tissueEffect;
		}
		
		then action updateProgress {
			in currentDepth : ISQ::LengthValue;
			in targetDepth = incisionDepth;
			out depthAchieved : Boolean;
		}
		
		then merge evaluateProgress;
		
		then decide completionDecision;
			if updateProgress.depthAchieved then finalizeProcedure;
			if not updateProgress.depthAchieved then performIncision;
		
		action finalizeProcedure {
			action returnToStandby;
			then action recordProcedureData {
				in totalEnergy = totalEnergyDelivered;
				in procedureDuration : ISQ::TimeValue;
			}
			then assign procedureComplete := true;
		}
		then done;
		
		action abortProcedure {
			action emergencyShutdown;
			then action logAbortReason {
				in reason : String;
			}
			then assign procedureComplete := false;
		}
		then done;
		
		attribute doorClosed : Boolean;
		attribute keyInserted : Boolean;
		attribute emergencyStop : Boolean;
		attribute externalInterlock : Boolean;
		attribute currentTemperature : OperatingTemperature;
		attribute maxTemperature : OperatingTemperature;
		attribute flowRate : CoolantFlowRate;
		attribute safetyStatus : SafetyState;
		attribute pulseDuration : PulseDuration;
		attribute tissueContact : Boolean;
	}
	
	part laserScalpelSystem {
		attribute systemIdentifier : String;
		attribute modelDesignation : String;
		attribute serialNumber : String;
		
		part laserSource : LaserGenerator {
			attribute nominalWavelength = 1064.0;
			attribute maximumPower = 120.0;
			attribute efficiency = 0.35;
		}
		
		part deliverySystem : OpticalDeliverySystem {
			part articulatedArm {
				attribute numberOfSegments = 7;
				attribute totalLength = 1.5;
				attribute mirrorReflectivity = 0.995;
			}
			part fiberOpticCable {
				attribute coreSize = 0.0006;
				attribute transmissionEfficiency = 0.92;
			}
		}
		
		part handpiece : SurgicalHandpiece {
			attribute weight = 0.18;
			attribute length = 0.22;
			part focusingOptics {
				attribute spotSize = 0.0003;
				attribute workingDistance = 0.005;
			}
		}
		
		part console : ControlConsole {
			part touchscreenDisplay {
				attribute screenSize = 0.254;
				attribute resolution = "1920x1080";
			}
		}
		
		part safetySystem : SafetyInterlockSystem;
		
		part coolingSystem : ThermalManagementSystem {
			attribute reservoirCapacity = 0.0025;
			part coolantPump {
				attribute pumpFlowRate = 0.000025;
			}
			part heatExchanger {
				attribute thermalCapacity = 200.0;
				attribute exchangerEfficiency = 0.88;
			}
		}
		
		port mainPowerInput : PowerSupplyPort;
		port operatorControl : LaserControlPort;
		port laserBeamOutput : LaserBeamPort;
		
		connection powerToLaser connect mainPowerInput to laserSource.powerInput;
		connection powerToCooling connect mainPowerInput to coolingSystem.powerInput;
		
		connection consoleToSafety connect console.safetyMonitoring to safetySystem.safetyInput;
		connection safetyToLaser connect safetySystem.safetyOutput to laserSource.controlInterface;
		connection operatorToConsole connect operatorControl to console.userInterface;
		connection consoleToLaser connect console.laserControl to laserSource.controlInterface;
		
		connection laserToDelivery connect laserSource.beamOutput to deliverySystem.beamInput;
		connection deliveryToHandpiece connect deliverySystem.fiberOutput to handpiece.fiberInput;
		connection handpieceToOutput connect handpiece.fiberInput to laserBeamOutput;
		
		connection coolingToLaser connect coolingSystem.coolingOutput to laserSource.coolingInterface;
		connection coolingToHandpiece connect coolingSystem.coolingOutput to handpiece.coolingInput;
		
		exhibit state operatingStateMachine : LaserSystemStates;
		
		perform action surgicalProcedure : PerformSurgicalIncision[*];
	}
	
	requirement def <'REQ-LSS-001'> PrimaryFunctionRequirement {
		doc /* The laser scalpel system shall perform precise surgical incisions and tissue 
		       coagulation by delivering controlled, focused laser energy to biological tissue, 
		       enabling minimally invasive surgical procedures with reduced thermal damage to 
		       surrounding tissue compared to conventional electrosurgical methods. */
		
		subject laserScalpelSystem;
		
		require constraint precisionCutting {
			doc /* The system shall deliver laser energy with a focal spot size not exceeding 0.5mm 
			       to enable precise tissue cutting. */
		}
		
		require constraint powerRange {
			doc /* The system shall provide adjustable laser power output from 1W to 120W to 
			       accommodate different tissue types and surgical procedures. */
		}
		
		require constraint wavelengthStability {
			doc /* The laser wavelength shall remain stable at 1064nm within 5nm during operation. */
		}
	}
	
	requirement def <'REQ-LSS-002'> SafetyRequirement {
		doc /* The laser scalpel system shall incorporate comprehensive safety mechanisms to 
		       prevent accidental laser emission and protect surgical staff and patients from 
		       laser hazards. */
		
		subject laserScalpelSystem;
		
		require constraint multipleInterlocks {
			doc /* The system shall require engagement of at least three independent safety 
			       interlocks before laser emission is permitted. */
		}
		
		require constraint emergencyShutoff {
			doc /* The emergency stop function shall terminate laser emission within 50ms of 
			       activation. */
		}
		
		require constraint keyControl {
			doc /* The system shall require an authorized key switch to be engaged for operation. */
		}
	}
	
	requirement def <'REQ-LSS-003'> ThermalManagementRequirement {
		doc /* The laser scalpel system shall maintain all critical components within safe 
		       operating temperature ranges during continuous use. */
		
		subject laserScalpelSystem;
		
		require constraint laserTemperature {
			doc /* The laser generator temperature shall not exceed 323K during continuous operation. */
		}
		
		require constraint coolingCapacity {
			doc /* The cooling system shall provide minimum 200W heat dissipation capacity. */
		}
		
		require constraint coolantFlow {
			doc /* The cooling system shall maintain minimum 1.0 L/min coolant flow rate. */
		}
	}
	
	requirement def <'REQ-LSS-004'> OperationalRequirement {
		doc /* The laser scalpel system shall provide reliable, consistent performance throughout 
		       extended surgical procedures. */
		
		subject laserScalpelSystem;
		
		require constraint powerStability {
			doc /* Laser output power shall remain within 5 percent of set value during continuous operation. */
		}
		
		require constraint responseTime {
			doc /* The system shall respond to power adjustment commands within 100ms. */
		}
		
		require constraint continuousOperation {
			doc /* The system shall support continuous operation for minimum 4 hours without 
			       performance degradation. */
		}
	}
	
	requirement <'SYS-LSS-001'> systemRequirement : PrimaryFunctionRequirement {
		doc /* Top-level system requirement for laser scalpel surgical capability. */
		
		assume constraint surgicalEnvironment {
			doc /* The system operates in a controlled surgical environment with ambient temperature 
			       between 293K and 298K and relative humidity between 30 percent and 70 percent. */
		}
		
		assume constraint trainedOperators {
			doc /* The system is operated by trained surgical personnel with laser safety certification. */
		}
		
		require <'REQ-LSS-001'> PrimaryFunctionRequirement;
		require <'REQ-LSS-002'> SafetyRequirement;
		require <'REQ-LSS-003'> ThermalManagementRequirement;
		require <'REQ-LSS-004'> OperationalRequirement;
	}
}
