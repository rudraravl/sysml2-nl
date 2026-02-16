package HospitalBedSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BedAngle :> Real;
	attribute def BedHeight :> LengthValue;
	attribute def PatientMass :> MassValue;
	attribute def PressureReading :> PressureValue;
	attribute def MotorTorque :> TorqueValue;
	attribute def ElectricPower :> PowerValue;
	
	enum def AlertType {
		none;
		patientExit;
		pressureUlcerRisk;
		overweight;
		positionLimit;
	}
	
	attribute def BedConfiguration {
		attribute headAngle : BedAngle;
		attribute footAngle : BedAngle;
		attribute overallHeight : BedHeight;
	}
	
	port def ControlPort {
		in attribute desiredConfiguration : BedConfiguration;
		out attribute currentConfiguration : BedConfiguration;
		out attribute alert : AlertType;
	}
	
	port def PowerPort {
		in attribute powerSupply : ElectricPower;
	}
	
	port def SensorDataPort {
		out attribute patientWeight : PatientMass;
		out attribute pressureMap : PressureReading[*];
		out attribute occupancyStatus : Boolean;
	}
	
	item def Patient {
		attribute weight : PatientMass;
		attribute position : String;
	}
	
	part def PressureSensor {
		attribute sensorID : Integer;
		attribute location : String;
		out attribute pressure : PressureReading;
	}
	
	part def LoadCell {
		attribute maxCapacity : PatientMass;
		out attribute measuredWeight : PatientMass;
	}
	
	part def ElectricMotor {
		in attribute targetAngle : BedAngle;
		in attribute powerInput : ElectricPower;
		out attribute currentAngle : BedAngle;
		out attribute outputTorque : MotorTorque;
		attribute maxTorque : MotorTorque;
	}
	
	part def LinearActuator {
		in attribute targetHeight : BedHeight;
		in attribute powerInput : ElectricPower;
		out attribute currentHeight : BedHeight;
		attribute minHeight : BedHeight;
		attribute maxHeight : BedHeight;
		attribute maxLoad : PatientMass;
	}
	
	part def ControlUnit {
		in attribute sensorInputs : SensorDataPort;
		in attribute userCommands : BedConfiguration;
		out attribute motorCommands : BedConfiguration;
		out attribute alertOutput : AlertType;
		
		perform action processControl : ProcessControlLogic;
	}
	
	part def MattressSurface {
		part pressureSensors : PressureSensor[16];
		attribute totalArea : AreaValue;
		attribute firmness : Real;
	}
	
	part def BedFrame {
		part headSection {
			attribute sectionAngle : BedAngle;
			part headMotor : ElectricMotor;
		}
		part footSection {
			attribute sectionAngle : BedAngle;
			part footMotor : ElectricMotor;
		}
		part heightSystem : LinearActuator;
		attribute structuralCapacity : PatientMass;
	}
	
	action def MonitorPatientStatus {
		in attribute pressureData : PressureReading[*];
		in attribute weight : PatientMass;
		in attribute occupancy : Boolean;
		out attribute riskLevel : AlertType;
		out attribute pressureDistribution : Real[*];
	}
	
	action def AdjustBedPosition {
		in attribute targetConfig : BedConfiguration;
		in attribute currentConfig : BedConfiguration;
		in attribute safetyLimits : BedConfiguration;
		out attribute headCommand : BedAngle;
		out attribute footCommand : BedAngle;
		out attribute heightCommand : BedHeight;
		out attribute withinLimits : Boolean;
	}
	
	action def DetectPatientExit {
		in attribute previousWeight : PatientMass;
		in attribute currentWeight : PatientMass;
		in attribute pressurePattern : Real[*];
		in attribute threshold : PatientMass;
		out attribute exitDetected : Boolean;
	}
	
	action def ProcessControlLogic {
		in attribute sensorData : SensorDataPort;
		in attribute commandedConfig : BedConfiguration;
		out attribute controlSignals : BedConfiguration;
		out attribute systemAlert : AlertType;
		
		first start;
		then merge operationLoop;
		
		action monitorStatus : MonitorPatientStatus {
			in pressureData;
			in weight;
			in occupancy;
			out riskLevel;
			out pressureDistribution;
		}
		
		then action checkExit : DetectPatientExit {
			in previousWeight;
			in currentWeight;
			in pressurePattern = monitorStatus.pressureDistribution;
			in threshold = 5.0;
			out exitDetected;
		}
		
		then action adjustPosition : AdjustBedPosition {
			in targetConfig = commandedConfig;
			in currentConfig;
			in safetyLimits;
			out headCommand;
			out footCommand;
			out heightCommand;
			out withinLimits;
		}
		
		then decide;
			if checkExit.exitDetected then raiseExitAlert;
			if adjustPosition.withinLimits then applyCommands;
		
		action raiseExitAlert {
			then assign systemAlert := AlertType::patientExit;
		}
		then operationLoop;
		
		action applyCommands {
			then assign systemAlert := AlertType::none;
		}
		then operationLoop;
	}
	
	action def ProvidePatientSupport {
		doc /* 
			Primary high-level function: Provide safe, adjustable support 
			for a patient by continuously monitoring their condition and 
			responding to caregiver positioning commands while maintaining 
			safety and comfort.
		*/
		
		in attribute caregiverInput : BedConfiguration;
		in attribute patientPresent : Boolean;
		out attribute supportProvided : Boolean;
		out attribute safetyMaintained : Boolean;
		
		first start;
		then merge continuousSupport;
		
		action acquireSensorData {
			out attribute weightData : PatientMass;
			out attribute pressureData : PressureReading[*];
			out attribute occupancyData : Boolean;
		}
		
		then action evaluateSafety {
			in attribute sensorWeight = acquireSensorData.weightData;
			in attribute sensorPressure = acquireSensorData.pressureData;
			in attribute sensorOccupancy = acquireSensorData.occupancyData;
			out attribute safeToAdjust : Boolean;
			out attribute alertCondition : AlertType;
		}
		
		then decide;
			if evaluateSafety.safeToAdjust and patientPresent then adjustForComfort;
			if not evaluateSafety.safeToAdjust then maintainPosition;
		
		action adjustForComfort {
			in attribute requestedPosition = caregiverInput;
			then action computeMotion {
				in attribute target = requestedPosition;
				out attribute headMotion : BedAngle;
				out attribute footMotion : BedAngle;
				out attribute heightMotion : BedHeight;
			}
			then action executeMotion {
				in attribute headTarget = computeMotion.headMotion;
				in attribute footTarget = computeMotion.footMotion;
				in attribute heightTarget = computeMotion.heightMotion;
			}
			then assign supportProvided := true;
			then assign safetyMaintained := true;
		}
		then continuousSupport;
		
		action maintainPosition {
			then assign supportProvided := true;
			then assign safetyMaintained := false;
		}
		then continuousSupport;
	}
	
	part def HospitalBed {
		doc /* 
			A hospital bed system that provides adjustable patient positioning,
			continuous safety monitoring, and pressure management to support
			patient care and prevent complications.
		*/
		
		attribute maxPatientCapacity : PatientMass;
		attribute bedID : String;
		
		port controlInterface : ControlPort;
		port powerInterface : PowerPort;
		port sensorInterface : SensorDataPort;
		
		part mattress : MattressSurface {
			attribute :>> totalArea = 2.0;
			attribute :>> firmness = 6.5;
		}
		
		part frame : BedFrame {
			attribute :>> structuralCapacity = 300.0;
		}
		
		part loadCells : LoadCell[4] {
			attribute :>> maxCapacity = 100.0;
		}
		
		part controller : ControlUnit;
		
		perform action provideSupport : ProvidePatientSupport {
			in caregiverInput = controlInterface.desiredConfiguration;
			in patientPresent;
			out supportProvided;
			out safetyMaintained;
		}
		
		connection pressureMonitoring connect 
			mattress.pressureSensors.pressure to sensorInterface.pressureMap;
		
		connection weightMonitoring connect 
			loadCells.measuredWeight to sensorInterface.patientWeight;
		
		connection alertOutput connect 
			controller.alertOutput to controlInterface.alert;
		
		connection powerToHead connect 
			powerInterface.powerSupply to frame.headSection.headMotor.powerInput;
		
		connection powerToFoot connect 
			powerInterface.powerSupply to frame.footSection.footMotor.powerInput;
		
		connection powerToHeight connect 
			powerInterface.powerSupply to frame.heightSystem.powerInput;
	}
	
	part clinicalBed : HospitalBed {
		attribute :>> maxPatientCapacity = 250.0;
		attribute :>> bedID = "ICU-BED-042";
		
		part :>> frame {
			part :>> headSection {
				part :>> headMotor {
					attribute :>> maxTorque = 50.0;
				}
			}
			part :>> footSection {
				part :>> footMotor {
					attribute :>> maxTorque = 40.0;
				}
			}
			part :>> heightSystem {
				attribute :>> minHeight = 0.35;
				attribute :>> maxHeight = 0.85;
				attribute :>> maxLoad = 300.0;
			}
		}
	}
	
	requirement def PatientSafetyRequirement {
		doc /* Bed must maintain patient safety during all operations */
		subject bed : HospitalBed;
		require constraint {
			bed.provideSupport.safetyMaintained
		}
	}
	
	requirement def WeightLimitRequirement {
		doc /* Bed must not exceed maximum patient weight capacity */
		subject bed : HospitalBed;
		require constraint {
			bed.sensorInterface.patientWeight <= bed.maxPatientCapacity
		}
	}
	
	requirement def PositionRangeRequirement {
		doc /* Bed sections must operate within safe angular ranges */
		subject bed : HospitalBed;
		require constraint {
			bed.frame.headSection.sectionAngle >= 0.0 and
			bed.frame.headSection.sectionAngle <= 70.0 and
			bed.frame.footSection.sectionAngle >= -15.0 and
			bed.frame.footSection.sectionAngle <= 30.0
		}
	}
	
	requirement def HeightRangeRequirement {
		doc /* Bed height must remain within operational limits */
		subject bed : HospitalBed;
		require constraint {
			bed.frame.heightSystem.currentHeight >= bed.frame.heightSystem.minHeight and
			bed.frame.heightSystem.currentHeight <= bed.frame.heightSystem.maxHeight
		}
	}
	
	requirement bedSystemRequirements {
		doc /* Comprehensive requirements for hospital bed system */
		
		subject bed : HospitalBed;
		
		require safetyReq : PatientSafetyRequirement {
			subject bed = bedSystemRequirements::bed;
		}
		
		require weightReq : WeightLimitRequirement {
			subject bed = bedSystemRequirements::bed;
		}
		
		require positionReq : PositionRangeRequirement {
			subject bed = bedSystemRequirements::bed;
		}
		
		require heightReq : HeightRangeRequirement {
			subject bed = bedSystemRequirements::bed;
		}
	}
}
