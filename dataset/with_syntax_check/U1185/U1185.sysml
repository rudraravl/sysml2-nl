package 'Robotic Fin System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FinAngle :> ISQ::PlaneAngleValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit[1] = SI::deg;
	}
	
	attribute def TorqueValue :> ISQ::TorqueValue {
		attribute :>> num : Real;
		attribute :>> mRef : TorqueUnit[1] = SI::'N*m';
	}
	
	attribute def AngularVelocityValue :> ISQ::AngularVelocityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularVelocityUnit[1] = SI::'rad/s';
	}
	
	attribute def ForceValue :> ISQ::ForceValue {
		attribute :>> num : Real;
		attribute :>> mRef : ForceUnit[1] = SI::N;
	}
	
	attribute def FrequencyValue :> ISQ::FrequencyValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit[1] = SI::Hz;
	}
	
	item def ControlSignal {
		attribute targetAngle : FinAngle;
		attribute targetVelocity : AngularVelocityValue;
		attribute oscillationFrequency : FrequencyValue;
	}
	
	item def SensorData {
		attribute currentAngle : FinAngle;
		attribute currentVelocity : AngularVelocityValue;
		attribute fluidPressure : ISQ::PressureValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def ActuatorCommand {
		attribute torque : TorqueValue;
		attribute direction : Integer;
	}
	
	item def ThrustOutput {
		attribute force : ForceValue;
		attribute efficiency : Real;
	}
	
	port def ControlPort {
		in item controlInput : ControlSignal;
		out item sensorFeedback : SensorData;
	}
	
	port def ActuatorPort {
		in item command : ActuatorCommand;
		out item status : SensorData;
	}
	
	port def FluidInteractionPort {
		out item thrustForce : ThrustOutput;
		in item fluidResistance : ForceValue;
	}
	
	port def PowerPort {
		in item powerSupply : ISQ::PowerValue;
	}
	
	part def Motor {
		attribute maxTorque : TorqueValue;
		attribute efficiency : Real;
		attribute ratedPower : ISQ::PowerValue;
		
		port actuatorPort : ActuatorPort;
		port powerPort : PowerPort;
		
		action def GenerateTorque {
			in commandedTorque : TorqueValue;
			in availablePower : ISQ::PowerValue;
			out outputTorque : TorqueValue;
		}
	}
	
	part def AngleSensor {
		attribute resolution : FinAngle;
		attribute sampleRate : FrequencyValue;
		attribute accuracy : FinAngle;
		
		action def MeasureAngle {
			in physicalAngle : FinAngle;
			out sensedAngle : FinAngle;
			out velocity : AngularVelocityValue;
		}
	}
	
	part def FinBlade {
		attribute surfaceArea : ISQ::AreaValue;
		attribute flexuralRigidity : Real;
		attribute currentAngle : FinAngle;
		attribute mass : ISQ::MassValue;
		
		port fluidPort : FluidInteractionPort;
		
		action def GenerateThrust {
			in angle : FinAngle;
			in velocity : AngularVelocityValue;
			in fluidDensity : ISQ::DensityValue;
			out thrust : ThrustOutput;
		}
	}
	
	part def FinController {
		attribute controlGain : Real;
		attribute maxAngleRate : AngularVelocityValue;
		attribute integralGain : Real;
		attribute derivativeGain : Real;
		
		port controlPort : ControlPort;
		
		action def ComputeControl {
			in targetAngle : FinAngle;
			in currentAngle : FinAngle;
			in currentVelocity : AngularVelocityValue;
			out actuatorCommand : ActuatorCommand;
		}
		
		state def ControlStateMachine {
			entry; then idle;
			
			state idle {
				entry assign controlPort.sensorFeedback.currentAngle := 0.0;
			}
			
			transition idle_to_initializing
				first idle
				accept controlPort.controlInput
				then initializing;
			
			state initializing {
				do action calibrateAction {
					out calibrationComplete : Boolean;
				}
			}
			
			transition initializing_to_active
				first initializing
				if initializing.calibrateAction.calibrationComplete == true
				then active;
			
			state active {
				do action controlLoop : ComputeControl {
					in targetAngle = controlPort.controlInput.targetAngle;
					in currentAngle = controlPort.sensorFeedback.currentAngle;
					in currentVelocity = controlPort.sensorFeedback.currentVelocity;
					out actuatorCommand;
				}
			}
			
			transition active_to_idle
				first active
				if controlPort.controlInput.targetAngle == 0.0
				then idle;
			
			transition active_to_active
				first active
				accept controlPort.sensorFeedback
				then active;
		}
	}
	
	part def RoboticFin {
		attribute operatingDepth : ISQ::LengthValue;
		attribute maxDeflection : FinAngle;
		attribute totalMass : ISQ::MassValue;
		
		port externalControl : ControlPort;
		port thrustOutput : FluidInteractionPort;
		port powerInput : PowerPort;
		
		part controller : FinController {
			attribute :>> controlGain = 1.5;
			attribute :>> maxAngleRate = 90.0;
			attribute :>> integralGain = 0.3;
			attribute :>> derivativeGain = 0.1;
		}
		
		part motor : Motor {
			attribute :>> maxTorque = 5.0;
			attribute :>> efficiency = 0.85;
			attribute :>> ratedPower = 50.0;
		}
		
		part sensor : AngleSensor {
			attribute :>> resolution = 0.1;
			attribute :>> sampleRate = 100.0;
			attribute :>> accuracy = 0.5;
		}
		
		part blade : FinBlade {
			attribute :>> surfaceArea = 0.025;
			attribute :>> flexuralRigidity = 150.0;
			attribute :>> mass = 0.8;
		}
		
		binding externalControl = controller.controlPort;
		binding thrustOutput = blade.fluidPort;
		binding powerInput = motor.powerPort;
		
		interface motorToBlade connect motor.actuatorPort to blade;
		interface sensorToController connect sensor to controller.controlPort;
		interface bladeToSensor connect blade to sensor;
		interface controllerToMotor connect controller to motor.actuatorPort;
	}
	
	action def OscillateFinAction {
		in frequency : FrequencyValue;
		in amplitude : FinAngle;
		in duration : ISQ::TimeValue;
		out thrustGenerated : ForceValue;
		
		first start;
		then merge cycleStart;
		then action generateCommand {
			in freq = frequency;
			in amp = amplitude;
			out signal : ControlSignal;
		}
		then action applyCommand {
			in command = generateCommand.signal;
		}
		then action measureThrust {
			out thrust : ForceValue;
		}
		then decide;
			if measureThrust.thrust > 0.0 then continueOscillation;
			if measureThrust.thrust <= 0.0 then stopOscillation;
		action continueOscillation;
		then cycleStart;
		action stopOscillation;
		then done;
	}
	
	part roboticFinSystem : RoboticFin {
		attribute :>> operatingDepth = 10.0;
		attribute :>> maxDeflection = 45.0;
		attribute :>> totalMass = 2.5;
		
		perform action propulsionAction : OscillateFinAction {
			in frequency = 2.0;
			in amplitude = 30.0;
			in duration = 60.0;
			out thrustGenerated;
		}
	}
	
	requirement def PropulsionRequirement {
		doc /* The robotic fin shall generate sufficient thrust for underwater propulsion through controlled oscillatory motion. */
		
		subject roboticFin : RoboticFin;
		
		require constraint thrustCapability {
			roboticFin.thrustOutput.thrustForce.force >= 10.0
		}
	}
	
	requirement def ControlAccuracyRequirement {
		doc /* The fin controller shall maintain angular position within specified tolerance to ensure efficient thrust generation. */
		
		subject finController : FinController;
		
		attribute maxError : FinAngle = 2.0;
		
		require constraint positionAccuracy {
			abs(finController.controlPort.controlInput.targetAngle - 
			    finController.controlPort.sensorFeedback.currentAngle) <= maxError
		}
	}
	
	requirement def MassConstraint {
		doc /* The total mass of the robotic fin system shall not exceed the specified limit for integration into underwater vehicles. */
		
		subject fin : RoboticFin;
		
		require constraint massLimit {
			fin.totalMass <= 3.0
		}
	}
	
	requirement def SystemRequirements {
		doc /* Top-level requirements for the robotic fin system defining its primary function: to generate controlled propulsive thrust through biomimetic oscillatory motion. */
		
		require propulsionReq : PropulsionRequirement;
		require controlReq : ControlAccuracyRequirement;
		require massReq : MassConstraint;
		
		requirement def ResponseTimeRequirement {
			doc /* The system shall respond to control inputs within specified time to maintain stable oscillation. */
			
			attribute maxResponseTime : ISQ::TimeValue = 0.1;
		}
		
		requirement def EfficiencyRequirement {
			doc /* The system shall maintain minimum propulsive efficiency during continuous operation. */
			
			attribute minEfficiency : Real = 0.65;
		}
	}
	
	occurrence def FinOperationScenario {
		ref part fin : RoboticFin = roboticFinSystem;
		
		event occurrence commandReceived;
		then event occurrence controlComputed;
		then event occurrence motorActivated;
		then event occurrence bladeDeflected;
		then event occurrence thrustProduced;
		then event occurrence sensorFeedback;
		
		message controlMessage of ControlSignal
			from commandReceived to fin.controller.controlPort.controlInput;
		
		then message actuatorMessage of ActuatorCommand
			from fin.controller to fin.motor.actuatorPort.command;
		
		then message sensorMessage of SensorData
			from fin.sensor to fin.controller.controlPort.sensorFeedback;
		
		then message thrustMessage of ThrustOutput
			from fin.blade.fluidPort to thrustProduced;
	}
}
