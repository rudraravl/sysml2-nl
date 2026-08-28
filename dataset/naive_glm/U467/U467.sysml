package ArchimedesScrewPumpSystem {

	import ScalarValues::*;

	value type AngleValue {
		unit "deg";
	}
	
	value type VolumeValue {
		unit "m^3";
	}
	
	value type FlowRateValue {
		unit "m^3/s";
	}
	
	value type RotationalSpeedValue {
		unit "rpm";
	}
	
	value type TorqueValue {
		unit "N*m";
	}
	
	value type LengthValue {
		unit "m";
	}
	
	value type PowerValue {
		unit "W";
	}

	item def Water;
	item def StartCommand;
	item def StopCommand;
	item def WaterLevelLow;
	item def WaterLevelOk;
	item def MotorStartSignal;
	item def MotorStopSignal;

	port def FluidPort {
		flow of Water;
	}

	port def MechanicalPort {
		attribute speed : RotationalSpeedValue;
		attribute torque : TorqueValue;
	}

	port def OperatorCommandPort {
		in startCmd : StartCommand;
		in stopCmd : StopCommand;
	}

	port def WaterSensorPort {
		in waterLow : WaterLevelLow;
		in waterOk : WaterLevelOk;
	}

	port def MotorControlPort {
		out motorStart : MotorStartSignal;
		out motorStop : MotorStopSignal;
	}

	part def HelicalBlade {
		attribute material : String = "Steel";
		attribute diameter : LengthValue = 1.0;
	}

	part def CentralShaft {
		attribute material : String = "Steel";
		attribute shape : String = "Cylindrical";
		attribute length : LengthValue = 5.0;
		attribute radius : LengthValue = 0.2;
	}

	part def ScrewAssembly {
		part blade : HelicalBlade;
		part shaft : CentralShaft;
		
		attribute pitch : LengthValue = 0.5;
		attribute liftedVolumePerRev : VolumeValue = 0.05;
		
		port rotIn : MechanicalPort;
		port waterIn : FluidPort;
		port waterOut : FluidPort;
	}

	part def TubularHousing {
		attribute material : String = "Steel";
		attribute isStationary : Boolean = true;
		attribute inclination : AngleValue = 30;
		attribute diameter : LengthValue = 1.2;
		attribute length : LengthValue = 5.5;
	}

	part def ElectricDriveMotor {
		port rotOut : MechanicalPort;
		port control : ~MotorControlPort;
		
		attribute nominalSpeed : RotationalSpeedValue = 120;
		attribute startingTorque : TorqueValue = 500;
		attribute power : PowerValue = 5000;
		attribute currentSpeed : RotationalSpeedValue;
	}

	part def Basin {
		attribute capacity : VolumeValue = 10.0;
		attribute currentVolume : VolumeValue;
		port waterPort : FluidPort;
	}

	part def LowerBasin : Basin {
		attribute minThreshold : VolumeValue = 1.0;
		port sensorOut : ~WaterSensorPort;
	}

	part def UpperBasin : Basin {
		attribute capacity : VolumeValue = 50.0;
	}

	part def Controller {
		port opCmd : OperatorCommandPort;
		port sensorIn : WaterSensorPort;
		port motorCmd : MotorControlPort;
		
		attribute isWaterAvailable : Boolean = true;
		
		state machine ControlStateMachine {
			state idle;
			state starting;
			state accelerating;
			state operating;
			state stopping;
			
			transition idle to starting accept StartCommand;
			transition starting to accelerating after 2 [s];
			transition accelerating to operating after 3 [s];
			
			transition operating to stopping accept StopCommand;
			transition operating to stopping accept WaterLevelLow;
			transition starting to stopping accept StopCommand;
			transition starting to stopping accept WaterLevelLow;
			transition accelerating to stopping accept StopCommand;
			transition accelerating to stopping accept WaterLevelLow;
			
			transition stopping to idle after 5 [s];
		}
	}

	part def ArchimedesScrewPump {
		port opCmd : OperatorCommandPort;
		
		attribute designFlowRate : FlowRateValue = 0.15;
		
		part housing : TubularHousing;
		part screw : ScrewAssembly;
		part motor : ElectricDriveMotor;
		part lowerBasin : LowerBasin;
		part upperBasin : UpperBasin;
		part controller : Controller;
		
		connection motorToScrew connect motor.rotOut to screw.rotIn;
		connection lowerBasinToScrew connect lowerBasin.waterPort to screw.waterIn;
		connection screwToUpperBasin connect screw.waterOut to upperBasin.waterPort;
		connection sensorToCtrl connect lowerBasin.sensorOut to controller.sensorIn;
		connection ctrlToMotor connect controller.motorCmd to motor.control;
		connection opCmdToCtrl connect opCmd to controller.opCmd;
	}

	requirement def MinimumFlowRateRequirement {
		subject pump : ArchimedesScrewPump;
		attribute minFlowRate : FlowRateValue = 0.1;
		require {
			pump.designFlowRate >= minFlowRate
		}
	}

	requirement def ContinuousLiftingRequirement {
		subject sys : ArchimedesScrewPump;
		require {
			sys.controller.isWaterAvailable == true
		}
	}

}
