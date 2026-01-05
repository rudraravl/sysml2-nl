package 'Window Blind System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BlindPositionPercent :> Real {
		doc /* Position of the blind from 0% (fully closed) to 100% (fully open). */
	}
	
	attribute def LightIntensityLevel :> Real {
		doc /* Ambient light intensity level measured in lux. */
	}
	
	attribute def UserCommand;
	attribute def RaiseCommand :> UserCommand;
	attribute def LowerCommand :> UserCommand;
	attribute def StopCommand :> UserCommand;
	
	port def PowerPort {
		in voltage : VoltageValue;
		in current : ElectricCurrentValue;
	}
	
	port def ControlSignalPort {
		in raiseSignal : RaiseCommand;
		in lowerSignal : LowerCommand;
		in stopSignal : StopCommand;
	}
	
	port def SensorPort {
		out lightLevel : LightIntensityLevel;
	}
	
	port def MechanicalPort {
		out torque : TorqueValue;
		in position : BlindPositionPercent;
	}
	
	part def ElectricMotor {
		attribute ratedPower : PowerValue;
		attribute maxTorque : TorqueValue;
		attribute operatingVoltage : VoltageValue;
		
		port powerIn : PowerPort;
		port controlIn : ControlSignalPort;
		port driveOut : MechanicalPort;
		
		action def GenerateTorque {
			in command : UserCommand;
			in voltage : VoltageValue;
			out outputTorque : TorqueValue;
		}
	}
	
	part def SlatAssembly {
		attribute numberOfSlats : Integer;
		attribute slatWidth : LengthValue;
		attribute slatThickness : LengthValue;
		attribute totalLength : LengthValue;
		
		port mechanicalIn : MechanicalPort;
		port lightTransmission {
			in incidentLight : LightIntensityLevel;
			out transmittedLight : LightIntensityLevel;
		}
		
		action def AdjustSlatAngle {
			in appliedTorque : TorqueValue;
			out newPosition : BlindPositionPercent;
		}
	}
	
	part def LiftMechanism {
		attribute cordDiameter : LengthValue;
		attribute drumDiameter : LengthValue;
		attribute gearRatio : Real;
		
		port motorConnection {
			in driveTorque : TorqueValue;
		}
		port slatConnection {
			out liftForce : ForceValue;
			in currentHeight : LengthValue;
		}
		
		action def TransmitMotion {
			in inputTorque : TorqueValue;
			out outputForce : ForceValue;
		}
	}
	
	part def AmbientLightSensor {
		attribute sensorType : String;
		attribute measurementRange : LightIntensityLevel;
		attribute accuracy : Real;
		
		port powerIn : PowerPort;
		port dataOut : SensorPort;
		
		action def MeasureLight {
			out detectedLevel : LightIntensityLevel;
		}
	}
	
	part def ControllerUnit {
		attribute processorSpeed : FrequencyValue;
		attribute memoryCapacity : Integer;
		
		port powerIn : PowerPort;
		port userInput : ControlSignalPort;
		port sensorInput : SensorPort;
		port motorCommand : ControlSignalPort;
		port positionFeedback {
			in currentPosition : BlindPositionPercent;
		}
		
		attribute targetPosition : BlindPositionPercent;
		attribute lightThreshold : LightIntensityLevel;
		
		action def ProcessInputs {
			in userCmd : UserCommand;
			in lightReading : LightIntensityLevel;
			in currentPos : BlindPositionPercent;
			out motorCmd : UserCommand;
		}
	}
	
	part def PowerSupply {
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : ElectricCurrentValue;
		
		port acInput {
			in voltage : VoltageValue;
		}
		port dcOutput : PowerPort;
		
		action def ConvertPower {
			in acVoltage : VoltageValue;
			out dcVoltage : VoltageValue;
			out dcCurrent : ElectricCurrentValue;
		}
	}
	
	part def WindowBlindSystem {
		doc /* Automated window blind system that regulates interior lighting by adjusting blind position. */
	}
	
	part windowBlindSystem : WindowBlindSystem {
		doc /* Complete automated window blind system for light control. */
		
		part powerSupply : PowerSupply {
			attribute :>> inputVoltage = 120.0 [V];
			attribute :>> outputVoltage = 12.0 [V];
			attribute :>> maxCurrent = 2.0 [A];
		}
		
		part controller : ControllerUnit {
			attribute :>> processorSpeed = 16.0e6 [Hz];
			attribute :>> memoryCapacity = 256;
			attribute :>> lightThreshold = 500.0;
		}
		
		part motor : ElectricMotor {
			attribute :>> ratedPower = 24.0 [W];
			attribute :>> maxTorque = 1.5 [N * m];
			attribute :>> operatingVoltage = 12.0 [V];
		}
		
		part liftMechanism : LiftMechanism {
			attribute :>> cordDiameter = 0.002 [m];
			attribute :>> drumDiameter = 0.025 [m];
			attribute :>> gearRatio = 10.0;
		}
		
		part slats : SlatAssembly {
			attribute :>> numberOfSlats = 25;
			attribute :>> slatWidth = 0.05 [m];
			attribute :>> slatThickness = 0.001 [m];
			attribute :>> totalLength = 1.5 [m];
		}
		
		part lightSensor : AmbientLightSensor {
			attribute :>> sensorType = "Photodiode";
			attribute :>> measurementRange = 1000.0;
			attribute :>> accuracy = 0.98;
		}
		
		connect powerSupply.dcOutput to controller.powerIn;
		connect powerSupply.dcOutput to motor.powerIn;
		connect powerSupply.dcOutput to lightSensor.powerIn;
		connect controller.motorCommand to motor.controlIn;
		connect motor.driveOut to liftMechanism.motorConnection;
		connect liftMechanism.slatConnection to slats.mechanicalIn;
		connect lightSensor.dataOut to controller.sensorInput;
		
		perform action operateBlind;
	}
	
	action def MonitorAmbientLight {
		out measuredLight : LightIntensityLevel;
	}
	
	action def DetermineDesiredPosition {
		in lightLevel : LightIntensityLevel;
		in userInput : UserCommand;
		in threshold : LightIntensityLevel;
		out targetPos : BlindPositionPercent;
	}
	
	action def CommandMotor {
		in targetPosition : BlindPositionPercent;
		in currentPosition : BlindPositionPercent;
		out motorCommand : UserCommand;
	}
	
	action def UpdateBlindPosition {
		in motorTorque : TorqueValue;
		out newPosition : BlindPositionPercent;
	}
	
	action operateBlind {
		doc /* Main operational behavior for automated blind control. */
		
		first start;
		then merge controlLoop;
		
		action monitorLight : MonitorAmbientLight {
			out ambientLevel : LightIntensityLevel;
		}
		
		then action determinePosition : DetermineDesiredPosition {
			in lightLevel = monitorLight.ambientLevel;
			in userInput;
			in threshold = 500.0;
			out desiredPosition : BlindPositionPercent;
		}
		
		then decide;
			if determinePosition.desiredPosition > currentBlindPosition then raiseBlind;
			if determinePosition.desiredPosition < currentBlindPosition then lowerBlind;
			if determinePosition.desiredPosition == currentBlindPosition then maintainPosition;
		
		action raiseBlind : CommandMotor {
			in targetPosition = determinePosition.desiredPosition;
			in currentPosition = currentBlindPosition;
			out motorCommand;
		}
		then action updateRaised : UpdateBlindPosition {
			in motorTorque;
			out newPosition;
		}
		then assign currentBlindPosition := updateRaised.newPosition;
		then controlLoop;
		
		action lowerBlind : CommandMotor {
			in targetPosition = determinePosition.desiredPosition;
			in currentPosition = currentBlindPosition;
			out motorCommand;
		}
		then action updateLowered : UpdateBlindPosition {
			in motorTorque;
			out newPosition;
		}
		then assign currentBlindPosition := updateLowered.newPosition;
		then controlLoop;
		
		action maintainPosition;
		then controlLoop;
		
		private attribute currentBlindPosition : BlindPositionPercent := 50.0;
	}
	
	state def BlindOperationalStates {
		doc /* State machine defining operational modes of the blind system. */
		
		entry; then idle;
		
		state idle {
			doc /* Blind is stationary, awaiting command. */
		}
		accept raiseCmd : RaiseCommand
			then raising;
		accept lowerCmd : LowerCommand
			then lowering;
		
		state raising {
			doc /* Blind is moving upward to increase light. */
			entry action activateMotorUp;
			do action monitorUpperLimit;
		}
		accept stopCmd : StopCommand
			then idle;
		accept reachedUpperLimit
			then idle;
		
		state lowering {
			doc /* Blind is moving downward to reduce light. */
			entry action activateMotorDown;
			do action monitorLowerLimit;
		}
		accept stopCmd : StopCommand
			then idle;
		accept reachedLowerLimit
			then idle;
	}
	
	requirement <'WBS-REQ-001'> primaryFunctionRequirement {
		doc /* The window blind system shall control the amount of natural light entering 
		       an interior space by adjusting the position and orientation of horizontal slats. */
		
		subject windowBlindSystem;
		
		require constraint lightControlCapability {
			doc /* The system shall be capable of varying light transmission from 5% (fully closed) 
			       to 95% (fully open) of incident light. */
		}
		
		require constraint positionControl {
			doc /* The blind position shall be adjustable in increments of 5% across the full range. */
		}
		
		require constraint responseTime {
			doc /* The system shall respond to user commands within 300 milliseconds. */
		}
	}
	
	requirement <'WBS-REQ-002'> automationRequirement {
		doc /* The window blind system shall provide automatic light level regulation. */
		
		assume constraint sensorAvailability {
			doc /* A calibrated ambient light sensor is installed and operational. */
		}
		
		require primaryFunctionRequirement;
		
		require constraint automaticAdjustment {
			doc /* The system shall automatically adjust blind position to maintain interior 
			       light levels within 10% of user-defined target when in automatic mode. */
		}
		
		require constraint manualOverride {
			doc /* User manual commands shall override automatic operation immediately. */
		}
	}
	
	requirement <'WBS-REQ-003'> safetyRequirement {
		doc /* The window blind system shall operate safely without causing injury or damage. */
		
		require constraint obstructionDetection {
			doc /* The system shall detect obstructions and stop movement within 100 milliseconds. */
		}
		
		require constraint torqueLimiting {
			doc /* Motor torque shall be limited to prevent cord breakage or mechanism damage. */
		}
		
		require constraint thermalProtection {
			doc /* The motor shall include thermal overload protection to prevent overheating. */
		}
	}
	
	requirement <'WBS-REQ-004'> performanceRequirement {
		doc /* The window blind system shall meet specified performance criteria. */
		
		require constraint fullTravelTime {
			doc /* The blind shall traverse from fully open to fully closed in no more than 15 seconds. */
		}
		
		require constraint positionAccuracy {
			doc /* The blind position shall be maintained within ±2% of commanded position. */
		}
		
		require constraint operatingCycles {
			doc /* The system shall be capable of at least 50,000 full travel cycles. */
		}
	}
	
	requirement <'WBS-REQ-005'> systemIntegrationRequirement {
		doc /* The window blind system shall integrate with building automation systems. */
		
		require primaryFunctionRequirement;
		require automationRequirement;
		
		require constraint communicationInterface {
			doc /* The system shall provide a standard communication interface for external control. */
		}
		
		require constraint statusReporting {
			doc /* The system shall report current position and operational status on request. */
		}
	}
}
