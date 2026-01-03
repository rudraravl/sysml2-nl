package 'Crankshaft Position Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def AngleValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit;
	}
	
	attribute def AngularVelocityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularVelocityUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def AngleUnit :> DerivedUnit;
	attribute def AngularVelocityUnit :> DerivedUnit;
	attribute def VoltageUnit :> DerivedUnit;
	attribute def FrequencyUnit :> DerivedUnit;
	
	item def ToothWheelPattern {
		attribute totalTeeth : Integer;
		attribute missingTeeth : Integer;
		attribute toothAngleSpacing : AngleValue;
	}
	
	item def RawSensorVoltage {
		attribute voltage : VoltageValue;
		attribute timestamp : TimeValue;
	}
	
	item def CrankshaftPositionData {
		attribute angle : AngleValue;
		attribute angularVelocity : AngularVelocityValue;
		attribute timestamp : TimeValue;
		attribute synchronized : Boolean;
	}
	
	port def SensorOutputPort {
		out item rawVoltage : RawSensorVoltage;
	}
	
	port def ProcessedDataPort {
		out item positionData : CrankshaftPositionData;
	}
	
	port def PowerPort {
		in item supplyVoltage : VoltageValue;
	}
	
	part def Crankshaft {
		attribute currentAngle : AngleValue;
		attribute rotationalSpeed : AngularVelocityValue;
		part toothWheel : ToothWheel {
			attribute :>> pattern : ToothWheelPattern {
				attribute :>> totalTeeth = 60;
				attribute :>> missingTeeth = 2;
			}
		}
	}
	
	part def ToothWheel {
		attribute pattern : ToothWheelPattern;
		attribute currentRotationAngle : AngleValue;
	}
	
	part def HallEffectElement {
		in attribute magneticFluxDensity : Real;
		out attribute outputVoltage : VoltageValue;
		attribute sensitivity : Real;
	}
	
	part def SignalAmplifier {
		in attribute inputVoltage : VoltageValue;
		out attribute amplifiedVoltage : VoltageValue;
		attribute gain : Real default 20.0;
	}
	
	part def SignalFilter {
		in attribute rawVoltage : VoltageValue;
		out attribute filteredVoltage : VoltageValue;
		attribute cutoffFrequency : FrequencyValue;
	}
	
	connection def SignalFlow {
		end source;
		end target;
	}
	
	part def CrankshaftPositionSensor {
		attribute sensorType : String default "Hall Effect";
		attribute operatingVoltageMin : VoltageValue;
		attribute operatingVoltageMax : VoltageValue;
		attribute measurementResolution : AngleValue;
		
		port powerSupply : PowerPort;
		port sensorOutput : SensorOutputPort;
		
		part sensingElement : HallEffectElement {
			in attribute :>> magneticFluxDensity;
			out attribute :>> outputVoltage;
			attribute :>> sensitivity = 5.0;
		}
		
		part amplifier : SignalAmplifier {
			in attribute :>> inputVoltage;
			out attribute :>> amplifiedVoltage;
			attribute :>> gain = 20.0;
		}
		
		part filterStage : SignalFilter {
			in attribute :>> rawVoltage;
			out attribute :>> filteredVoltage;
		}
		
		connection : SignalFlow connect sensingElement.outputVoltage to amplifier.inputVoltage;
		connection : SignalFlow connect amplifier.amplifiedVoltage to filterStage.rawVoltage;
	}
	
	action def DetectToothTransition {
		in item inputVoltage : RawSensorVoltage;
		in item thresholdVoltage : VoltageValue;
		out item transitionDetected : Boolean;
	}
	
	action def CountTeeth {
		in item transitionDetected : Boolean;
		in item currentCount : Integer;
		out item updatedCount : Integer;
	}
	
	action def IdentifyGap {
		in item toothCount : Integer;
		in item timeSinceLastTooth : TimeValue;
		in item pattern : ToothWheelPattern;
		out item gapDetected : Boolean;
		out item referenceEstablished : Boolean;
	}
	
	action def ComputeAngle {
		in item toothCount : Integer;
		in item pattern : ToothWheelPattern;
		in item synchronized : Boolean;
		out item angle : AngleValue;
	}
	
	action def ComputeAngularVelocity {
		in item timeBetweenTeeth : TimeValue;
		in item toothSpacing : AngleValue;
		out item angularVelocity : AngularVelocityValue;
	}
	
	action def ProcessSensorSignal {
		in item rawVoltage : RawSensorVoltage;
		in item wheelPattern : ToothWheelPattern;
		out item positionData : CrankshaftPositionData;
		
		action detectTransition : DetectToothTransition {
			in item :>> inputVoltage = rawVoltage;
			in item :>> thresholdVoltage;
			out item :>> transitionDetected;
		}
		
		then decision checkTransition;
		accept if detectTransition.transitionDetected;
		
		then action countTeeth : CountTeeth {
			in item :>> transitionDetected;
			in item :>> currentCount;
			out item :>> updatedCount;
		}
		
		then action identifyGap : IdentifyGap {
			in item :>> toothCount;
			in item :>> timeSinceLastTooth;
			in item :>> pattern = wheelPattern;
			out item :>> gapDetected;
			out item :>> referenceEstablished;
		}
		
		then fork;
		
		then action computeAngle : ComputeAngle {
			in item :>> toothCount;
			in item :>> pattern = wheelPattern;
			in item :>> synchronized;
			out item :>> angle;
		}
		
		then joinNode;
		
		then action computeVelocity : ComputeAngularVelocity {
			in item :>> timeBetweenTeeth;
			in item :>> toothSpacing;
			out item :>> angularVelocity;
		}
		
		then joinNode;
		
		join joinNode;
		
		then action assembleData {
			in item angle : AngleValue;
			in item velocity : AngularVelocityValue;
			in item sync : Boolean;
			out item data : CrankshaftPositionData;
		}
		
		flow from computeAngle.angle to assembleData.angle;
		flow from computeVelocity.angularVelocity to assembleData.velocity;
		flow from identifyGap.referenceEstablished to assembleData.sync;
		bind assembleData.data = positionData;
	}
	
	part def SignalProcessor {
		in attribute rawSignal : RawSensorVoltage;
		out attribute processedData : CrankshaftPositionData;
		
		attribute toothCounter : Integer default 0;
		attribute lastToothTimestamp : TimeValue;
		attribute isSynchronized : Boolean default false;
		attribute referenceAngle : AngleValue;
	}
	
	state def SensorOperationalStates {
		entry; then powerOff;
		
		state powerOff {
			entry assign status = "Power Off";
		}
		
		transition powerOn
			first powerOff
			accept PowerApplied
			then initializing;
		
		state initializing {
			entry assign status = "Initializing";
			do action performSelfTest;
		}
		
		transition initComplete
			first initializing
			accept SelfTestPassed
			then synchronizing;
		
		state synchronizing {
			entry assign status = "Synchronizing";
			entry assign synchronized = false;
			do action searchForGap;
		}
		
		transition syncAchieved
			first synchronizing
			accept GapDetected
			then operational;
		
		state operational {
			entry assign status = "Operational";
			entry assign synchronized = true;
			
			state measuring {
				entry assign measurementActive = true;
				do action continuousMeasurement : ProcessSensorSignal;
			}
		}
		
		transition toFault
			first operational
			accept SensorFault
			then fault;
		
		state fault {
			entry assign status = "Fault";
			entry assign synchronized = false;
		}
		
		transition faultRecovery
			first fault
			accept FaultCleared
			then synchronizing;
		
		transition shutdown
			first operational
			accept PowerRemoved
			then powerOff;
	}
	
	part def CrankshaftPositionSensingUnit {
		attribute unitSerialNumber : String;
		attribute calibrationDate : String;
		attribute firmwareVersion : String;
		
		port powerInput : PowerPort;
		port dataOutput : ProcessedDataPort;
		
		ref part monitoredCrankshaft : Crankshaft;
		
		part sensor : CrankshaftPositionSensor {
			attribute :>> sensorType = "Hall Effect";
		}
		
		part processor : SignalProcessor;
		
		connection : SignalFlow connect powerInput to sensor.powerSupply;
		
		perform action measurePosition : ProcessSensorSignal {
			in item :>> rawVoltage;
			in item :>> wheelPattern = monitoredCrankshaft.toothWheel.pattern;
			out item :>> positionData;
		}
		
		exhibit state operationalState : SensorOperationalStates;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure crankshaft angular position with accuracy of +/- 1.0 degree. */
		
		subject unit : CrankshaftPositionSensingUnit;
	}
	
	requirement def SynchronizationRequirement {
		doc /* The sensing unit shall achieve synchronization within 2 complete crankshaft revolutions. */
		
		subject unit : CrankshaftPositionSensingUnit;
	}
	
	requirement def OperatingVoltageRequirement {
		doc /* The sensing unit shall operate within supply voltage range of 4.5V to 5.5V. */
		
		subject unit : CrankshaftPositionSensingUnit;
	}
	
	requirement def UpdateRateRequirement {
		doc /* The sensing unit shall provide position updates at minimum rate of 1 kHz at 6000 RPM. */
		
		subject unit : CrankshaftPositionSensingUnit;
	}
	
	part sensingUnitInstance : CrankshaftPositionSensingUnit {
		attribute :>> unitSerialNumber = "CPS-2025-001";
		attribute :>> calibrationDate = "2025-01-15";
		attribute :>> firmwareVersion = "v2.3.1";
		
		part engineCrankshaft : Crankshaft :>> monitoredCrankshaft;
		
		satisfy accuracyReq : MeasurementAccuracyRequirement {
			subject unit = sensingUnitInstance;
		}
		
		satisfy syncReq : SynchronizationRequirement {
			subject unit = sensingUnitInstance;
		}
		
		satisfy voltageReq : OperatingVoltageRequirement {
			subject unit = sensingUnitInstance;
		}
		
		satisfy updateReq : UpdateRateRequirement {
			subject unit = sensingUnitInstance;
		}
	}
}
