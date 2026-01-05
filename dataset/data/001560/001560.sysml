package RoboticTechVestSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PostureAngle :> Real;
	attribute def SupportLevel :> Real;
	attribute def BatteryPercentage :> Real;
	
	item def PostureData {
		attribute spineAngle : ISQ::AngleValue;
		attribute shoulderAlignment : ISQ::AngleValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def SupportCommand {
		attribute targetJoint : String;
		attribute assistanceTorque : ISQ::TorqueValue;
		attribute duration : ISQ::TimeValue;
	}
	
	item def HapticFeedback {
		attribute intensity : Real;
		attribute location : String;
		attribute pattern : String;
	}
	
	item def BatteryStatus {
		attribute chargeLevel : BatteryPercentage;
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def SensorDataPort {
		out item postureReading : PostureData;
	}
	
	port def ActuatorCommandPort {
		in item supportCmd : SupportCommand;
	}
	
	port def HapticPort {
		out item feedback : HapticFeedback;
	}
	
	port def PowerPort {
		out item batteryInfo : BatteryStatus;
	}
	
	part def PostureSensor {
		port dataOutput : SensorDataPort;
		attribute sensorAccuracy : ISQ::AngleValue;
		attribute samplingRate : ISQ::FrequencyValue;
	}
	
	part def ExoskeletonActuator {
		port commandInput : ActuatorCommandPort;
		attribute maxTorque : ISQ::TorqueValue;
		attribute responseTime : ISQ::TimeValue;
		attribute jointLocation : String;
	}
	
	part def HapticFeedbackModule {
		port feedbackOutput : HapticPort;
		attribute vibrationFrequency : ISQ::FrequencyValue;
		attribute maxIntensity : Real;
	}
	
	part def ControlProcessor {
		port sensorInput : ~SensorDataPort;
		port actuatorOutput : ~ActuatorCommandPort;
		port hapticControl : ~HapticPort;
		port powerMonitor : ~PowerPort;
		
		attribute processingFrequency : ISQ::FrequencyValue;
		attribute controlAlgorithm : String;
	}
	
	part def BatteryModule {
		port powerStatus : PowerPort;
		attribute capacity : ISQ::EnergyValue;
		attribute nominalVoltage : ISQ::ElectricPotentialValue;
		attribute currentCharge : BatteryPercentage;
	}
	
	part def RoboticTechVest {
		part spineSensors : PostureSensor[5] {
			attribute :>> sensorAccuracy = 0.5 [SI::deg];
			attribute :>> samplingRate = 100.0 [SI::Hz];
		}
		
		part shoulderSensors : PostureSensor[2] {
			attribute :>> sensorAccuracy = 0.5 [SI::deg];
			attribute :>> samplingRate = 100.0 [SI::Hz];
		}
		
		part spineActuators : ExoskeletonActuator[5] {
			attribute :>> maxTorque = 50.0 [SI::'N·m'];
			attribute :>> responseTime = 0.05 [SI::s];
			attribute :>> jointLocation = "spine";
		}
		
		part shoulderActuators : ExoskeletonActuator[2] {
			attribute :>> maxTorque = 40.0 [SI::'N·m'];
			attribute :>> responseTime = 0.05 [SI::s];
			attribute :>> jointLocation = "shoulder";
		}
		
		part hipActuators : ExoskeletonActuator[2] {
			attribute :>> maxTorque = 60.0 [SI::'N·m'];
			attribute :>> responseTime = 0.05 [SI::s];
			attribute :>> jointLocation = "hip";
		}
		
		part hapticModules : HapticFeedbackModule[6] {
			attribute :>> vibrationFrequency = 250.0 [SI::Hz];
			attribute :>> maxIntensity = 1.0;
		}
		
		part controller : ControlProcessor {
			attribute :>> processingFrequency = 1000.0 [SI::Hz];
			attribute :>> controlAlgorithm = "AdaptivePostureControl";
		}
		
		part battery : BatteryModule {
			attribute :>> capacity = 100.0 [SI::'W·h'];
			attribute :>> nominalVoltage = 24.0 [SI::V];
			attribute :>> currentCharge = 100.0;
		}
		
		interface sensorToController connect 
			spineSensors[1].dataOutput to controller.sensorInput;
		
		interface controllerToActuator connect 
			controller.actuatorOutput to spineActuators[1].commandInput;
		
		interface controllerToHaptic connect 
			controller.hapticControl to hapticModules[1].feedbackOutput;
		
		interface batteryMonitoring connect 
			battery.powerStatus to controller.powerMonitor;
		
		perform action providePosturalSupport[*] ordered references assistUserPosture;
	}
	
	action def SensePosture {
		in attribute sensorLocation : String;
		out postureReading : PostureData;
	}
	
	action def AnalyzePosture {
		in postureInput : PostureData;
		out supportRequired : Boolean;
		out supportLevel : Real;
	}
	
	action def GenerateSupportCommand {
		in supportLevel : Real;
		in targetJoint : String;
		out supportCmd : SupportCommand;
	}
	
	action def ActivateHapticFeedback {
		in feedbackTrigger : Boolean;
		out hapticSignal : HapticFeedback;
	}
	
	action def CheckBatteryStatus {
		in currentCharge : BatteryPercentage;
		out lowBattery : Boolean;
	}
	
	action def AssistUserPosture {
		first start;
		then merge continuousMonitoring;
		
		action senseUserPosture : SensePosture {
			in sensorLocation = "spine";
			out postureReading : PostureData;
		}
		
		then action analyzePosture : AnalyzePosture {
			in postureInput = senseUserPosture.postureReading;
			out supportRequired : Boolean;
			out supportLevel : Real;
		}
		
		then decide;
			if analyzePosture.supportRequired then generateSupport;
			if not analyzePosture.supportRequired then provideHaptic;
		
		action generateSupport : GenerateSupportCommand {
			in supportLevel = analyzePosture.supportLevel;
			in targetJoint = "spine";
			out supportCmd : SupportCommand;
		}
		then action activateActuator {
			in command = generateSupport.supportCmd;
		}
		then provideHaptic;
		
		action provideHaptic : ActivateHapticFeedback {
			in feedbackTrigger = analyzePosture.supportRequired;
			out hapticSignal : HapticFeedback;
		}
		
		then action checkBattery : CheckBatteryStatus {
			in currentCharge = 100.0;
			out lowBattery : Boolean;
		}
		
		then decide;
			if checkBattery.lowBattery then alertLowPower;
			if not checkBattery.lowBattery then continuousMonitoring;
		
		action alertLowPower;
		then done;
	}
	
	action assistUserPosture : AssistUserPosture;
	
	state def VestOperationStates {
		entry; then standby;
		
		state standby;
		
		transition standby_to_monitoring
			first standby
			accept userActivation
			then monitoring;
		
		state monitoring;
		
		transition monitoring_to_analyzing
			first monitoring
			accept postureDataReceived
			then analyzing;
		
		state analyzing;
		
		transition analyzing_to_assisting
			first analyzing
			if supportNeeded
			then assisting;
		
		transition analyzing_to_monitoring
			first analyzing
			if not supportNeeded
			then monitoring;
		
		state assisting;
		
		transition assisting_to_monitoring
			first assisting
			accept supportComplete
			then monitoring;
		
		state lowPowerMode;
		
		transition any_to_lowPower
			first standby, monitoring, analyzing, assisting
			accept batteryLevelCritical
			then lowPowerMode;
		
		transition lowPower_to_standby
			first lowPowerMode
			accept batteryCharged
			then standby;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
		doc /* The robotic tech vest shall provide real-time postural support to the user by monitoring spinal alignment and activating exoskeleton actuators to assist in maintaining proper posture and reducing physical strain. */
		subject vestSystem : RoboticTechVest;
	}
	
	requirement <'REQ-002'> responseTime : PerformanceRequirement {
		doc /* The system shall detect postural deviation and activate support within 100 milliseconds. */
		subject vestSystem : RoboticTechVest;
		require constraint {
			vestSystem.controller.processingFrequency >= 10.0 [SI::Hz]
		}
	}
	
	requirement <'REQ-003'> maxTorqueLimit : SafetyRequirement {
		doc /* Actuators shall not exceed safe torque limits to prevent user injury. */
		subject vestSystem : RoboticTechVest;
		require constraint {
			vestSystem.spineActuators[1].maxTorque <= 60.0 [SI::'N·m']
		}
	}
	
	requirement <'REQ-004'> batteryLife : PerformanceRequirement {
		doc /* The battery shall support at least 8 hours of continuous operation. */
		subject vestSystem : RoboticTechVest;
		require constraint {
			vestSystem.battery.capacity >= 80.0 [SI::'W·h']
		}
	}
	
	requirement <'REQ-005'> sensorPrecision : PerformanceRequirement {
		doc /* Posture sensors shall maintain accuracy within 1 degree. */
		subject vestSystem : RoboticTechVest;
		require constraint {
			vestSystem.spineSensors[1].sensorAccuracy <= 1.0 [SI::deg]
		}
	}
	
	requirement vestMissionRequirement {
		doc /* The robotic tech vest shall augment human physical capability by providing intelligent postural support and reducing musculoskeletal strain during daily activities and physical labor. */
		
		require primaryFunction;
		require responseTime;
		require maxTorqueLimit;
		require batteryLife;
		require sensorPrecision;
	}
	
	part vestSystem : RoboticTechVest;
}
