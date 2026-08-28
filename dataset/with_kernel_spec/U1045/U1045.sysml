package 'Self-Balancing Electric Unicycle' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	item def OrientationData {
		attribute pitch : AngleValue;
		attribute roll : AngleValue;
	}
	
	item def PressureData {
		attribute riderPresent : Boolean;
		attribute leanAngle : AngleValue;
	}
	
	item def TorqueCommand {
		attribute torque : TorqueValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	item def BatteryStatus {
		attribute chargeLevel : Real;
		attribute voltage : ElectricPotentialValue;
	}
	
	item def DisplayData {
		attribute mode : String;
		attribute batteryLevel : Real;
		attribute status : String;
	}
	
	item def PowerOnSignal;
	item def InitCompleteSignal;
	item def RiderMountedSignal;
	item def ForwardLeanSignal;
	item def NeutralLeanSignal;
	item def ChargerConnectedSignal;
	item def ChargerDisconnectedSignal;
	item def FaultSignal;
	item def ResetSignal;
	
	part def Chassis;
	
	part def IMU {
		port orientationOut {
			out orientation : OrientationData;
		}
		port powerIn {
			in power : ElectricalPower;
		}
	}
	
	part def PedalAssembly {
		port pressureOut {
			out pressure : PressureData;
		}
		port powerIn {
			in power : ElectricalPower;
		}
	}
	
	part def ElectricMotor {
		port torqueIn {
			in torqueCmd : TorqueCommand;
		}
		port powerIn {
			in power : ElectricalPower;
		}
	}
	
	part def Wheel {
		part motor : ElectricMotor;
		port torqueIn {
			in torqueCmd : TorqueCommand;
		}
		port powerIn {
			in power : ElectricalPower;
		}
		bind motor.torqueIn = torqueIn;
		bind motor.powerIn = powerIn;
	}
	
	part def Battery {
		port powerOut {
			out power : ElectricalPower;
		}
		port statusOut {
			out status : BatteryStatus;
		}
	}
	
	part def Display {
		port dataIn {
			in displayData : DisplayData;
		}
		port powerIn {
			in power : ElectricalPower;
		}
	}
	
	part def MotorController {
		port orientationIn {
			in orientation : OrientationData;
		}
		port pressureIn {
			in pressure : PressureData;
		}
		port torqueOut {
			out torqueCmd : TorqueCommand;
		}
		port displayOut {
			out displayData : DisplayData;
		}
		port batteryIn {
			in status : BatteryStatus;
		}
		port powerIn {
			in power : ElectricalPower;
		}
		
		state ControllerStates {
			entry; then off;
			state off;
			transition off_to_init first off accept PowerOnSignal then initializing;
			state initializing;
			transition init_to_ready first initializing accept InitCompleteSignal then ready;
			state ready;
			transition ready_to_balancing first ready accept RiderMountedSignal then balancing;
			state balancing;
			transition balancing_to_riding first balancing accept ForwardLeanSignal then riding;
			transition riding_to_balancing first riding accept NeutralLeanSignal then balancing;
			transition off_to_charging first off accept ChargerConnectedSignal then charging;
			transition ready_to_charging first ready accept ChargerConnectedSignal then charging;
			transition balancing_to_charging first balancing accept ChargerConnectedSignal then charging;
			transition riding_to_charging first riding accept ChargerConnectedSignal then charging;
			state charging;
			transition charging_to_off first charging accept ChargerDisconnectedSignal then off;
			transition off_to_fault first off accept FaultSignal then fault;
			transition init_to_fault first initializing accept FaultSignal then fault;
			transition ready_to_fault first ready accept FaultSignal then fault;
			transition balancing_to_fault first balancing accept FaultSignal then fault;
			transition riding_to_fault first riding accept FaultSignal then fault;
			transition charging_to_fault first charging accept FaultSignal then fault;
			state fault;
			transition fault_to_off first fault accept ResetSignal then off;
		}
	}
	
	part def EUC {
		part chassis : Chassis;
		part imu : IMU;
		part pedalAssembly : PedalAssembly;
		part motorController : MotorController;
		part wheel : Wheel;
		part battery : Battery;
		part display : Display;
		
		flow orientationFlow of OrientationData 
			from imu.orientationOut.orientation to motorController.orientationIn.orientation;
		flow pressureFlow of PressureData 
			from pedalAssembly.pressureOut.pressure to motorController.pressureIn.pressure;
		flow torqueFlow of TorqueCommand 
			from motorController.torqueOut.torqueCmd to wheel.torqueIn.torqueCmd;
		flow displayFlow of DisplayData 
			from motorController.displayOut.displayData to display.dataIn.displayData;
		flow batteryStatusFlow of BatteryStatus 
			from battery.statusOut.status to motorController.batteryIn.status;
			
		flow powerFlowToController of ElectricalPower 
			from battery.powerOut.power to motorController.powerIn.power;
		flow powerFlowToMotor of ElectricalPower 
			from battery.powerOut.power to wheel.powerIn.power;
		flow powerFlowToIMU of ElectricalPower 
			from battery.powerOut.power to imu.powerIn.power;
		flow powerFlowToPedal of ElectricalPower 
			from battery.powerOut.power to pedalAssembly.powerIn.power;
		flow powerFlowToDisplay of ElectricalPower 
			from battery.powerOut.power to display.powerIn.power;
	}
	
	requirement def BalanceRequirement {
		doc /* The EUC shall dynamically maintain balance by adjusting motor torque based on IMU and pedal pressure data. */
	}
	
	requirement def RiderControlRequirement {
		doc /* The EUC shall respond to rider lean by accelerating or decelerating to maintain balance. */
	}
	
	requirement def StateManagementRequirement {
		doc /* The EUC shall operate through states: off, initializing, ready, balancing, riding, charging, and fault. */
	}
	
	requirement def PowerRequirement {
		doc /* The Battery Pack shall supply electrical power to the motor, controller, sensors, and display. */
	}
	
	part euc : EUC;
	
	satisfy BalanceRequirement by euc;
	satisfy RiderControlRequirement by euc;
	satisfy StateManagementRequirement by euc.motorController;
	satisfy PowerRequirement by euc.battery;
}
