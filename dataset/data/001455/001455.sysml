package 'Honeybee Robotics Planetary Drilling System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DrillDepth :> ISQ::LengthValue {
		doc /* Depth achieved by drilling operation below planetary surface */
	}
	
	attribute def DrillTorque :> ISQ::TorqueValue {
		doc /* Rotational torque applied by drill motor */
	}
	
	attribute def DrillSpeed :> ISQ::AngularVelocityValue {
		doc /* Rotational speed of drill bit */
	}
	
	attribute def SampleMass :> ISQ::MassValue {
		doc /* Mass of collected regolith or rock sample */
	}
	
	attribute def Temperature :> ISQ::ThermodynamicTemperatureValue {
		doc /* Operating temperature of system components */
	}
	
	attribute def Voltage :> ISQ::ElectricPotentialValue {
		doc /* Electrical voltage for power distribution */
	}
	
	attribute def Current :> ISQ::ElectricCurrentValue {
		doc /* Electrical current draw */
	}
	
	enum def OperationalMode {
		stowed;
		deploying;
		positioning;
		drilling;
		retracting;
		transferring;
		complete;
		fault;
	}
	
	enum def SampleCondition {
		pristine;
		acceptable;
		compromised;
	}
	
	attribute def DrillCommand;
	attribute def PositionCommand;
	attribute def TransferCommand;
	attribute def SystemHalt;
	
	requirement def MissionRequirement {
		doc /* Top-level mission requirements for planetary sample acquisition */
	}
	
	requirement def PerformanceRequirement :> MissionRequirement;
	requirement def SafetyRequirement :> MissionRequirement;
	requirement def ReliabilityRequirement :> MissionRequirement;
	
	part def PlanetaryDrillingSystem {
		doc /* Integrated autonomous drilling system for planetary subsurface exploration and sample return */
		
		attribute minDrillDepth : DrillDepth;
		attribute maxDrillDepth : DrillDepth;
		attribute minSampleMass : SampleMass;
		attribute minOperatingTemp : Temperature;
		attribute maxOperatingTemp : Temperature;
		attribute peakPowerConsumption : ISQ::PowerValue;
		attribute sampleCondition : SampleCondition;
	}
	
	requirement <'HBRS-001'> subsurfaceSamplingRequirement : PerformanceRequirement {
		doc /* The system shall acquire subsurface samples from depths between 5 cm and 100 cm below the planetary surface. */
		subject drillingSystem : PlanetaryDrillingSystem;
		require constraint {
			drillingSystem.minDrillDepth >= 5.0[SI::cm] and
			drillingSystem.maxDrillDepth >= 100.0[SI::cm]
		}
	}
	
	requirement <'HBRS-002'> sampleMassRequirement : PerformanceRequirement {
		doc /* The system shall collect and preserve at least 30 grams of sample material per drilling operation. */
		subject drillingSystem : PlanetaryDrillingSystem;
		require constraint {
			drillingSystem.minSampleMass >= 30.0[SI::g]
		}
	}
	
	requirement <'HBRS-003'> operatingTemperatureRequirement : ReliabilityRequirement {
		doc /* The system shall operate reliably in extreme temperature environments from -150 degC to +70 degC. */
		subject drillingSystem : PlanetaryDrillingSystem;
		require constraint {
			drillingSystem.minOperatingTemp <= -150.0[SI::K] and
			drillingSystem.maxOperatingTemp >= 70.0[SI::K]
		}
	}
	
	requirement <'HBRS-004'> powerConsumptionRequirement : PerformanceRequirement {
		doc /* The system shall not exceed 150 Watts peak power consumption during drilling operations. */
		subject drillingSystem : PlanetaryDrillingSystem;
		require constraint {
			drillingSystem.peakPowerConsumption <= 150.0[SI::W]
		}
	}
	
	requirement <'HBRS-005'> sampleIntegrityRequirement : SafetyRequirement {
		doc /* The system shall maintain sample integrity and prevent cross-contamination during collection and storage. */
		subject drillingSystem : PlanetaryDrillingSystem;
		require constraint {
			drillingSystem.sampleCondition == SampleCondition::pristine or
			drillingSystem.sampleCondition == SampleCondition::acceptable
		}
	}
	
	port def PowerInputPort {
		in voltage : Voltage;
		in current : Current;
	}
	
	port def DrillControlPort {
		in command : DrillCommand;
		out status : OperationalMode;
	}
	
	port def SampleOutputPort {
		out sampleMass : SampleMass;
		out sampleCondition : SampleCondition;
	}
	
	port def PositionControlPort {
		in positionCommand : PositionCommand;
		out currentPosition : ISQ::LengthValue;
	}
	
	port def ThermalPort {
		out temperature : Temperature;
	}
	
	part def DrillMotorAssembly {
		doc /* Brushless DC motor with gearbox for rotary-percussive drilling */
		
		attribute motorTorque : DrillTorque;
		attribute motorSpeed : DrillSpeed;
		attribute powerDraw : ISQ::PowerValue;
		
		port powerIn : PowerInputPort;
		port controlIn : DrillControlPort;
		port thermalOut : ThermalPort;
	}
	
	part def DrillBitAssembly {
		doc /* Carbide-tipped drill bit with fluted design for sample extraction */
		
		attribute currentDepth : DrillDepth;
		attribute bitDiameter : ISQ::LengthValue;
		attribute wearLevel : Real;
		
		port mechanicalInput;
		port sampleOutput : SampleOutputPort;
	}
	
	part def LinearActuator {
		doc /* Electromechanical actuator for vertical positioning of drill assembly */
		
		attribute position : ISQ::LengthValue;
		attribute maxStroke : ISQ::LengthValue;
		attribute force : ISQ::ForceValue;
		
		port powerIn : PowerInputPort;
		port positionControl : PositionControlPort;
	}
	
	part def SampleCacheSystem {
		doc /* Hermetically sealed sample containers with transfer mechanism */
		
		attribute storedMass : SampleMass;
		attribute numberOfContainers : Integer;
		attribute sealIntegrity : Real;
		
		port sampleIn : SampleOutputPort;
		port storageStatus;
	}
	
	part def ThermalManagementSystem {
		doc /* Active heating elements and passive insulation for temperature control */
		
		attribute currentTemp : Temperature;
		attribute targetTemp : Temperature;
		attribute heaterPower : ISQ::PowerValue;
		
		port powerIn : PowerInputPort;
		port thermalSensors : ThermalPort[*];
		port heaterControl;
	}
	
	part def ControllerUnit {
		doc /* Embedded flight computer managing all subsystem operations and telemetry */
		
		port drillControl : DrillControlPort;
		port actuatorControl : PositionControlPort;
		port thermalControl;
		port telemetryInterface;
		port commandInterface;
	}
	
	part def PowerDistributionUnit {
		doc /* Regulated power supply with overcurrent protection */
		
		attribute inputVoltage : Voltage;
		attribute outputVoltage : Voltage;
		attribute totalCurrent : Current;
		
		port primaryPowerIn : PowerInputPort;
		port drillPowerOut : PowerInputPort;
		port actuatorPowerOut : PowerInputPort;
		port thermalPowerOut : PowerInputPort;
	}
	
	action def DeployDrill {
		in deploymentAngle : Real;
		out deploymentSuccess : Boolean;
	}
	
	action def PositionDrill {
		in targetDepth : DrillDepth;
		out positionAchieved : Boolean;
		out actualPosition : ISQ::LengthValue;
	}
	
	action def ExecuteDrilling {
		in drillDepth : DrillDepth;
		in drillTorque : DrillTorque;
		in drillSpeed : DrillSpeed;
		out achievedDepth : DrillDepth;
		out sampleMass : SampleMass;
		out drillSuccess : Boolean;
	}
	
	action def ExtractSample {
		out extractedMass : SampleMass;
		out extractionSuccess : Boolean;
	}
	
	action def TransferToCache {
		in sampleMass : SampleMass;
		in containerID : Integer;
		out transferSuccess : Boolean;
	}
	
	action def RetractDrill {
		out retractionSuccess : Boolean;
	}
	
	action def MonitorThermals {
		out systemTemp : Temperature;
		out thermalStatus : Boolean;
	}
	
	action def PlanetaryDrillingOperation {
		doc /* Complete autonomous drilling sequence from deployment to sample caching */
		
		in targetDepth : DrillDepth;
		in targetSampleMass : SampleMass;
		in drillTorque : DrillTorque;
		in drillSpeed : DrillSpeed;
		out operationSuccess : Boolean;
		out totalSampleMass : SampleMass;
		out finalDepth : DrillDepth;
		
		private attribute currentDepth : DrillDepth := 0.0[SI::m];
		private attribute accumulatedSample : SampleMass := 0.0[SI::g];
		private attribute thermalOK := true;
		
		first start;
		
		then action checkThermals : MonitorThermals {
			out systemTemp : Temperature;
			out thermalStatus : Boolean;
		}
		
		then decide;
			if checkThermals.thermalStatus then deployDrill;
			if not checkThermals.thermalStatus then abortOperation;
		
		action deployDrill : DeployDrill {
			in deploymentAngle = 90.0;
			out deploymentSuccess : Boolean;
		}
		
		then decide;
			if deployDrill.deploymentSuccess then positionDrill;
			if not deployDrill.deploymentSuccess then abortOperation;
		
		action positionDrill : PositionDrill {
			in targetDepth = PlanetaryDrillingOperation::targetDepth;
			out positionAchieved : Boolean;
			out actualPosition : ISQ::LengthValue;
		}
		
		then decide;
			if positionDrill.positionAchieved then executeDrilling;
			if not positionDrill.positionAchieved then abortOperation;
		
		action executeDrilling : ExecuteDrilling {
			in drillDepth = PlanetaryDrillingOperation::targetDepth;
			in drillTorque = PlanetaryDrillingOperation::drillTorque;
			in drillSpeed = PlanetaryDrillingOperation::drillSpeed;
			out achievedDepth : DrillDepth;
			out sampleMass : SampleMass;
			out drillSuccess : Boolean;
		}
		
		then assign currentDepth := executeDrilling.achievedDepth;
		then assign accumulatedSample := executeDrilling.sampleMass;
		
		then action monitorDuringDrill : MonitorThermals {
			out systemTemp : Temperature;
			out thermalStatus : Boolean;
		}
		
		then assign thermalOK := monitorDuringDrill.thermalStatus;
		
		then decide;
			if executeDrilling.drillSuccess and thermalOK then extractSample;
			if not executeDrilling.drillSuccess or not thermalOK then retractDrill;
		
		action extractSample : ExtractSample {
			out extractedMass : SampleMass;
			out extractionSuccess : Boolean;
		}
		
		then decide;
			if extractSample.extractionSuccess and extractSample.extractedMass >= targetSampleMass 
				then retractDrill;
			if not extractSample.extractionSuccess or extractSample.extractedMass < targetSampleMass 
				then retractDrill;
		
		action retractDrill : RetractDrill {
			out retractionSuccess : Boolean;
		}
		
		then decide;
			if retractDrill.retractionSuccess and extractSample.extractionSuccess then transferToCache;
			if not retractDrill.retractionSuccess or not extractSample.extractionSuccess then abortOperation;
		
		action transferToCache : TransferToCache {
			in sampleMass = extractSample.extractedMass;
			in containerID = 1;
			out transferSuccess : Boolean;
		}
		
		then decide;
			if transferToCache.transferSuccess then completeOperation;
			if not transferToCache.transferSuccess then abortOperation;
		
		action completeOperation {
			then assign operationSuccess := true;
			then assign totalSampleMass := extractSample.extractedMass;
			then assign finalDepth := executeDrilling.achievedDepth;
		}
		then done;
		
		action abortOperation {
			then assign operationSuccess := false;
			then assign totalSampleMass := 0.0[SI::g];
			then assign finalDepth := currentDepth;
		}
		then done;
	}
	
	part drillingSystem : PlanetaryDrillingSystem {
		doc /* Honeybee Robotics autonomous planetary drilling system for subsurface sample acquisition and preservation */
		
		attribute minDrillDepth : DrillDepth = 5.0[SI::cm];
		attribute maxDrillDepth : DrillDepth = 100.0[SI::cm];
		attribute minSampleMass : SampleMass = 30.0[SI::g];
		attribute minOperatingTemp : Temperature = 223.15[SI::K];
		attribute maxOperatingTemp : Temperature = 343.15[SI::K];
		attribute peakPowerConsumption : ISQ::PowerValue = 150.0[SI::W];
		attribute sampleCondition : SampleCondition = SampleCondition::pristine;
		
		perform action drillingOperation[*] ordered : PlanetaryDrillingOperation;
		
		part powerDistribution : PowerDistributionUnit {
			attribute inputVoltage = 28.0[SI::V];
			attribute outputVoltage = 28.0[SI::V];
			attribute totalCurrent = 5.4[SI::A];
		}
		
		part controller : ControllerUnit {
			perform drillingOperation.checkThermals;
			perform drillingOperation.monitorDuringDrill;
		}
		
		part drillMotor : DrillMotorAssembly {
			attribute motorTorque = 20.0[SI::N*SI::m];
			attribute motorSpeed = 100.0[SI::rad/SI::s];
			attribute powerDraw = 120.0[SI::W];
			
			perform drillingOperation.executeDrilling;
		}
		
		part drillBit : DrillBitAssembly {
			attribute currentDepth = 0.0[SI::m];
			attribute bitDiameter = 2.5[SI::cm];
			attribute wearLevel = 0.0;
			
			perform drillingOperation.extractSample;
		}
		
		part actuator : LinearActuator {
			attribute position = 0.0[SI::m];
			attribute maxStroke = 1.2[SI::m];
			attribute force = 500.0[SI::N];
			
			perform drillingOperation.deployDrill;
			perform drillingOperation.positionDrill;
			perform drillingOperation.retractDrill;
		}
		
		part sampleCache : SampleCacheSystem {
			attribute storedMass = 0.0[SI::g];
			attribute numberOfContainers = 10;
			attribute sealIntegrity = 1.0;
			
			perform drillingOperation.transferToCache;
		}
		
		part thermalManagement : ThermalManagementSystem {
			attribute currentTemp = 193.15[SI::K];
			attribute targetTemp = 253.15[SI::K];
			attribute heaterPower = 30.0[SI::W];
		}
		
		connect powerDistribution.drillPowerOut to drillMotor.powerIn;
		connect powerDistribution.actuatorPowerOut to actuator.powerIn;
		connect powerDistribution.thermalPowerOut to thermalManagement.powerIn;
		
		connect controller.drillControl to drillMotor.controlIn;
		connect controller.actuatorControl to actuator.positionControl;
		connect controller.thermalControl to thermalManagement.heaterControl;
		
		connect drillMotor.thermalOut to thermalManagement.thermalSensors;
		connect drillBit.sampleOutput to sampleCache.sampleIn;
	}
}
