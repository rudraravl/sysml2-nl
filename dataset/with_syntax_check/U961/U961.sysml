package ActuatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* 
	This model describes an electromechanical actuator system that converts electrical control signals 
	into precise mechanical motion. The system's primary function is to receive position or force commands, 
	process them through a feedback control loop, drive an electric motor, and produce controlled linear 
	or rotary mechanical output while continuously monitoring performance and maintaining accuracy.
	*/
	
	attribute def CommandSignal;
	attribute def FaultCode;
	
	item def ElectricalPower {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def MechanicalOutput {
		attribute force : ISQ::ForceValue;
		attribute position : ISQ::LengthValue;
		attribute velocity : ISQ::SpeedValue;
	}
	
	item def SensorData {
		attribute measuredPosition : ISQ::LengthValue;
		attribute measuredForce : ISQ::ForceValue;
		attribute timestamp : Real;
	}
	
	port def CommandPort {
		in attribute targetPosition : ISQ::LengthValue;
		in attribute targetForce : ISQ::ForceValue;
		in attribute commandMode : CommandSignal;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : ISQ::VoltageValue;
		in attribute supplyCurrent : ISQ::ElectricCurrentValue;
	}
	
	port def OutputPort {
		out attribute outputForce : ISQ::ForceValue;
		out attribute outputPosition : ISQ::LengthValue;
		out attribute outputVelocity : ISQ::SpeedValue;
	}
	
	port def FeedbackPort {
		out attribute positionFeedback : ISQ::LengthValue;
		out attribute forceFeedback : ISQ::ForceValue;
		out attribute statusCode : FaultCode;
	}
	
	part def ControlProcessor {
		in attribute commandedPosition : ISQ::LengthValue;
		in attribute currentPosition : ISQ::LengthValue;
		in attribute commandedForce : ISQ::ForceValue;
		in attribute currentForce : ISQ::ForceValue;
		out attribute controlVoltage : ISQ::VoltageValue;
		
		attribute proportionalGain : Real;
		attribute integralGain : Real;
		attribute derivativeGain : Real;
		attribute errorIntegral : Real;
		attribute previousError : Real;
		attribute controlMode : String;
	}
	
	part def PowerAmplifier {
		in attribute controlSignal : ISQ::VoltageValue;
		in attribute inputPower : ElectricalPower;
		out attribute motorVoltage : ISQ::VoltageValue;
		out attribute motorCurrent : ISQ::ElectricCurrentValue;
		
		attribute amplificationFactor : Real;
		attribute maxOutputCurrent : ISQ::ElectricCurrentValue;
		attribute efficiency : Real;
	}
	
	part def ElectricMotor {
		in attribute appliedVoltage : ISQ::VoltageValue;
		in attribute appliedCurrent : ISQ::ElectricCurrentValue;
		out attribute outputTorque : ISQ::TorqueValue;
		out attribute rotationalSpeed : ISQ::AngularVelocityValue;
		
		attribute torqueConstant : Real;
		attribute backEmfConstant : Real;
		attribute windingResistance : Real;
		attribute rotorInertia : Real;
	}
	
	part def TransmissionMechanism {
		in attribute inputTorque : ISQ::TorqueValue;
		in attribute inputSpeed : ISQ::AngularVelocityValue;
		out attribute outputForce : ISQ::ForceValue;
		out attribute outputVelocity : ISQ::SpeedValue;
		out attribute outputPosition : ISQ::LengthValue;
		
		attribute mechanicalAdvantage : Real;
		attribute efficiency : Real;
		attribute backlash : ISQ::LengthValue;
	}
	
	part def PositionSensor {
		in attribute actualPosition : ISQ::LengthValue;
		out attribute sensedPosition : ISQ::LengthValue;
		out attribute sensorHealth : FaultCode;
		
		attribute resolution : ISQ::LengthValue;
		attribute accuracy : Real;
		attribute sampleRate : ISQ::FrequencyValue;
	}
	
	part def ForceSensor {
		in attribute actualForce : ISQ::ForceValue;
		out attribute sensedForce : ISQ::ForceValue;
		
		attribute sensitivity : Real;
		attribute maxMeasurableForce : ISQ::ForceValue;
		attribute noiseLevel : ISQ::ForceValue;
	}
	
	action def ComputePIDControl {
		in attribute setpoint : ISQ::LengthValue;
		in attribute measurement : ISQ::LengthValue;
		in attribute kp : Real;
		in attribute ki : Real;
		in attribute kd : Real;
		in attribute integralSum : Real;
		in attribute lastError : Real;
		in attribute deltaTime : Real;
		out attribute controlOutput : ISQ::VoltageValue;
		out attribute newIntegralSum : Real;
		out attribute newLastError : Real;
	}
	
	action def AmplifySignal {
		in attribute inputSignal : ISQ::VoltageValue;
		in attribute powerSource : ElectricalPower;
		in attribute gain : Real;
		out attribute amplifiedVoltage : ISQ::VoltageValue;
		out attribute outputCurrent : ISQ::ElectricCurrentValue;
	}
	
	action def ConvertElectricalToMechanical {
		in attribute voltage : ISQ::VoltageValue;
		in attribute current : ISQ::ElectricCurrentValue;
		in attribute motorConstant : Real;
		out attribute torque : ISQ::TorqueValue;
		out attribute angularVelocity : ISQ::AngularVelocityValue;
	}
	
	action def TransformMotion {
		in attribute inputTorque : ISQ::TorqueValue;
		in attribute inputAngularVelocity : ISQ::AngularVelocityValue;
		in attribute gearRatio : Real;
		out attribute linearForce : ISQ::ForceValue;
		out attribute linearVelocity : ISQ::SpeedValue;
		out attribute linearPosition : ISQ::LengthValue;
	}
	
	action def MeasurePosition {
		in attribute mechanicalPosition : ISQ::LengthValue;
		in attribute sensorResolution : ISQ::LengthValue;
		out attribute digitalReading : ISQ::LengthValue;
	}
	
	action def ActuatorControlCycle {
		in attribute targetPos : ISQ::LengthValue;
		in attribute targetForce : ISQ::ForceValue;
		in attribute powerSupply : ElectricalPower;
		out attribute mechanicalForce : ISQ::ForceValue;
		out attribute mechanicalPosition : ISQ::LengthValue;
		out attribute mechanicalVelocity : ISQ::SpeedValue;
		out attribute feedbackData : SensorData;
		
		attribute cycleTime : Real;
		attribute currentPos : ISQ::LengthValue;
		attribute currentForce : ISQ::ForceValue;
		
		first start;
		then merge controlLoop;
		then action acquireCommand {
			in target = targetPos;
			out commandValue : ISQ::LengthValue;
		}
		then action senseCurrentState : MeasurePosition {
			in mechanicalPosition = currentPos;
			out digitalReading;
		}
		then action calculateControl : ComputePIDControl {
			in setpoint = acquireCommand.commandValue;
			in measurement = senseCurrentState.digitalReading;
			out controlOutput;
		}
		then action amplifyControl : AmplifySignal {
			in inputSignal = calculateControl.controlOutput;
			in powerSource = powerSupply;
			out amplifiedVoltage;
			out outputCurrent;
		}
		then action driveMotor : ConvertElectricalToMechanical {
			in voltage = amplifyControl.amplifiedVoltage;
			in current = amplifyControl.outputCurrent;
			out torque;
			out angularVelocity;
		}
		then action convertToLinear : TransformMotion {
			in inputTorque = driveMotor.torque;
			in inputAngularVelocity = driveMotor.angularVelocity;
			out linearForce;
			out linearVelocity;
			out linearPosition;
		}
		then assign mechanicalForce := convertToLinear.linearForce;
		then assign mechanicalPosition := convertToLinear.linearPosition;
		then assign mechanicalVelocity := convertToLinear.linearVelocity;
		then assign currentPos := mechanicalPosition;
		then assign currentForce := mechanicalForce;
		then controlLoop;
	}
	
	part def LinearActuator {
		attribute maxStroke : ISQ::LengthValue;
		attribute maxForce : ISQ::ForceValue;
		attribute maxVelocity : ISQ::SpeedValue;
		attribute nominalVoltage : ISQ::VoltageValue;
		attribute positionAccuracy : ISQ::LengthValue;
		attribute responseTime : Real;
		attribute systemStatus : String;
		
		port cmdPort : CommandPort;
		port pwrPort : PowerPort;
		port outPort : OutputPort;
		port fbPort : FeedbackPort;
		
		part controller : ControlProcessor {
			in attribute commandedPosition = cmdPort.targetPosition;
			in attribute currentPosition = positionSensor.sensedPosition;
			in attribute commandedForce = cmdPort.targetForce;
			in attribute currentForce = forceSensor.sensedForce;
			out attribute controlVoltage;
			
			attribute :>> proportionalGain = 5.0;
			attribute :>> integralGain = 1.2;
			attribute :>> derivativeGain = 0.8;
		}
		
		part amplifier : PowerAmplifier {
			in attribute controlSignal = controller.controlVoltage;
			in attribute inputPower {
				attribute voltage = pwrPort.supplyVoltage;
				attribute current = pwrPort.supplyCurrent;
			}
			out attribute motorVoltage;
			out attribute motorCurrent;
			
			attribute :>> amplificationFactor = 10.0;
			attribute :>> efficiency = 0.92;
		}
		
		part motor : ElectricMotor {
			in attribute appliedVoltage = amplifier.motorVoltage;
			in attribute appliedCurrent = amplifier.motorCurrent;
			out attribute outputTorque;
			out attribute rotationalSpeed;
			
			attribute :>> torqueConstant = 0.08;
			attribute :>> backEmfConstant = 0.08;
			attribute :>> windingResistance = 1.5;
		}
		
		part transmission : TransmissionMechanism {
			in attribute inputTorque = motor.outputTorque;
			in attribute inputSpeed = motor.rotationalSpeed;
			out attribute outputForce;
			out attribute outputVelocity;
			out attribute outputPosition;
			
			attribute :>> mechanicalAdvantage = 25.0;
			attribute :>> efficiency = 0.88;
		}
		
		part positionSensor : PositionSensor {
			in attribute actualPosition = transmission.outputPosition;
			out attribute sensedPosition;
			out attribute sensorHealth;
			
			attribute :>> resolution = 0.001[SI::mm];
			attribute :>> accuracy = 0.998;
		}
		
		part forceSensor : ForceSensor {
			in attribute actualForce = transmission.outputForce;
			out attribute sensedForce;
			
			attribute :>> sensitivity = 0.002;
		}
		
		connection controlFeedback connect positionSensor.sensedPosition to controller.currentPosition;
		connection forceFeedback connect forceSensor.sensedForce to controller.currentForce;
		connection controlToAmplifier connect controller.controlVoltage to amplifier.controlSignal;
		connection powerToAmplifier connect pwrPort to amplifier.inputPower;
		connection amplifierToMotor connect amplifier.motorVoltage to motor.appliedVoltage;
		connection motorToTransmission connect motor.outputTorque to transmission.inputTorque;
		connection transmissionToPositionSensor connect transmission.outputPosition to positionSensor.actualPosition;
		connection transmissionToForceSensor connect transmission.outputForce to forceSensor.actualForce;
		connection positionOutput connect positionSensor.sensedPosition to fbPort.positionFeedback;
		connection forceOutput connect forceSensor.sensedForce to fbPort.forceFeedback;
		connection mechanicalOutput connect transmission.outputForce to outPort.outputForce;
		
		perform action operate : ActuatorControlCycle {
			in targetPos = cmdPort.targetPosition;
			in targetForce = cmdPort.targetForce;
			in powerSupply {
				attribute voltage = pwrPort.supplyVoltage;
				attribute current = pwrPort.supplyCurrent;
			}
			out mechanicalForce;
			out mechanicalPosition;
			out mechanicalVelocity;
		}
		
		state actuatorBehavior {
			entry; then initialize;
			
			state initialize {
				entry assign systemStatus := "Initializing";
			}
			accept powerOn;
			then ready;
			
			state ready {
				entry assign systemStatus := "Ready";
			}
			accept commandReceived;
			then operating;
			
			state operating {
				entry assign systemStatus := "Operating";
				do action executeControl : ActuatorControlCycle;
			}
			accept targetAchieved;
			then holding;
			accept faultDetected;
			then faulted;
			
			state holding {
				entry assign systemStatus := "Holding Position";
			}
			accept newCommandReceived;
			then operating;
			accept shutdown;
			then ready;
			
			state faulted {
				entry assign systemStatus := "Fault";
			}
			accept resetCommand;
			then initialize;
		}
	}
	
	part actuatorSystem : LinearActuator {
		attribute :>> maxStroke = 200.0[SI::mm];
		attribute :>> maxForce = 8000.0[SI::N];
		attribute :>> maxVelocity = 0.5[SI::'m/s'];
		attribute :>> nominalVoltage = 48.0[SI::V];
		attribute :>> positionAccuracy = 0.05[SI::mm];
		attribute :>> responseTime = 0.1;
	}
	
	requirement def ActuatorFunctionalRequirement {
		doc /* 
		The actuator system shall convert electrical command signals into precise mechanical motion 
		by processing position and force commands through a closed-loop feedback control system.
		*/
		
		subject actuatorSubject : LinearActuator;
		
		require constraint accuracyRequirement {
			actuatorSubject.positionAccuracy <= 0.1[SI::mm]
		}
		
		require constraint forceCapability {
			actuatorSubject.maxForce >= 5000.0[SI::N]
		}
		
		require constraint strokeRequirement {
			actuatorSubject.maxStroke >= 100.0[SI::mm]
		}
		
		require constraint velocityRequirement {
			actuatorSubject.maxVelocity >= 0.3[SI::'m/s']
		}
	}
	
	requirement <'ACT-REQ-001'> primaryActuatorFunction {
		doc /* 
		The actuator system shall receive electrical command signals specifying target position or force,
		process these commands through a PID feedback control loop that compares commanded values with 
		sensor measurements, amplify the control signal to drive an electric motor, convert the motor's 
		rotational motion into linear mechanical output through a transmission mechanism, and continuously 
		monitor position and force while maintaining commanded values within specified accuracy tolerances.
		*/
		
		subject primaryActuator : LinearActuator;
		
		assume constraint powerAvailability {
			primaryActuator.pwrPort.supplyVoltage >= 40.0[SI::V] and
			primaryActuator.pwrPort.supplyVoltage <= 56.0[SI::V]
		}
		
		require ActuatorFunctionalRequirement {
			subject actuatorSubject = primaryActuator;
		}
		
		require constraint responseTimeRequirement {
			doc /* The actuator shall achieve 90% of commanded position within specified response time. */
			primaryActuator.responseTime <= 0.2
		}
		
		require constraint stabilityRequirement {
			doc /* The control system shall maintain stable operation without oscillation. */
		}
		
		require constraint safetyRequirement {
			doc /* The actuator shall detect faults and enter safe state when anomalies occur. */
		}
	}
}
