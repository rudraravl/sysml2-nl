package AnimatronicCharacterSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def MotionCommand {
		attribute jointId : Integer;
		attribute targetAngle : ISQ::AngleValue;
		attribute speed : ISQ::AngularVelocityValue;
		attribute duration : ISQ::TimeValue;
	}
	
	item def SensorFeedback {
		attribute jointId : Integer;
		attribute currentAngle : ISQ::AngleValue;
		attribute currentTorque : ISQ::TorqueValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute statusCode : Integer;
	}
	
	item def AudioCommand {
		attribute trackId : Integer;
		attribute volume : Real;
		attribute startTime : ISQ::TimeValue;
		attribute loopCount : Integer;
	}
	
	item def TriggerEvent {
		attribute eventType : Integer;
		attribute detectionDistance : ISQ::LengthValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def PowerSupply {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute powerRating : ISQ::PowerValue;
	}
	
	port def MotionControlPort {
		out item command : MotionCommand;
		in item feedback : SensorFeedback;
	}
	
	port def AudioControlPort {
		out item audioCmd : AudioCommand;
	}
	
	port def SensorPort {
		out item trigger : TriggerEvent;
	}
	
	port def PowerPort {
		in item power : PowerSupply;
	}
	
	part def ServoActuator {
		attribute jointName : String;
		attribute maxTorque : ISQ::TorqueValue;
		attribute rangeMin : ISQ::AngleValue;
		attribute rangeMax : ISQ::AngleValue;
		attribute currentPosition : ISQ::AngleValue;
		
		port controlPort : MotionControlPort;
		port powerPort : PowerPort;
		
		action def ExecuteMotion {
			in cmd : MotionCommand;
			out fb : SensorFeedback;
			
			first start;
			then assign currentPosition := cmd.targetAngle;
			then assign fb := SensorFeedback {
				jointId = cmd.jointId;
				currentAngle = currentPosition;
				currentTorque = maxTorque * 0.6;
				temperature = 318.15 [K];
				statusCode = 0;
			}
			then done;
		}
	}
	
	part def ProximitySensor {
		attribute sensorId : Integer;
		attribute detectionRange : ISQ::LengthValue;
		attribute detectionAngle : ISQ::AngleValue;
		attribute sensitivity : Real;
		
		port sensorPort : SensorPort;
		port powerPort : PowerPort;
		
		action def DetectPresence {
			out event : TriggerEvent;
			
			first start;
			then assign event := TriggerEvent {
				eventType = 1;
				detectionDistance = 1.5 [SI::m];
				timestamp = 0.0 [SI::s];
			}
			then done;
		}
	}
	
	part def SpeakerSystem {
		attribute speakerId : Integer;
		attribute maxVolume : Real;
		attribute frequencyRange : ISQ::FrequencyValue;
		attribute currentTrack : Integer;
		
		port audioPort : AudioControlPort;
		port powerPort : PowerPort;
		
		action def PlayAudio {
			in audioCmd : AudioCommand;
			
			first start;
			then assign currentTrack := audioCmd.trackId;
			then done;
		}
	}
	
	part def AnimationController {
		attribute controllerId : Integer;
		attribute sequenceLibrarySize : Integer;
		attribute activeSequence : Integer;
		attribute isPerforming : Boolean;
		
		port motorControl[8] : MotionControlPort;
		port audioControl : AudioControlPort;
		port sensorInput : SensorPort;
		port powerPort : PowerPort;
		
		action def LoadAnimationSequence {
			in sequenceId : Integer;
			out motionCommands : MotionCommand[*] ordered;
			out audioCommands : AudioCommand[*] ordered;
			
			first start;
			then assign activeSequence := sequenceId;
			then assign motionCommands := (
				MotionCommand { jointId = 1; targetAngle = 0.785 [SI::rad]; speed = 0.524 [SI::rad/SI::s]; duration = 1.5 [SI::s]; },
				MotionCommand { jointId = 2; targetAngle = -0.524 [SI::rad]; speed = 0.436 [SI::rad/SI::s]; duration = 1.2 [SI::s]; },
				MotionCommand { jointId = 3; targetAngle = 1.047 [SI::rad]; speed = 0.611 [SI::rad/SI::s]; duration = 1.7 [SI::s]; }
			);
			then assign audioCommands := (
				AudioCommand { trackId = 101; volume = 0.8; startTime = 0.0 [SI::s]; loopCount = 1; }
			);
			then done;
		}
		
		action def ExecutePerformance {
			in sequenceId : Integer;
			out feedbackData : SensorFeedback[*];
			
			first start;
			then perform action loadSeq : LoadAnimationSequence {
				in sequenceId = sequenceId;
				out motionCommands;
				out audioCommands;
			}
			then assign isPerforming := true;
			then assign feedbackData := ( );
			then for motionCmd in loadSeq.motionCommands {
				perform action sendMotion : SendMotionCommand {
					in command = motionCmd;
					out feedback;
				}
				then assign feedbackData := feedbackData->including(sendMotion.feedback);
			}
			then for audioCmd in loadSeq.audioCommands {
				perform action sendAudio : SendAudioCommand {
					in command = audioCmd;
				}
			}
			then assign isPerforming := false;
			then done;
		}
		
		action def SendMotionCommand {
			in command : MotionCommand;
			out feedback : SensorFeedback;
			
			first start;
			then assign feedback := SensorFeedback {
				jointId = command.jointId;
				currentAngle = command.targetAngle;
				currentTorque = 3.5 [SI::'N*m'];
				temperature = 315.15 [K];
				statusCode = 0;
			}
			then done;
		}
		
		action def SendAudioCommand {
			in command : AudioCommand;
			
			first start;
			then done;
		}
	}
	
	state def AnimatronicOperationalState {
		entry action initializeSystem;
		
		state Standby {
			entry action enterLowPowerMode;
		}
		
		state Monitoring {
			entry action activateSensors;
			do action continuousMonitoring {
				out sensorData : TriggerEvent;
			}
		}
		
		state Performing {
			entry action beginPerformance;
			do action executeAnimationSequence {
				in sequenceId : Integer;
			}
			exit action completePerformance;
		}
		
		state Resetting {
			entry action returnToNeutralPosition;
		}
		
		transition standbyToMonitoring
			first Standby
			accept at Standby
			then Monitoring;
		
		transition monitoringToPerforming
			first Monitoring
			accept when continuousMonitoring.sensorData
			if continuousMonitoring.sensorData.eventType == 1
			then Performing;
		
		transition performingToResetting
			first Performing
			accept after 25.0 [SI::s]
			then Resetting;
		
		transition resettingToStandby
			first Resetting
			accept at Resetting
			then Standby;
	}
	
	part def AnimatronicCharacter {
		attribute characterName : String;
		attribute totalMass : ISQ::MassValue;
		attribute heightDimension : ISQ::LengthValue;
		attribute operatingVoltage : ISQ::VoltageValue;
		attribute maxPowerDraw : ISQ::PowerValue;
		
		port mainPowerPort : PowerPort;
		
		part headServo : ServoActuator {
			attribute :>> jointName = "Head";
			attribute :>> maxTorque = 4.0 [SI::'N*m'];
			attribute :>> rangeMin = -1.571 [SI::rad];
			attribute :>> rangeMax = 1.571 [SI::rad];
		}
		
		part neckServo : ServoActuator {
			attribute :>> jointName = "Neck";
			attribute :>> maxTorque = 5.0 [SI::'N*m'];
			attribute :>> rangeMin = -0.785 [SI::rad];
			attribute :>> rangeMax = 0.785 [SI::rad];
		}
		
		part leftShoulderServo : ServoActuator {
			attribute :>> jointName = "LeftShoulder";
			attribute :>> maxTorque = 8.0 [SI::'N*m'];
			attribute :>> rangeMin = -2.094 [SI::rad];
			attribute :>> rangeMax = 2.094 [SI::rad];
		}
		
		part rightShoulderServo : ServoActuator {
			attribute :>> jointName = "RightShoulder";
			attribute :>> maxTorque = 8.0 [SI::'N*m'];
			attribute :>> rangeMin = -2.094 [SI::rad];
			attribute :>> rangeMax = 2.094 [SI::rad];
		}
		
		part leftElbowServo : ServoActuator {
			attribute :>> jointName = "LeftElbow";
			attribute :>> maxTorque = 6.0 [SI::'N*m'];
			attribute :>> rangeMin = 0.0 [SI::rad];
			attribute :>> rangeMax = 2.618 [SI::rad];
		}
		
		part rightElbowServo : ServoActuator {
			attribute :>> jointName = "RightElbow";
			attribute :>> maxTorque = 6.0 [SI::'N*m'];
			attribute :>> rangeMin = 0.0 [SI::rad];
			attribute :>> rangeMax = 2.618 [SI::rad];
		}
		
		part jawServo : ServoActuator {
			attribute :>> jointName = "Jaw";
			attribute :>> maxTorque = 2.0 [SI::'N*m'];
			attribute :>> rangeMin = 0.0 [SI::rad];
			attribute :>> rangeMax = 0.524 [SI::rad];
		}
		
		part eyesServo : ServoActuator {
			attribute :>> jointName = "Eyes";
			attribute :>> maxTorque = 1.5 [SI::'N*m'];
			attribute :>> rangeMin = -0.785 [SI::rad];
			attribute :>> rangeMax = 0.785 [SI::rad];
		}
		
		part proximitySensor1 : ProximitySensor {
			attribute :>> sensorId = 1;
			attribute :>> detectionRange = 3.0 [SI::m];
			attribute :>> detectionAngle = 1.047 [SI::rad];
			attribute :>> sensitivity = 0.85;
		}
		
		part proximitySensor2 : ProximitySensor {
			attribute :>> sensorId = 2;
			attribute :>> detectionRange = 2.5 [SI::m];
			attribute :>> detectionAngle = 0.785 [SI::rad];
			attribute :>> sensitivity = 0.80;
		}
		
		part speakerSystem : SpeakerSystem {
			attribute :>> speakerId = 1;
			attribute :>> maxVolume = 1.0;
			attribute :>> frequencyRange = 20000.0 [SI::Hz];
		}
		
		part controller : AnimationController {
			attribute :>> controllerId = 1;
			attribute :>> sequenceLibrarySize = 50;
			attribute :>> isPerforming = false;
		}
		
		connection powerDist1 : PowerPort connect mainPowerPort to controller.powerPort;
		connection powerDist2 : PowerPort connect mainPowerPort to headServo.powerPort;
		connection powerDist3 : PowerPort connect mainPowerPort to neckServo.powerPort;
		connection powerDist4 : PowerPort connect mainPowerPort to leftShoulderServo.powerPort;
		connection powerDist5 : PowerPort connect mainPowerPort to rightShoulderServo.powerPort;
		connection powerDist6 : PowerPort connect mainPowerPort to leftElbowServo.powerPort;
		connection powerDist7 : PowerPort connect mainPowerPort to rightElbowServo.powerPort;
		connection powerDist8 : PowerPort connect mainPowerPort to jawServo.powerPort;
		connection powerDist9 : PowerPort connect mainPowerPort to eyesServo.powerPort;
		connection powerDist10 : PowerPort connect mainPowerPort to proximitySensor1.powerPort;
		connection powerDist11 : PowerPort connect mainPowerPort to proximitySensor2.powerPort;
		connection powerDist12 : PowerPort connect mainPowerPort to speakerSystem.powerPort;
		
		connection motorCtrl1 : MotionControlPort connect controller.motorControl[1] to headServo.controlPort;
		connection motorCtrl2 : MotionControlPort connect controller.motorControl[2] to neckServo.controlPort;
		connection motorCtrl3 : MotionControlPort connect controller.motorControl[3] to leftShoulderServo.controlPort;
		connection motorCtrl4 : MotionControlPort connect controller.motorControl[4] to rightShoulderServo.controlPort;
		connection motorCtrl5 : MotionControlPort connect controller.motorControl[5] to leftElbowServo.controlPort;
		connection motorCtrl6 : MotionControlPort connect controller.motorControl[6] to rightElbowServo.controlPort;
		connection motorCtrl7 : MotionControlPort connect controller.motorControl[7] to jawServo.controlPort;
		connection motorCtrl8 : MotionControlPort connect controller.motorControl[8] to eyesServo.controlPort;
		
		connection audioCtrl : AudioControlPort connect controller.audioControl to speakerSystem.audioPort;
		connection sensorInput1 : SensorPort connect proximitySensor1.sensorPort to controller.sensorInput;
		connection sensorInput2 : SensorPort connect proximitySensor2.sensorPort to controller.sensorInput;
		
		perform action operateCharacter {
			first start;
			then merge monitoringLoop;
			
			then action detectVisitor : DetectVisitorPresence {
				out visitorDetected : Boolean;
				out detectionDistance : ISQ::LengthValue;
			}
			
			then decide;
				if detectVisitor.visitorDetected then selectAnimation;
				if not detectVisitor.visitorDetected then monitoringLoop;
			
			action selectAnimation : SelectAnimationSequence {
				in distance = detectVisitor.detectionDistance;
				out selectedSequenceId : Integer;
			}
			
			then action performAnimation : controller.ExecutePerformance {
				in sequenceId = selectAnimation.selectedSequenceId;
				out feedbackData;
			}
			
			then action resetPosition : ResetToNeutral;
			
			then monitoringLoop;
		}
		
		action def DetectVisitorPresence {
			out visitorDetected : Boolean;
			out detectionDistance : ISQ::LengthValue;
			
			first start;
			then assign visitorDetected := true;
			then assign detectionDistance := 1.8 [SI::m];
			then done;
		}
		
		action def SelectAnimationSequence {
			in distance : ISQ::LengthValue;
			out selectedSequenceId : Integer;
			
			first start;
			then decide;
				if distance < 1.0 [SI::m] then assignClose;
				if distance >= 1.0 [SI::m] then assignFar;
			
			action assignClose {
				first start;
				then assign selectedSequenceId := 5;
				then done;
			}
			
			action assignFar {
				first start;
				then assign selectedSequenceId := 3;
				then done;
			}
			
			then done;
		}
		
		action def ResetToNeutral {
			first start;
			then done;
		}
		
		exhibit state operationalBehavior : AnimatronicOperationalState;
	}
	
	requirement def MotionPrecisionRequirement {
		doc /* The animatronic character shall achieve precise joint positioning for realistic movement. */
		
		require constraint positionAccuracy {
			doc /* Joint positioning accuracy shall be within 1.5 degrees of commanded angle. */
		}
		
		require constraint responseLatency {
			doc /* Motion commands shall be executed within 150 milliseconds of receipt. */
		}
	}
	
	requirement def AudioSynchronizationRequirement {
		doc /* The animatronic character shall synchronize audio playback with physical movements. */
		
		require constraint timingPrecision {
			doc /* Audio and motion synchronization shall be maintained within 40 milliseconds. */
		}
		
		require constraint audioQuality {
			doc /* Audio playback shall maintain clarity across the full frequency range. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The animatronic character shall operate safely in public interactive environments. */
		
		require constraint torqueLimit {
			doc /* Actuator torque shall not exceed 80% of maximum rated torque during normal operation. */
		}
		
		require constraint emergencyStop {
			doc /* System shall support immediate emergency stop with motion halt within 500 milliseconds. */
		}
		
		require constraint obstacleAvoidance {
			doc /* System shall detect unexpected obstacles and halt motion to prevent contact. */
		}
		
		require constraint thermalProtection {
			doc /* System shall monitor component temperatures and reduce operation if limits are approached. */
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The animatronic character shall operate reliably for extended operational periods. */
		
		require constraint operationalCycles {
			doc /* System shall complete minimum 15,000 animation cycles without mechanical failure. */
		}
		
		require constraint powerStability {
			doc /* System shall maintain stable operation across voltage variations of +/- 10%. */
		}
		
		require constraint maintenanceInterval {
			doc /* System shall operate for minimum 500 hours between scheduled maintenance. */
		}
	}
	
	requirement <'ANIM-SYS-001'> primaryFunctionRequirement {
		doc /* 
		The animatronic character system shall autonomously detect the presence and proximity 
		of visitors using integrated sensors, then execute pre-programmed lifelike animation 
		sequences that combine coordinated multi-joint servo motion with synchronized audio 
		playback to create engaging, realistic, and interactive entertainment experiences 
		in theme parks, museums, and public exhibition spaces.
		*/
		
		subject character : AnimatronicCharacter;
		
		assume constraint operatingEnvironment {
			doc /* System operates in controlled indoor environment with stable power supply and ambient temperature between 288K and 303K. */
		}
		
		assume constraint visitorBehavior {
			doc /* Visitors approach within sensor detection range and remain within performance area during animation sequences. */
		}
		
		require motionPrecisionRequirement : MotionPrecisionRequirement;
		require audioSyncRequirement : AudioSynchronizationRequirement;
		require safetyRequirement : SafetyRequirement;
		require reliabilityRequirement : ReliabilityRequirement;
	}
	
	part animatronicSystem : AnimatronicCharacter {
		attribute :>> characterName = "InteractiveCharacter-Alpha";
		attribute :>> totalMass = 45.0 [SI::kg];
		attribute :>> heightDimension = 1.75 [SI::m];
		attribute :>> operatingVoltage = 24.0 [SI::V];
		attribute :>> maxPowerDraw = 600.0 [SI::W];
		
		satisfy primaryFunctionRequirement;
	}
}
