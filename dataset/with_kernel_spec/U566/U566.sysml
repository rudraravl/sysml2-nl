package 'Automated Centrifugal Pump System' {
	import ScalarValues::*;

	attribute def FlowRateValue :> Real;
	attribute def PressureValue :> Real;
	attribute def RotationalSpeedValue :> Real;
	attribute def HeadValue :> Real;
	attribute def SpecificSpeedValue :> Real;
	attribute def FrequencyValue :> Real;

	attribute def StartSignal;
	attribute def StopSignal;
	attribute def EmergencySignal;
	attribute def ResetSignal;
	attribute def InitCompleteSignal;
	attribute def TargetSpeedReachedSignal;
	attribute def SpeedZeroSignal;

	item def Fluid;
	item def ElectricalPower;

	item def FlowReading {
		flowRate : FlowRateValue;
	}
	item def PressureReading {
		pressure : PressureValue;
	}
	item def SpeedReading {
		speed : RotationalSpeedValue;
	}
	item def VFDCommand {
		targetFrequency : FrequencyValue;
	}

	part def Impeller {
		attribute diameter : Real;
		attribute bladeCount : Integer;
	}

	part def Volute {
		attribute throatArea : Real;
	}

	part def PumpHousing {
		attribute material : String;
	}

	part def Pump {
		part impeller : Impeller;
		part volute : Volute;
		part housing : PumpHousing;
		port inletPort { in fluid : Fluid; }
		port outletPort { out fluid : Fluid; }
		port shaftPort { in speed : RotationalSpeedValue; }
	}

	part def ElectricMotor {
		port powerIn { in power : ElectricalPower; }
		port commandIn { in command : VFDCommand; }
		port shaftOut { out speed : RotationalSpeedValue; }
	}

	part def VariableFrequencyDrive {
		port powerIn { in power : ElectricalPower; }
		port powerOut { out power : ElectricalPower; }
		port commandIn { in command : VFDCommand; }
	}

	part def FlowSensor {
		port fluidIn { in fluid : Fluid; }
		port dataOut { out reading : FlowReading; }
	}

	part def PressureSensor {
		port fluidIn { in fluid : Fluid; }
		port dataOut { out reading : PressureReading; }
	}

	part def SpeedSensor {
		port shaftIn { in speed : RotationalSpeedValue; }
		port dataOut { out reading : SpeedReading; }
	}

	part def SpecificSpeedController {
		attribute idealSpecificSpeed : SpecificSpeedValue := 0.8;

		port flowIn { in reading : FlowReading; }
		port inletPressureIn { in reading : PressureReading; }
		port outletPressureIn { in reading : PressureReading; }
		port speedIn { in reading : SpeedReading; }
		port commandOut { out command : VFDCommand; }

		action controlLoop {
			action readFlow accept FlowReading via flowIn;
			then action readInletPressure accept PressureReading via inletPressureIn;
			then action readOutletPressure accept PressureReading via outletPressureIn;
			then action readSpeed accept SpeedReading via speedIn;
			then action calculateHead { /* compute head from pressure differential */ }
			then action calculateSpecificSpeed { /* compute specific speed metric */ }
			then action compareWithIdeal { /* compare current vs ideal specific speed */ }
			then action sendAdjustment send new VFDCommand() to commandOut;
		}
	}

	part def PumpSystem {
		port fluidIn { in fluid : Fluid; }
		port fluidOut { out fluid : Fluid; }
		port powerIn { in power : ElectricalPower; }

		part pump : Pump;
		part motor : ElectricMotor;
		part vfd : VariableFrequencyDrive;
		part controller : SpecificSpeedController;
		part flowSensor : FlowSensor;
		part inletPressureSensor : PressureSensor;
		part outletPressureSensor : PressureSensor;
		part speedSensor : SpeedSensor;

		flow fluidFlowIn of Fluid from fluidIn.fluid to pump.inletPort.fluid;
		flow fluidToFlowSensor of Fluid from fluidIn.fluid to flowSensor.fluidIn.fluid;
		flow fluidToInletPSensor of Fluid from fluidIn.fluid to inletPressureSensor.fluidIn.fluid;
		flow fluidFlowOut of Fluid from pump.outletPort.fluid to fluidOut.fluid;
		flow fluidToOutletPSensor of Fluid from pump.outletPort.fluid to outletPressureSensor.fluidIn.fluid;

		flow powerToVFD of ElectricalPower from powerIn.power to vfd.powerIn.power;
		flow powerToMotor of ElectricalPower from vfd.powerOut.power to motor.powerIn.power;

		flow speedToSpeedSensor of RotationalSpeedValue from motor.shaftOut.speed to speedSensor.shaftIn.speed;
		flow motorToPumpShaft of RotationalSpeedValue from motor.shaftOut.speed to pump.shaftPort.speed;

		flow flowData of FlowReading from flowSensor.dataOut.reading to controller.flowIn.reading;
		flow inletPressureData of PressureReading from inletPressureSensor.dataOut.reading to controller.inletPressureIn.reading;
		flow outletPressureData of PressureReading from outletPressureSensor.dataOut.reading to controller.outletPressureIn.reading;
		flow speedData of SpeedReading from speedSensor.dataOut.reading to controller.speedIn.reading;

		flow vfdCommandFlow of VFDCommand from controller.commandOut.command to vfd.commandIn.command;

		state def PumpSystemStates;
		state pumpSystemStates : PumpSystemStates {
			entry; then stopped;

			state stopped;
			accept StartSignal then initializing;

			state initializing {
				entry action performSelfTest {
					action checkSensorCommunication { /* verify sensor links */ }
					then action checkVFDReadiness { /* verify VFD response */ }
				}
			}
			accept InitCompleteSignal
				do send new VFDCommand() to vfd
				then accelerating;

			state accelerating;
			accept TargetSpeedReachedSignal then normalOperation;
			accept EmergencySignal then emergency;

			state normalOperation {
				do action optimizePerformance {
					action readFlow accept FlowReading via controller.flowIn;
					then action readInletPressure accept PressureReading via controller.inletPressureIn;
					then action readOutletPressure accept PressureReading via controller.outletPressureIn;
					then action readSpeed accept SpeedReading via controller.speedIn;
					then action calculateHead { /* compute head from pressure differential */ }
					then action calculateSpecificSpeed { /* compute specific speed metric */ }
					then action compareWithIdeal { /* compare current vs ideal specific speed */ }
					then action sendAdjustment send new VFDCommand() to vfd;
				}
			}
			accept StopSignal
				do send new VFDCommand() to vfd
				then decelerating;
			accept EmergencySignal then emergency;

			state decelerating;
			accept SpeedZeroSignal then stopped;

			state emergency {
				entry action immediateShutdown {
					action cutPower { /* disconnect electrical power */ }
					then action applyBrake { /* engage mechanical brake */ }
				}
			}
			accept ResetSignal then stopped;
		}
	}

	requirement EfficiencyOptimizationRequirement {
		doc /* The system shall continuously monitor flow rate, inlet pressure, outlet pressure, and rotational speed to calculate specific speed and adjust motor speed to maintain optimal efficiency. */;
	}

	requirement ClosedLoopControlRequirement {
		doc /* The Specific Speed Controller shall form a closed-loop control system by processing sensor data and issuing commands to the VFD to maintain the ideal specific speed. */;
	}

	requirement SafeOperationRequirement {
		doc /* The system shall support normal start/stop sequences including initialization, acceleration, deceleration, and emergency shutdown from any operational state. */;
	}

	requirement SensorIntegrationRequirement {
		doc /* The system shall integrate flow, inlet pressure, outlet pressure, and speed sensors with the specific speed controller for real-time performance monitoring. */;
	}
}
