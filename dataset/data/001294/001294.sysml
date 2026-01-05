package TransmissionControlUnitSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	alias Speed for ISQ::SpeedValue;
	alias Torque for ISQ::TorqueValue;
	alias Time for ISQ::TimeValue;
	alias Pressure for ISQ::PressureValue;
	
	attribute def AngularSpeedValue :> ISQ::QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularSpeedUnit;
	}
	
	attribute def AngularSpeedUnit :> ISQ::DimensionOneUnit;
	
	attribute def ThrottlePosition {
		attribute percentage : Real;
	}
	
	attribute def DriveMode;
	
	item def SensorData {
		attribute vehicleSpeed : Speed;
		attribute engineSpeed : Real;
		attribute throttlePosition : Real;
		attribute currentGear : Integer;
		attribute transmissionTemp : Real;
	}
	
	item def GearCommand {
		attribute targetGear : Integer;
		attribute clutchPressure : Pressure;
		attribute shiftDuration : Time;
	}
	
	item def ShiftStrategy {
		attribute upshiftSpeed : Speed;
		attribute downshiftSpeed : Speed;
		attribute optimalRPM : Real;
	}
	
	port def SensorInputPort {
		in speed : Speed;
		in rpm : Real;
		in throttle : Real;
		in gear : Integer;
	}
	
	port def ActuatorOutputPort {
		out gearCmd : GearCommand;
		out clutchPressure : Pressure;
	}
	
	port def StatusPort {
		out currentGear : Integer;
		out shiftInProgress : Boolean;
	}
	
	part def VehicleSpeedSensor {
		out port speedOut {
			out speed : Speed;
		}
		attribute measurementAccuracy : Real = 0.98;
	}
	
	part def EngineSpeedSensor {
		out port rpmOut {
			out rpm : Real;
		}
		attribute updateFrequency : Real = 100.0;
	}
	
	part def ThrottlePositionSensor {
		out port throttleOut {
			out throttle : Real;
		}
	}
	
	part def GearPositionSensor {
		out port gearOut {
			out gear : Integer;
		}
	}
	
	part def TransmissionFluidTempSensor {
		out port tempOut {
			out temperature : Real;
		}
	}
	
	part def HydraulicActuator {
		in port cmdIn {
			in gearCmd : GearCommand;
		}
		out port pressureOut {
			out pressure : Pressure;
		}
		attribute responseTime : Time = 0.05[s];
	}
	
	part def ClutchActuator {
		in port clutchIn {
			in clutchPressure : Pressure;
		}
		attribute engagementRate : Real;
	}
	
	action def ReadSensorInputs {
		out sensorData : SensorData;
	}
	
	action def AnalyzeDrivingConditions {
		in sensorData : SensorData;
		in driveMode : DriveMode;
		out optimalGear : Integer;
		out shiftRequired : Boolean;
	}
	
	action def CalculateShiftParameters {
		in currentGear : Integer;
		in targetGear : Integer;
		in engineSpeed : Real;
		out gearCommand : GearCommand;
	}
	
	action def ExecuteGearShift {
		in gearCommand : GearCommand;
	}
	
	action def MonitorShiftProgress {
		in targetGear : Integer;
		in currentGear : Integer;
		out shiftComplete : Boolean;
	}
	
	action def ControlTransmissionOperation {
		in vehicleSpeed : Speed;
		in engineSpeed : Real;
		in throttlePosition : Real;
		in driveMode : DriveMode;
		out gearCommand : GearCommand;
		
		first start;
		then merge continuousOperation;
		
		then action readSensors : ReadSensorInputs {
			out sensorData : SensorData;
		}
		
		then action analyzeConditions : AnalyzeDrivingConditions {
			in sensorData = readSensors.sensorData;
			in driveMode = ControlTransmissionOperation::driveMode;
			out optimalGear : Integer;
			out shiftRequired : Boolean;
		}
		
		then decide;
			if analyzeConditions.shiftRequired then calculateShift;
			if !analyzeConditions.shiftRequired then continuousOperation;
		
		action calculateShift : CalculateShiftParameters {
			in currentGear : Integer;
			in targetGear = analyzeConditions.optimalGear;
			in engineSpeed = ControlTransmissionOperation::engineSpeed;
			out gearCommand : GearCommand;
		}
		
		then action executeShift : ExecuteGearShift {
			in gearCommand = calculateShift.gearCommand;
		}
		
		then action monitorShift : MonitorShiftProgress {
			in targetGear = analyzeConditions.optimalGear;
			in currentGear : Integer;
			out shiftComplete : Boolean;
		}
		
		then continuousOperation;
		then done;
	}
	
	part def TransmissionControlUnit {
		in port sensorInput : SensorInputPort;
		out port actuatorOutput : ActuatorOutputPort;
		out port status : StatusPort;
		
		attribute currentGear : Integer = 1;
		attribute targetGear : Integer = 1;
		attribute shiftInProgress : Boolean = false;
		attribute driveMode : DriveMode;
		
		action controlLogic : ControlTransmissionOperation {
			in vehicleSpeed : Speed;
			in engineSpeed : Real;
			in throttlePosition : Real;
			in driveMode : DriveMode;
			out gearCommand : GearCommand;
		}
	}
	
	part def TransmissionAssembly {
		in port controlInput {
			in gearCmd : GearCommand;
			in clutchPressure : Pressure;
		}
		out port transmissionStatus {
			out currentGear : Integer;
			out gearRatio : Real;
		}
		
		part hydraulicSystem : HydraulicActuator;
		part clutchSystem : ClutchActuator;
		
		attribute currentGearRatio : Real;
		attribute numberOfGears : Integer = 8;
	}
	
	part def Engine {
		attribute rpm : Real;
		attribute torque : Torque;
		attribute maxRPM : Real = 6500.0;
	}
	
	part def Vehicle {
		attribute speed : Speed;
		attribute mass : ISQ::MassValue;
	}
	
	part powertrainSystem {
		part engine : Engine {
			attribute :>> rpm;
			attribute :>> torque;
		}
		
		part vehicle : Vehicle {
			attribute :>> speed;
			attribute :>> mass = 1800.0[kg];
		}
		
		part speedSensor : VehicleSpeedSensor;
		part rpmSensor : EngineSpeedSensor;
		part throttleSensor : ThrottlePositionSensor;
		part gearSensor : GearPositionSensor;
		part tempSensor : TransmissionFluidTempSensor;
		
		part tcu : TransmissionControlUnit {
			attribute :>> currentGear;
			attribute :>> targetGear;
			attribute :>> shiftInProgress;
		}
		
		part transmission : TransmissionAssembly {
			attribute :>> currentGearRatio;
			attribute :>> numberOfGears;
		}
		
		connect speedSensor.speedOut.speed to tcu.sensorInput.speed;
		connect rpmSensor.rpmOut.rpm to tcu.sensorInput.rpm;
		connect throttleSensor.throttleOut.throttle to tcu.sensorInput.throttle;
		connect gearSensor.gearOut.gear to tcu.sensorInput.gear;
		
		connect tcu.actuatorOutput.gearCmd to transmission.controlInput.gearCmd;
		connect tcu.actuatorOutput.clutchPressure to transmission.controlInput.clutchPressure;
		
		connect transmission.transmissionStatus.currentGear to tcu.status.currentGear;
	}
	
	requirement def OptimalGearSelectionRequirement {
		doc /* The TCU shall determine and command the optimal gear ratio based on 
		     * real-time analysis of vehicle speed, engine RPM, throttle position, 
		     * and selected drive mode to maximize fuel efficiency and performance. */
		
		attribute requirementId : String = "REQ-TCU-001";
		
		require continuousAnalysis {
			doc /* The system shall analyze driving conditions at minimum 100 Hz frequency. */
		}
		
		require optimalSelection {
			doc /* Gear selection shall optimize for fuel efficiency within performance constraints. */
		}
	}
	
	requirement def SmoothShiftExecutionRequirement {
		doc /* The TCU shall execute gear shifts with precise clutch timing and hydraulic 
		     * pressure control to minimize torque interruption and ensure smooth transitions. */
		
		attribute requirementId : String = "REQ-TCU-002";
		attribute maxShiftTime : Time = 0.8[s];
		attribute maxTorqueInterruption : Real = 0.15;
		
		require timingPrecision {
			doc /* Clutch engagement timing shall be controlled within 10 milliseconds accuracy. */
		}
		
		require pressureControl {
			doc /* Hydraulic pressure shall be modulated to match engine torque characteristics. */
		}
	}
	
	requirement def SystemResponseRequirement {
		doc /* The TCU shall respond to changes in driving conditions and driver inputs 
		     * within specified time limits to ensure responsive vehicle behavior. */
		
		attribute requirementId : String = "REQ-TCU-003";
		attribute maxResponseTime : Time = 0.05[s];
		
		require rapidDetection {
			doc /* Changes in throttle position shall be detected within 20 milliseconds. */
		}
		
		require commandExecution {
			doc /* Gear shift commands shall be issued within 50 milliseconds of decision. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The TCU shall ensure safe transmission operation under all conditions 
		     * including fault detection and fail-safe modes. */
		
		attribute requirementId : String = "REQ-TCU-004";
		
		require temperatureMonitoring {
			doc /* Transmission fluid temperature shall be continuously monitored. */
		}
		
		require faultDetection {
			doc /* System faults shall be detected and appropriate fail-safe actions initiated. */
		}
	}
	
	requirement tcuSystemRequirement {
		subject powertrainSystem.tcu;
		
		require optimalGearReq : OptimalGearSelectionRequirement;
		require smoothShiftReq : SmoothShiftExecutionRequirement;
		require responseReq : SystemResponseRequirement;
		require safetyReq : SafetyRequirement;
		
		assume constraint sensorAccuracy {
			doc /* Vehicle speed sensor provides readings within 2% accuracy. */
		}
		
		assume constraint engineRPMAccuracy {
			doc /* Engine RPM sensor updates at minimum 100 Hz with 1% accuracy. */
		}
		
		assume constraint hydraulicResponse {
			doc /* Hydraulic actuators respond within 50 milliseconds. */
		}
	}
	
	satisfy tcuSystemRequirement.optimalGearReq by powertrainSystem.tcu;
	satisfy tcuSystemRequirement.smoothShiftReq by powertrainSystem.tcu;
	satisfy tcuSystemRequirement.responseReq by powertrainSystem.tcu;
	satisfy tcuSystemRequirement.safetyReq by powertrainSystem.tcu;
}
