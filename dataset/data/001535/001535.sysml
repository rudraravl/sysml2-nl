package 'Powered Exoskeleton System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def UserIntentSignal {
		attribute movementDirection : Real[3];
		attribute movementMagnitude : Real;
		attribute timestamp : DurationValue;
	}
	
	attribute def AssistanceLevel :> Real;
	
	attribute def JointState {
		attribute angle : AngleValue;
		attribute velocity : AngularVelocityValue;
		attribute appliedForce : ForceValue;
	}
	
	enumeration def OperatingMode {
		enum standby;
		enum active;
		enum emergency;
		enum shutdown;
	}
	
	enumeration def SafetyStatus {
		enum normal;
		enum warning;
		enum critical;
	}
	
	port def PowerSupplyPort {
		out attribute voltage : ElectricPotentialValue;
		out attribute current : ElectricCurrentValue;
		out attribute availablePower : PowerValue;
	}
	
	port def PowerConsumptionPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
		in attribute requiredPower : PowerValue;
	}
	
	port def SensorDataPort {
		out attribute jointStates : JointState[*];
		out attribute userIntent : UserIntentSignal;
	}
	
	port def ControlCommandPort {
		out attribute targetTorques : TorqueValue[*];
		out attribute assistLevel : AssistanceLevel;
	}
	
	port def MechanicalInterfacePort {
		in attribute userForce : ForceValue;
		out attribute assistiveForce : ForceValue;
	}
	
	port def StatusPort {
		out attribute mode : OperatingMode;
		out attribute safety : SafetyStatus;
		out attribute batteryLevel : Real;
	}
	
	part def BatteryPack {
		attribute capacity : EnergyValue;
		attribute currentCharge : EnergyValue;
		attribute nominalVoltage : ElectricPotentialValue;
		attribute maxCurrent : ElectricCurrentValue;
		attribute operatingDuration : DurationValue;
		
		port powerOutput : PowerSupplyPort;
		
		state batteryStates {
			entry; then charged;
			
			state charged;
			accept dischargeEvent then discharging;
			
			state discharging;
			accept continueDischarge then discharging;
			accept lowChargeDetected then low;
			
			state low;
			accept rechargeEvent then charged;
		}
	}
	
	part def MotorActuator {
		attribute maxTorque : TorqueValue;
		attribute efficiency : Real;
		attribute gearRatio : Real;
		
		port powerInput : PowerConsumptionPort;
		port commandInput : ~ControlCommandPort;
		port mechanicalOutput : MechanicalInterfacePort;
	}
	
	part def ForceSensor {
		attribute sensitivity : Real;
		attribute samplingRate : Real;
		
		port dataOutput : SensorDataPort;
	}
	
	part def AngleSensor {
		attribute resolution : AngleValue;
		attribute range : AngleValue;
		
		port dataOutput : SensorDataPort;
	}
	
	part def ControlProcessor {
		attribute processingFrequency : Real;
		attribute responseTime : DurationValue;
		attribute detectionResponseTime : DurationValue;
		
		port sensorInput : ~SensorDataPort;
		port commandOutput : ControlCommandPort;
		port statusOutput : StatusPort;
		port powerInput : PowerConsumptionPort;
	}
	
	part def StructuralFrame {
		attribute material : String;
		attribute totalMass : MassValue;
		attribute maxLoad : MassValue;
		
		port userInterface : MechanicalInterfacePort;
	}
	
	part def ExoskeletonJoint {
		attribute jointName : String;
		attribute rangeOfMotion : AngleValue;
		
		part actuator : MotorActuator;
		part forceSensor : ForceSensor;
		part angleSensor : AngleSensor;
		
		port powerIn : PowerConsumptionPort;
		port controlIn : ~ControlCommandPort;
		port sensorOut : SensorDataPort;
		port mechanicalInterface : MechanicalInterfacePort;
		
		connect powerIn to actuator.powerInput;
		connect controlIn to actuator.commandInput;
		connect forceSensor.dataOutput to sensorOut;
		connect angleSensor.dataOutput to sensorOut;
		connect actuator.mechanicalOutput to mechanicalInterface;
	}
	
	action def SenseUserIntent {
		in jointStates : JointState[*];
		in userForce : ForceValue;
		out detectedIntent : UserIntentSignal;
	}
	
	action def ComputeAssistiveTorque {
		in userIntent : UserIntentSignal;
		in currentJointStates : JointState[*];
		in assistanceLevel : AssistanceLevel;
		out requiredTorques : TorqueValue[*];
	}
	
	action def ApplyActuation {
		in commandedTorques : TorqueValue[*];
		in availablePower : PowerValue;
		out appliedTorques : TorqueValue[*];
		out assistiveForce : ForceValue;
	}
	
	action def MonitorSafety {
		in jointStates : JointState[*];
		in systemMode : OperatingMode;
		in batteryLevel : Real;
		out safetyStatus : SafetyStatus;
	}
	
	action def AugmentHumanStrength {
		in userForce : ForceValue;
		in desiredAssistLevel : AssistanceLevel;
		out augmentedForce : ForceValue;
		
		first start;
		then merge continuousAssist;
		then action sense : SenseUserIntent {
			in jointStates : JointState[*];
			in userForce = AugmentHumanStrength::userForce;
			out detectedIntent : UserIntentSignal;
		}
		flow sense.detectedIntent to compute.userIntent;
		then action compute : ComputeAssistiveTorque {
			in userIntent : UserIntentSignal;
			in currentJointStates : JointState[*];
			in assistanceLevel = desiredAssistLevel;
			out requiredTorques : TorqueValue[*];
		}
		flow compute.requiredTorques to apply.commandedTorques;
		then action apply : ApplyActuation {
			in commandedTorques : TorqueValue[*];
			in availablePower : PowerValue;
			out appliedTorques : TorqueValue[*];
			out assistiveForce : ForceValue;
		}
		flow apply.assistiveForce to augmentedForce;
		then action monitor : MonitorSafety {
			in jointStates : JointState[*];
			in systemMode : OperatingMode;
			in batteryLevel : Real;
			out safetyStatus : SafetyStatus;
		}
		then decide;
		if monitor.safetyStatus == SafetyStatus::normal then continuousAssist;
		if monitor.safetyStatus == SafetyStatus::warning then continuousAssist;
		if monitor.safetyStatus == SafetyStatus::critical then done;
	}
	
	requirement def <'REQ-001'> StrengthAugmentationRequirement {
		doc /* The exoskeleton shall augment user lifting capacity by a minimum factor of 3x. */
		subject exoskeleton;
		require constraint {
			exoskeleton.augmentationFactor >= 3.0
		}
	}
	
	requirement def <'REQ-002'> OperationalEnduranceRequirement {
		doc /* The system shall operate continuously for at least 6 hours on a single charge. */
		subject battery;
		require constraint {
			battery.operatingDuration >= 6.0 [h]
		}
	}
	
	requirement def <'REQ-003'> ResponseTimeRequirement {
		doc /* The control system shall respond to user intent within 30 milliseconds. */
		subject controller;
		require constraint {
			controller.responseTime <= 30.0 [ms]
		}
	}
	
	requirement def <'REQ-004'> SafetyMonitoringRequirement {
		doc /* The system shall continuously monitor safety parameters and enter safe mode within 50 milliseconds of detecting a critical condition. */
		subject safetySystem;
		require constraint {
			safetySystem.detectionResponseTime <= 50.0 [ms]
		}
	}
	
	requirement def <'REQ-005'> PayloadCapacityRequirement {
		doc /* The exoskeleton shall support a maximum payload of 100 kg while maintaining full functionality. */
		subject structure;
		require constraint {
			structure.maxLoad >= 100.0 [kg]
		}
	}
	
	part def PoweredExoskeleton {
		doc /* 
		A powered exoskeleton system designed to augment human physical capabilities.
		The system enhances user strength and endurance by providing assistive forces
		that amplify natural human movement while maintaining safety and control.
		*/
		
		attribute augmentationFactor : Real;
		attribute totalWeight : MassValue;
		attribute maxPayloadCapacity : MassValue;
		
		part battery : BatteryPack {
			attribute capacity = 3000.0 [W*h];
			attribute currentCharge = 3000.0 [W*h];
			attribute nominalVoltage = 48.0 [V];
			attribute maxCurrent = 30.0 [A];
			attribute operatingDuration = 6.0 [h];
		}
		
		part controller : ControlProcessor {
			attribute processingFrequency = 1000.0;
			attribute responseTime = 25.0 [ms];
			attribute detectionResponseTime = 45.0 [ms];
		}
		
		part frame : StructuralFrame {
			attribute material = "Carbon Fiber Composite";
			attribute totalMass = 18.0 [kg];
			attribute maxLoad = 120.0 [kg];
		}
		
		part hipJointLeft : ExoskeletonJoint {
			attribute jointName = "Left Hip";
			attribute rangeOfMotion = 120.0 [deg];
		}
		
		part hipJointRight : ExoskeletonJoint {
			attribute jointName = "Right Hip";
			attribute rangeOfMotion = 120.0 [deg];
		}
		
		part kneeJointLeft : ExoskeletonJoint {
			attribute jointName = "Left Knee";
			attribute rangeOfMotion = 135.0 [deg];
		}
		
		part kneeJointRight : ExoskeletonJoint {
			attribute jointName = "Right Knee";
			attribute rangeOfMotion = 135.0 [deg];
		}
		
		part ankleJointLeft : ExoskeletonJoint {
			attribute jointName = "Left Ankle";
			attribute rangeOfMotion = 70.0 [deg];
		}
		
		part ankleJointRight : ExoskeletonJoint {
			attribute jointName = "Right Ankle";
			attribute rangeOfMotion = 70.0 [deg];
		}
		
		part shoulderJointLeft : ExoskeletonJoint {
			attribute jointName = "Left Shoulder";
			attribute rangeOfMotion = 180.0 [deg];
		}
		
		part shoulderJointRight : ExoskeletonJoint {
			attribute jointName = "Right Shoulder";
			attribute rangeOfMotion = 180.0 [deg];
		}
		
		part elbowJointLeft : ExoskeletonJoint {
			attribute jointName = "Left Elbow";
			attribute rangeOfMotion = 145.0 [deg];
		}
		
		part elbowJointRight : ExoskeletonJoint {
			attribute jointName = "Right Elbow";
			attribute rangeOfMotion = 145.0 [deg];
		}
		
		part backSupportJoint : ExoskeletonJoint {
			attribute jointName = "Lumbar Support";
			attribute rangeOfMotion = 90.0 [deg];
		}
		
		connect battery.powerOutput to controller.powerInput;
		connect battery.powerOutput to hipJointLeft.powerIn;
		connect battery.powerOutput to hipJointRight.powerIn;
		connect battery.powerOutput to kneeJointLeft.powerIn;
		connect battery.powerOutput to kneeJointRight.powerIn;
		connect battery.powerOutput to ankleJointLeft.powerIn;
		connect battery.powerOutput to ankleJointRight.powerIn;
		connect battery.powerOutput to shoulderJointLeft.powerIn;
		connect battery.powerOutput to shoulderJointRight.powerIn;
		connect battery.powerOutput to elbowJointLeft.powerIn;
		connect battery.powerOutput to elbowJointRight.powerIn;
		connect battery.powerOutput to backSupportJoint.powerIn;
		
		connect hipJointLeft.sensorOut to controller.sensorInput;
		connect hipJointRight.sensorOut to controller.sensorInput;
		connect kneeJointLeft.sensorOut to controller.sensorInput;
		connect kneeJointRight.sensorOut to controller.sensorInput;
		connect ankleJointLeft.sensorOut to controller.sensorInput;
		connect ankleJointRight.sensorOut to controller.sensorInput;
		connect shoulderJointLeft.sensorOut to controller.sensorInput;
		connect shoulderJointRight.sensorOut to controller.sensorInput;
		connect elbowJointLeft.sensorOut to controller.sensorInput;
		connect elbowJointRight.sensorOut to controller.sensorInput;
		connect backSupportJoint.sensorOut to controller.sensorInput;
		
		connect controller.commandOutput to hipJointLeft.controlIn;
		connect controller.commandOutput to hipJointRight.controlIn;
		connect controller.commandOutput to kneeJointLeft.controlIn;
		connect controller.commandOutput to kneeJointRight.controlIn;
		connect controller.commandOutput to ankleJointLeft.controlIn;
		connect controller.commandOutput to ankleJointRight.controlIn;
		connect controller.commandOutput to shoulderJointLeft.controlIn;
		connect controller.commandOutput to shoulderJointRight.controlIn;
		connect controller.commandOutput to elbowJointLeft.controlIn;
		connect controller.commandOutput to elbowJointRight.controlIn;
		connect controller.commandOutput to backSupportJoint.controlIn;
		
		perform action primaryFunction : AugmentHumanStrength {
			doc /* 
			Primary Function: Continuously sense user movement intent through integrated
			force and position sensors, compute optimal assistive torques based on
			biomechanical models and user-configured assistance levels, and apply
			precisely controlled motor actuation to amplify human strength and reduce
			physical strain during lifting, carrying, and manipulation tasks.
			*/
			in userForce : ForceValue;
			in desiredAssistLevel : AssistanceLevel = 0.75;
			out augmentedForce : ForceValue;
		}
		
		state operatingStates {
			entry; then standby;
			
			state standby;
			accept powerOn then active;
			
			state active;
			accept emergencyStop then emergency;
			accept normalShutdown then shutdown;
			
			state emergency;
			accept reset then standby;
			
			state shutdown;
			then done;
		}
	}
	
	part industrialExoskeleton : PoweredExoskeleton {
		attribute augmentationFactor = 4.5;
		attribute totalWeight = 22.0 [kg];
		attribute maxPayloadCapacity = 100.0 [kg];
		
		satisfy strengthRequirement : StrengthAugmentationRequirement {
			subject exoskeleton = industrialExoskeleton;
		}
		
		satisfy enduranceRequirement : OperationalEnduranceRequirement {
			subject battery = industrialExoskeleton.battery;
		}
		
		satisfy responseRequirement : ResponseTimeRequirement {
			subject controller = industrialExoskeleton.controller;
		}
		
		satisfy safetyRequirement : SafetyMonitoringRequirement {
			subject safetySystem = industrialExoskeleton.controller;
		}
		
		satisfy payloadRequirement : PayloadCapacityRequirement {
			subject structure = industrialExoskeleton.frame;
		}
	}
}
