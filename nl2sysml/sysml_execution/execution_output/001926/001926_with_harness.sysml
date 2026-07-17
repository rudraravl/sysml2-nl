package SegwayHTSystem {
    attribute def powerButtonPressed;
    attribute def selfTestPassed;
    attribute def selfTestFailed;
    attribute def riderDetected;
    attribute def riderLeans;
    attribute def riderDismounts;
    attribute def riderStopsLeaning;
    attribute def criticalError;
    attribute def systemReset;

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TiltAngle :> ISQ::PlaneAngleValue;
	attribute def AngularRate :> ISQ::AngularVelocityValue;
	attribute def TorqueValue :> ISQ::TorqueValue;
	attribute def RiderMass :> ISQ::MassValue;
	
	item def SensorReading {
		attribute pitchAngle : TiltAngle;
		attribute pitchRate : AngularRate;
		attribute forwardSpeed : ISQ::SpeedValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def MotorCommand {
		attribute leftWheelTorque : TorqueValue;
		attribute rightWheelTorque : TorqueValue;
	}
	
	item def RiderInput {
		attribute leanAngle : TiltAngle;
		attribute leanRate : AngularRate;
	}
	
	port def SensorPort {
		out reading : SensorReading;
	}
	
	port def MotorControlPort {
		in command : MotorCommand;
	}
	
	port def PowerPort {
		out voltage : ISQ::ElectricPotentialValue;
		out current : ISQ::ElectricCurrentValue;
	}
	
	port def RiderInterfacePort {
		in riderInput : RiderInput;
	}
	
	part def GyroscopeSensor {
		attribute sampleRate : ISQ::FrequencyValue;
		port sensorOut : SensorPort;
	}
	
	part def AccelerometerSensor {
		attribute sensitivity : Real;
		port sensorOut : SensorPort;
	}
	
	part def WheelSpeedSensor {
		port sensorOut : SensorPort;
	}
	
	part def BalanceController {
		attribute proportionalGain : Real;
		attribute derivativeGain : Real;
		attribute integralGain : Real;
		
		port sensorIn : SensorPort;
		port motorOut : MotorControlPort;
		port riderIn : RiderInterfacePort;
		port powerIn : PowerPort;
	}
	
	part def BrushlessMotor {
		attribute maxTorque : TorqueValue;
		attribute maxSpeed : ISQ::AngularVelocityValue;
		attribute efficiency : Real;
		
		port controlIn : MotorControlPort;
		port powerIn : PowerPort;
		port mechanicalOut;
	}
	
	part def Wheel {
		attribute diameter : ISQ::LengthValue;
		attribute width : ISQ::LengthValue;
		
		port driveIn;
	}
	
	part def BatteryPack {
		attribute nominalVoltage : ISQ::ElectricPotentialValue;
		attribute capacity : ISQ::EnergyValue;
		attribute currentCharge : ISQ::EnergyValue;
		attribute maxDischargeCurrent : ISQ::ElectricCurrentValue;
		
		port powerOut : PowerPort;
	}
	
	part def HandlebarAssembly {
		attribute height : ISQ::LengthValue;
		port riderOut : RiderInterfacePort;
	}
	
	part def PlatformFrame {
		attribute mass : ISQ::MassValue;
		attribute maxLoad : ISQ::MassValue;
	}
	
	action def ReadSensorData {
		out sensorData : SensorReading;
	}
	
	action def ComputeBalanceControl {
		in sensorData : SensorReading;
		in riderInput : RiderInput;
		in targetAngle : TiltAngle;
		out motorCmd : MotorCommand;
	}
	
	action def ApplyMotorTorque {
		in motorCmd : MotorCommand;
		out appliedTorque : TorqueValue;
	}
	
	action def BalanceLoop {
		first start;
		then merge continueBalancing;
		
		then action readSensors : ReadSensorData {
			out currentData : SensorReading;
		}
		
		then action computeControl : ComputeBalanceControl {
			in sensorData = readSensors.currentData;
			in riderInput;
			in targetAngle;
			out controlCommand : MotorCommand;
		}
		
		then action applyTorque : ApplyMotorTorque {
			in motorCmd = computeControl.controlCommand;
			out torque : TorqueValue;
		}
		
		then continueBalancing;
	}
	
	action def MoveForward {
		in desiredSpeed : ISQ::SpeedValue;
		in currentSpeed : ISQ::SpeedValue;
		out adjustedTorque : TorqueValue;
	}
	
	action def Turn {
		in turnRate : AngularRate;
		out leftTorque : TorqueValue;
		out rightTorque : TorqueValue;
	}
	
	state def SegwayOperationalStates {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_initialization
			first powerOff
			accept powerButtonPressed
			then initialization;
		
		state initialization {
			do action selfTest;
		}
		
		transition initialization_to_standby
			first initialization
			accept selfTestPassed
			then standby;
		
		transition initialization_to_fault
			first initialization
			accept selfTestFailed
			then fault;
		
		state standby;
		
		transition standby_to_balancing
			first standby
			accept riderDetected
			then balancing;
		
		state balancing {
			do action balanceLoop : BalanceLoop;
		}
		
		transition balancing_to_moving
			first balancing
			accept riderLeans
			then moving;
		
		transition balancing_to_standby
			first balancing
			accept riderDismounts
			then standby;
		
		state moving {
			do action balanceLoop : BalanceLoop;
			do action moveForward : MoveForward;
			do action turn : Turn;
		}
		
		transition moving_to_balancing
			first moving
			accept riderStopsLeaning
			then balancing;
		
		transition moving_to_standby
			first moving
			accept riderDismounts
			then standby;
		
		transition any_to_fault
			first balancing
			accept criticalError
			then fault;
		
		state fault;
		
		transition fault_to_powerOff
			first fault
			accept systemReset
			then powerOff;
	}
	
	part segwayHT {
		attribute systemPower : ISQ::PowerValue;
		attribute totalMass : ISQ::MassValue;
		attribute maxRiderMass : RiderMass;
		
		perform action maintainBalance[*] ordered references BalanceLoop;
		exhibit state operationalStates : SegwayOperationalStates;
		
		part frame : PlatformFrame {
			attribute :>> mass = 23.0 [kg];
			attribute :>> maxLoad = 118.0 [kg];
		}
		
		part gyroscope : GyroscopeSensor {
			attribute :>> sampleRate = 100.0 [Hz];
			port :>> sensorOut;
		}
		
		part accelerometer : AccelerometerSensor {
			attribute :>> sensitivity = 0.001;
			port :>> sensorOut;
		}
		
		part speedSensor : WheelSpeedSensor {
			port :>> sensorOut;
		}
		
		part controller : BalanceController {
			attribute :>> proportionalGain = 50.0;
			attribute :>> derivativeGain = 20.0;
			attribute :>> integralGain = 5.0;
			
			port :>> sensorIn;
			port :>> motorOut;
			port :>> riderIn;
			port :>> powerIn;
			
			perform maintainBalance.computeControl;
		}
		
		part leftMotor : BrushlessMotor {
			attribute :>> maxTorque = 80.0 [N*m];
			attribute :>> maxSpeed = 1000.0 [rpm];
			attribute :>> efficiency = 0.92;
			
			port :>> controlIn;
			port :>> powerIn;
			port :>> mechanicalOut;
			
			perform maintainBalance.applyTorque;
		}
		
		part rightMotor : BrushlessMotor {
			attribute :>> maxTorque = 80.0 [N*m];
			attribute :>> maxSpeed = 1000.0 [rpm];
			attribute :>> efficiency = 0.92;
			
			port :>> controlIn;
			port :>> powerIn;
			port :>> mechanicalOut;
			
			perform maintainBalance.applyTorque;
		}
		
		part leftWheel : Wheel {
			attribute :>> diameter = 48.0 [cm];
			attribute :>> width = 6.0 [cm];
			port :>> driveIn;
		}
		
		part rightWheel : Wheel {
			attribute :>> diameter = 48.0 [cm];
			attribute :>> width = 6.0 [cm];
			port :>> driveIn;
		}
		
		part battery : BatteryPack {
			attribute :>> nominalVoltage = 72.0 [V];
			attribute :>> capacity = 1300.0 [W*h];
			attribute :>> currentCharge = 1300.0 [W*h];
			attribute :>> maxDischargeCurrent = 30.0 [A];
			
			port :>> powerOut;
		}
		
		part handlebar : HandlebarAssembly {
			attribute :>> height = 1.2 [m];
			port :>> riderOut;
		}
		
		connection gyroToController connect gyroscope.sensorOut to controller.sensorIn;
		connection accelToController connect accelerometer.sensorOut to controller.sensorIn;
		connection speedToController connect speedSensor.sensorOut to controller.sensorIn;
		connection handlebarToController connect handlebar.riderOut to controller.riderIn;
		
		connection controllerToLeftMotor connect controller.motorOut to leftMotor.controlIn;
		connection controllerToRightMotor connect controller.motorOut to rightMotor.controlIn;
		
		connection leftMotorToWheel connect leftMotor.mechanicalOut to leftWheel.driveIn;
		connection rightMotorToWheel connect rightMotor.mechanicalOut to rightWheel.driveIn;
		
		connection batteryToController connect battery.powerOut to controller.powerIn;
		connection batteryToLeftMotor connect battery.powerOut to leftMotor.powerIn;
		connection batteryToRightMotor connect battery.powerOut to rightMotor.powerIn;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'SEG-REQ-001'> maintainDynamicBalance : FunctionalRequirement {
		doc /* The Segway HT shall continuously maintain dynamic balance by 
		     monitoring platform tilt and adjusting wheel torque to keep the 
		     platform upright within safe operating limits. */
		
		subject segwayHT;
		
		satisfy by BalanceLoop;
		satisfy by segwayHT.controller;
	}
	
	requirement <'SEG-REQ-002'> respondToRiderCommands : FunctionalRequirement {
		doc /* The Segway HT shall respond to rider lean input by accelerating, 
		     decelerating, or turning while maintaining balance. */
		
		subject segwayHT;
		
		require constraint riderInputProcessing {
			segwayHT.handlebar.riderOut.riderInput.leanAngle >= -30.0 [deg] and
			segwayHT.handlebar.riderOut.riderInput.leanAngle <= 30.0 [deg]
		}
	}
	
	requirement <'SEG-REQ-003'> operateWithinSpeedLimits : PerformanceRequirement {
		doc /* The Segway HT shall operate at speeds up to 20 km/h on level ground. */
		
		subject segwayHT;
		
		require constraint maxSpeedLimit {
			segwayHT.speedSensor.sensorOut.reading.forwardSpeed <= 20.0 [km/h]
		}
	}
	
	requirement <'SEG-REQ-004'> supportRiderWeight : SafetyRequirement {
		doc /* The Segway HT shall safely support riders up to 118 kg. */
		
		subject segwayHT.frame;
		
		require constraint weightLimit {
			segwayHT.maxRiderMass <= 118.0 [kg]
		}
	}
	
	requirement <'SEG-REQ-005'> provideSufficientPower : PerformanceRequirement {
		doc /* The battery system shall provide sufficient energy for at least 
		     24 km of range under normal operating conditions. */
		
		subject segwayHT.battery;
		
		require constraint minimumCapacity {
			segwayHT.battery.capacity >= 1000.0 [W*h]
		}
	}
	
	requirement <'SEG-REQ-006'> ensureSafeOperation : SafetyRequirement {
		doc /* The Segway HT shall enter a safe shutdown state upon detection 
		     of critical system faults. */
		
		subject segwayHT;
		
		satisfy by segwayHT.operationalStates;
	}
	
	requirement segwaySystemRequirements {
		doc /* Top-level requirements for the Segway HT personal transporter system. 
		     The primary function is to provide stable, self-balancing personal 
		     transportation through continuous dynamic balance control. */
		
		require maintainDynamicBalance;
		require respondToRiderCommands;
		require operateWithinSpeedLimits;
		require supportRiderWeight;
		require provideSufficientPower;
		require ensureSafeOperation;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SegwayHTSystem::*;

    part testSubject = segwayHT {
        exhibit state sm : SegwayOperationalStates;
    }

    action orchestrator {
        attribute testPowerButtonPressed : powerButtonPressed;
        attribute testSelfTestPassed : selfTestPassed;
        attribute testRiderDetected : riderDetected;
        attribute testRiderLeans : riderLeans;
        attribute testRiderStopsLeaning : riderStopsLeaning;
        action triggerpowerButtonPressed send testPowerButtonPressed to testSubject;
        action triggerselfTestPassed send testSelfTestPassed to testSubject;
        action triggerriderDetected send testRiderDetected to testSubject;
        action triggerriderLeans send testRiderLeans to testSubject;
        action triggerriderStopsLeaning send testRiderStopsLeaning to testSubject;
        first triggerpowerButtonPressed;
        then triggerselfTestPassed;
        then triggerriderDetected;
        then triggerriderLeans;
        then triggerriderStopsLeaning;
    }
}
