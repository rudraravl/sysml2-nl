package 'Hug Machine System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		enum def HugMode { gentle; moderate; firm; }
		attribute def HugIntensity :> Real;
		attribute def SessionDuration :> DurationValue;
		attribute def UserProfile {
			attribute name : String;
			attribute mode : HugMode;
			attribute intensity : HugIntensity;
			attribute duration : SessionDuration;
		}

		attribute def UserConfiguration {
			attribute mode : HugMode;
			attribute intensity : HugIntensity;
			attribute duration : SessionDuration;
			attribute profile : UserProfile;
		}

		abstract attribute def ControlSignal;
		attribute def StartSessionSignal :> ControlSignal;
		attribute def StopSessionSignal :> ControlSignal;
		attribute def PauseSessionSignal :> ControlSignal;
		attribute def ResumeSessionSignal :> ControlSignal;

		attribute def UserPresentSignal;
		attribute def EmergencyStopSignal;
		attribute def SystemResetSignal;
		enum def ArmDirection { extend; retract; hold; }
		attribute def ActuationCommand {
			attribute targetForce : ForceValue;
			attribute direction : ArmDirection;
		}

		port def ConfigOutPort {
			out userConfig : UserConfiguration;
		}
		port def ConfigInPort {
			in userConfig : UserConfiguration;
		}
		port def ControlOutPort {
			out controlSignal : ControlSignal;
		}
		port def ControlInPort {
			in controlSignal : ControlSignal;
		}
		port def PressureOutPort {
			out sensedPressure : PressureValue;
		}
		port def PressureInPort {
			in sensedPressure : PressureValue;
		}
		port def PresenceOutPort {
			out presenceSignal : UserPresentSignal;
		}
		port def PresenceInPort {
			in presenceSignal : UserPresentSignal;
		}
		port def ForceOutPort {
			out armForce : ForceValue;
		}
		port def ForceInPort {
			in armForce : ForceValue;
		}
		port def CommandOutPort {
			out armCommand : ActuationCommand;
		}
		port def CommandInPort {
			in armCommand : ActuationCommand;
		}
		port def EmergencyOutPort {
			out estopSignal : EmergencyStopSignal;
		}
		port def EmergencyInPort {
			in estopSignal : EmergencyStopSignal;
		}

		part def ActuatorAssembly {
			port commandPort : CommandInPort;
			port feedbackPort : ForceOutPort;
		}

		part def RoboticArm {
			attribute maxForce : ForceValue;
			port actuationPort : CommandInPort;
			port feedbackPort : ForceOutPort;
			part actuatorAssembly : ActuatorAssembly;
			bind actuationPort = actuatorAssembly.commandPort;
			bind feedbackPort = actuatorAssembly.feedbackPort;
		}

		part def PressureSensor {
			attribute maxPressure : PressureValue;
			port sensorPort : PressureOutPort;
			port presencePort : PresenceOutPort;
		}

		part def UserInterface {
			port configPort : ConfigOutPort;
			port controlPort : ControlOutPort;
			attribute savedProfiles : UserProfile[*];
		}

		part def ControlProcessor {
			port configPort : ConfigInPort;
			port controlPort : ControlInPort;
			port leftSensorPort : PressureInPort;
			port rightSensorPort : PressureInPort;
			port backSensorPort : PressureInPort;
			port presencePort : PresenceInPort;
			port leftArmCommandPort : CommandOutPort;
			port rightArmCommandPort : CommandOutPort;
			port safetyPort : EmergencyInPort;
			attribute currentPressure : PressureValue;
			attribute targetForce : ForceValue;
			attribute sessionTimer : DurationValue;
		}

		part def SafetyController {
			port leftArmForcePort : ForceInPort;
			port rightArmForcePort : ForceInPort;
			port leftPressurePort : PressureInPort;
			port rightPressurePort : PressureInPort;
			port backPressurePort : PressureInPort;
			port estopPort : EmergencyOutPort;
			attribute maxSafeForce : ForceValue;
			attribute maxSafePressure : PressureValue;
		}

		part def HugMachine {
			part leftArm : RoboticArm;
			part rightArm : RoboticArm;
			part leftSensor : PressureSensor;
			part rightSensor : PressureSensor;
			part backSensor : PressureSensor;
			part controlProcessor : ControlProcessor;
			part safetyController : SafetyController;
			part userInterface : UserInterface;
		}

		action def CalibrateForce {
			in mode : HugMode;
			in intensity : HugIntensity;
			out targetForce : ForceValue;
		}
		action def ApplyHug {
			in targetForce : ForceValue;
		}
		action def ReleaseArms;
		action def MaintainPressure {
			in current : PressureValue;
			in target : PressureValue;
			out adjustedForce : ForceValue;
		}
		action def DetectPresence {
			in leftPressure : PressureValue;
			in rightPressure : PressureValue;
			in backPressure : PressureValue;
			out present : Boolean;
		}

		state def ControlStates;
		state def SafetyStates;

		requirement def HugMachineRequirements {
			doc /* The system shall provide controlled and adjustable physical embraces for stress relief and emotional support. */
		}
		requirement def SafetyRequirement {
			doc /* The system shall trigger an immediate emergency stop if force or pressure exceeds pre-set maximum safety limits, causing the arms to release and retract. */
		}
		requirement def FeedbackRequirement {
			doc /* The system shall maintain consistent, comfortable pressure via real-time sensor feedback during a hug session. */
		}
		requirement def UserProfileRequirement {
			doc /* The system shall support user profiles allowing individuals to save and recall preferred settings. */
		}
		requirement def SessionControlRequirement {
			doc /* The user shall be able to pause, resume, or stop the session at any time through the interface. */
		}
	}

	package Usages {
		private import Definitions::*;

		part hugMachine : HugMachine {
			part userInterface : UserInterface {
				port configPort : ConfigOutPort;
				port controlPort : ControlOutPort;
				attribute savedProfiles : UserProfile[*];
			}

			part controlProcessor : ControlProcessor {
				port configPort : ConfigInPort;
				port controlPort : ControlInPort;
				port leftSensorPort : PressureInPort;
				port rightSensorPort : PressureInPort;
				port backSensorPort : PressureInPort;
				port presencePort : PresenceInPort;
				port leftArmCommandPort : CommandOutPort;
				port rightArmCommandPort : CommandOutPort;
				port safetyPort : EmergencyInPort;
				attribute currentPressure : PressureValue;
				attribute targetForce : ForceValue;
				attribute sessionTimer : DurationValue;

				state 'control states' : ControlStates {
					entry; then idle;
					state idle;
					accept UserConfiguration via configPort
						then configuring;
					accept EmergencyStopSignal via safetyPort
						then emergency;

					state configuring {
						entry CalibrateForce {
							in mode = configPort.userConfig.mode;
							in intensity = configPort.userConfig.intensity;
							out targetForce = targetForce;
						}
					}
					accept UserPresentSignal via presencePort
						then embracing;
					accept EmergencyStopSignal via safetyPort
						then emergency;

					state embracing {
						entry ApplyHug {
							in targetForce = targetForce;
						}
						do ApplyHug {
							in targetForce = targetForce;
						}
						do MaintainPressure {
							in current = currentPressure;
							in target = targetForce;
							out adjustedForce = targetForce;
						}
						exit ReleaseArms;
					}
					accept StopSessionSignal via controlPort
						then releasing;
					accept PauseSessionSignal via controlPort
						then paused;
					accept EmergencyStopSignal via safetyPort
						then emergency;

					state paused;
					accept ResumeSessionSignal via controlPort
						then embracing;
					accept StopSessionSignal via controlPort
						then releasing;
					accept EmergencyStopSignal via safetyPort
						then emergency;

					state releasing {
						entry ReleaseArms;
					}
					accept when currentPressure <= 0.0 [Pa]
						then idle;

					state emergency {
						entry ReleaseArms;
					}
					accept SystemResetSignal via controlPort
						then idle;
				}
			}

			part safetyController : SafetyController {
				port leftArmForcePort : ForceInPort;
				port rightArmForcePort : ForceInPort;
				port leftPressurePort : PressureInPort;
				port rightPressurePort : PressureInPort;
				port backPressurePort : PressureInPort;
				port estopPort : EmergencyOutPort;
				attribute maxSafeForce : ForceValue = 50 [N];
				attribute maxSafePressure : PressureValue = 10000 [Pa];

				state 'safety states' : SafetyStates {
					entry; then monitoring;
					state monitoring;
					accept when leftArmForcePort.armForce > maxSafeForce
						do send new EmergencyStopSignal() to estopPort
						then fault;
					accept when rightArmForcePort.armForce > maxSafeForce
						do send new EmergencyStopSignal() to estopPort
						then fault;
					accept when leftPressurePort.sensedPressure > maxSafePressure
						do send new EmergencyStopSignal() to estopPort
						then fault;
					accept when rightPressurePort.sensedPressure > maxSafePressure
						do send new EmergencyStopSignal() to estopPort
						then fault;
					accept when backPressurePort.sensedPressure > maxSafePressure
						do send new EmergencyStopSignal() to estopPort
						then fault;
					state fault;
					accept SystemResetSignal
						then monitoring;
				}
			}

			part leftArm : RoboticArm {
				attribute maxForce : ForceValue = 50 [N];
				port actuationPort : CommandInPort;
				port feedbackPort : ForceOutPort;
				part actuatorAssembly : ActuatorAssembly {
					port commandPort : CommandInPort;
					port feedbackPort : ForceOutPort;
				}
			}
			part rightArm : RoboticArm {
				attribute maxForce : ForceValue = 50 [N];
				port actuationPort : CommandInPort;
				port feedbackPort : ForceOutPort;
				part actuatorAssembly : ActuatorAssembly {
					port commandPort : CommandInPort;
					port feedbackPort : ForceOutPort;
				}
			}

			part leftSensor : PressureSensor {
				attribute maxPressure : PressureValue = 10000 [Pa];
				port sensorPort : PressureOutPort;
				port presencePort : PresenceOutPort;
			}
			part rightSensor : PressureSensor {
				attribute maxPressure : PressureValue = 10000 [Pa];
				port sensorPort : PressureOutPort;
				port presencePort : PresenceOutPort;
			}
			part backSensor : PressureSensor {
				attribute maxPressure : PressureValue = 10000 [Pa];
				port sensorPort : PressureOutPort;
				port presencePort : PresenceOutPort;
			}

			flow configFlow of UserConfiguration
				from userInterface.configPort.userConfig to controlProcessor.configPort.userConfig;
			flow controlFlow of ControlSignal
				from userInterface.controlPort.controlSignal to controlProcessor.controlPort.controlSignal;

			flow leftSensorFlow of PressureValue
				from leftSensor.sensorPort.sensedPressure to controlProcessor.leftSensorPort.sensedPressure;
			flow rightSensorFlow of PressureValue
				from rightSensor.sensorPort.sensedPressure to controlProcessor.rightSensorPort.sensedPressure;
			flow backSensorFlow of PressureValue
				from backSensor.sensorPort.sensedPressure to controlProcessor.backSensorPort.sensedPressure;

			flow leftPresenceFlow of UserPresentSignal
				from leftSensor.presencePort.presenceSignal to controlProcessor.presencePort.presenceSignal;
			flow rightPresenceFlow of UserPresentSignal
				from rightSensor.presencePort.presenceSignal to controlProcessor.presencePort.presenceSignal;
			flow backPresenceFlow of UserPresentSignal
				from backSensor.presencePort.presenceSignal to controlProcessor.presencePort.presenceSignal;

			flow leftArmCommandFlow of ActuationCommand
				from controlProcessor.leftArmCommandPort.armCommand to leftArm.actuationPort.armCommand;
			flow rightArmCommandFlow of ActuationCommand
				from controlProcessor.rightArmCommandPort.armCommand to rightArm.actuationPort.armCommand;

			flow leftArmFeedbackFlow of ForceValue
				from leftArm.feedbackPort.armForce to safetyController.leftArmForcePort.armForce;
			flow rightArmFeedbackFlow of ForceValue
				from rightArm.feedbackPort.armForce to safetyController.rightArmForcePort.armForce;

			flow leftSafetySensorFlow of PressureValue
				from leftSensor.sensorPort.sensedPressure to safetyController.leftPressurePort.sensedPressure;
			flow rightSafetySensorFlow of PressureValue
				from rightSensor.sensorPort.sensedPressure to safetyController.rightPressurePort.sensedPressure;
			flow backSafetySensorFlow of PressureValue
				from backSensor.sensorPort.sensedPressure to safetyController.backPressurePort.sensedPressure;

			flow estopFlow of EmergencyStopSignal
				from safetyController.estopPort.estopSignal to controlProcessor.safetyPort.estopSignal;
		}

		requirement hugMachineReq : HugMachineRequirements {
			subject hugMachine;
		}
		requirement safetyReq : SafetyRequirement {
			subject hugMachine;
		}
		requirement feedbackReq : FeedbackRequirement {
			subject hugMachine;
		}
		requirement userProfileReq : UserProfileRequirement {
			subject hugMachine;
		}
		requirement sessionControlReq : SessionControlRequirement {
			subject hugMachine;
		}
	}
}
