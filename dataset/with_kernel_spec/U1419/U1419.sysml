package 'Industrial Two-Stage Gas Compressor System' {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		item def Gas;

		alias PressureValue for ISQ::PressureValue;
		alias TemperatureValue for ISQ::TemperatureValue;
		alias RotationalSpeedValue for ISQ::AngularVelocityValue;
		alias PowerValue for ISQ::PowerValue;
		alias TorqueValue for ISQ::TorqueValue;
		alias MassFlowRateValue for ISQ::MassFlowRateValue;

		attribute def DesiredPressure;
		attribute def MotorSpeedCmd;
		attribute def ValvePositionCmd;
		attribute def StartSignal;
		attribute def StopSignal;
		attribute def EmergencyStopSignal;
		attribute def OverPressureAlert;
		attribute def MotorOverloadAlert;
		attribute def ResetSignal;

		port def GasInPort {
			in gas : Gas;
			in pressure : PressureValue;
			in temperature : TemperatureValue;
		}
		port def GasOutPort {
			out gas : Gas;
			out pressure : PressureValue;
			out temperature : TemperatureValue;
		}
		port def DriveOutputPort {
			out rotationalSpeed : RotationalSpeedValue;
			out torque : TorqueValue;
		}
		port def DriveInputPort {
			in rotationalSpeed : RotationalSpeedValue;
			in torque : TorqueValue;
		}
		port def ElectricalPowerPort {
			in power : PowerValue;
		}
		port def PressureSensorOutPort {
			out sensedPressure : PressureValue;
		}
		port def PressureSensorInPort {
			in sensedPressure : PressureValue;
		}
		port def MotorCmdOutPort {
			out motorSpeedCmd : MotorSpeedCmd;
		}
		port def MotorCmdInPort {
			in motorSpeedCmd : MotorSpeedCmd;
		}
		port def ValveCmdOutPort {
			out valvePositionCmd : ValvePositionCmd;
		}
		port def ValveCmdInPort {
			in valvePositionCmd : ValvePositionCmd;
		}
		port def DesiredPressureInPort {
			in desiredPressure : DesiredPressure;
		}
		port def AlertInPort {
			in overPressureAlert : OverPressureAlert;
			in motorOverloadAlert : MotorOverloadAlert;
		}
		port def AlertOutPort {
			out overPressureAlert : OverPressureAlert;
			out motorOverloadAlert : MotorOverloadAlert;
		}

		action def 'Compress Gas' {
			in gas : Gas;
			in inletPressure : PressureValue;
			in inletTemperature : TemperatureValue;
			in rotationalSpeed : RotationalSpeedValue;
			in torque : TorqueValue;
			out outletGas : Gas;
			out outletPressure : PressureValue;
			out outletTemperature : TemperatureValue;
		}
		action def 'Cool Gas' {
			in gas : Gas;
			in inletPressure : PressureValue;
			in inletTemperature : TemperatureValue;
			out outletGas : Gas;
			out outletPressure : PressureValue;
			out outletTemperature : TemperatureValue;
		}
		action def 'Regulate Flow' {
			in gas : Gas;
			in inletPressure : PressureValue;
			in inletTemperature : TemperatureValue;
			in valvePosition : ValvePositionCmd;
			out outletGas : Gas;
			out outletPressure : PressureValue;
			out outletTemperature : TemperatureValue;
			out flowRate : MassFlowRateValue;
		}
		action def 'Sense Pressure' {
			in gas : Gas;
			in pressure : PressureValue;
			out sensedPressure : PressureValue;
		}
		action def 'Control System' {
			in desiredPressure : DesiredPressure;
			in sensedPressure : PressureValue;
			out motorSpeedCmd : MotorSpeedCmd;
			out valvePositionCmd : ValvePositionCmd;
		}
		action def 'Provide Power' {
			in power : PowerValue;
			in motorSpeedCmd : MotorSpeedCmd;
			out rotationalSpeed : RotationalSpeedValue;
			out torque : TorqueValue;
		}
		action def 'Initialize Motor';
		action def 'Pressurize First Stage';
		action def 'Pressurize Second Stage';
		action def 'Ramp Down Motor';
		action def 'Close Discharge Valve';
		action def 'Vent Pressure';
		action def 'Cut Motor Power';
		action def 'Open Vent Valve';
		action def 'Issue Emergency Commands' {
			out motorSpeedCmd : MotorSpeedCmd;
			out valvePositionCmd : ValvePositionCmd;
		}

		part def ElectricMotor {
			port electricalPowerPort : ElectricalPowerPort;
			port motorCmdPort : MotorCmdInPort;
			port drivePort : DriveOutputPort;
			port alertPort : AlertOutPort;
			attribute overload : Boolean;
			perform action 'provide power' : 'Provide Power';
		}
		part def CompressionStage {
			port gasInPort : GasInPort;
			port gasOutPort : GasOutPort;
			port drivePort : DriveInputPort;
			perform action 'compress gas' : 'Compress Gas';
		}
		part def Intercooler {
			port gasInPort : GasInPort;
			port gasOutPort : GasOutPort;
			attribute targetTemperature : TemperatureValue;
			perform action 'cool gas' : 'Cool Gas';
		}
		part def DischargeValve {
			port gasInPort : GasInPort;
			port gasOutPort : GasOutPort;
			port cmdPort : ValveCmdInPort;
			perform action 'regulate flow' : 'Regulate Flow';
		}
		part def PressureSensor {
			port gasInPort : GasInPort;
			port sensorPort : PressureSensorOutPort;
			perform action 'sense pressure' : 'Sense Pressure';
		}
		part def SystemController {
			port desiredPressurePort : DesiredPressureInPort;
			port sensedPressurePort : PressureSensorInPort;
			port motorCmdPort : MotorCmdOutPort;
			port valveCmdPort : ValveCmdOutPort;
			port alertPort : AlertInPort;
			perform action 'control system' : 'Control System';
			exhibit state 'controller states' : 'Controller States';
		}

		state def 'Compressor States';
		state def 'Controller States';

		part def 'Two-Stage Gas Compressor' {
			port gasIntakePort : GasInPort;
			port gasDischargePort : GasOutPort;
			port desiredPressurePort : DesiredPressureInPort;

			attribute dischargePressure : PressureValue;
			attribute minDischargePressure : PressureValue;
			attribute maxDischargePressure : PressureValue;
			attribute maxSafePressure : PressureValue;
			attribute inEmergencyShutdown : Boolean;

			part electricMotor : ElectricMotor;
			part firstStage : CompressionStage;
			part intercooler : Intercooler;
			part secondStage : CompressionStage;
			part dischargeValve : DischargeValve;
			part pressureSensor : PressureSensor;
			part controller : SystemController;

			exhibit state 'compressor states' : 'Compressor States';
		}

		requirement def 'Maintain Discharge Pressure' {
			subject compressor : 'Two-Stage Gas Compressor';
			doc /* The compressor shall maintain the discharge pressure within a specified tolerance of the desired setpoint. */
			require constraint {
				compressor.dischargePressure >= compressor.minDischargePressure and
				compressor.dischargePressure <= compressor.maxDischargePressure;
			}
		}
		requirement def 'Emergency Shutdown on Overpressure' {
			subject compressor : 'Two-Stage Gas Compressor';
			doc /* The system shall initiate an emergency shutdown when the output pressure exceeds a maximum safe threshold. */
			require constraint {
				compressor.dischargePressure > compressor.maxSafePressure implies
				compressor.inEmergencyShutdown;
			}
		}
		requirement def 'Interstage Cooling' {
			subject intercooler : Intercooler;
			doc /* The intercooler shall cool the gas to the target temperature before it enters the second stage. */
			require constraint {
				intercooler.gasOutPort.temperature <= intercooler.targetTemperature;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part compressorSystem : 'Two-Stage Gas Compressor' {
			attribute minDischargePressure = 1.0e6 [Pa];
			attribute maxDischargePressure = 1.5e6 [Pa];
			attribute maxSafePressure = 2.0e6 [Pa];
			attribute inEmergencyShutdown = false;

			part :>> electricMotor : ElectricMotor;
			part :>> firstStage : CompressionStage;
			part :>> intercooler : Intercooler {
				attribute targetTemperature = 310.0 [K];
			}
			part :>> secondStage : CompressionStage;
			part :>> dischargeValve : DischargeValve;
			part :>> pressureSensor : PressureSensor;

			bind desiredPressurePort = controller.desiredPressurePort;

			flow gasFlow1 of Gas
				from gasIntakePort.gas to firstStage.gasInPort.gas;
			flow pressureFlow1 of PressureValue
				from gasIntakePort.pressure to firstStage.gasInPort.pressure;
			flow tempFlow1 of TemperatureValue
				from gasIntakePort.temperature to firstStage.gasInPort.temperature;

			flow gasFlow2 of Gas
				from firstStage.gasOutPort.gas to intercooler.gasInPort.gas;
			flow pressureFlow2 of PressureValue
				from firstStage.gasOutPort.pressure to intercooler.gasInPort.pressure;
			flow tempFlow2 of TemperatureValue
				from firstStage.gasOutPort.temperature to intercooler.gasInPort.temperature;

			flow gasFlow3 of Gas
				from intercooler.gasOutPort.gas to secondStage.gasInPort.gas;
			flow pressureFlow3 of PressureValue
				from intercooler.gasOutPort.pressure to secondStage.gasInPort.pressure;
			flow tempFlow3 of TemperatureValue
				from intercooler.gasOutPort.temperature to secondStage.gasInPort.temperature;

			flow gasFlow4 of Gas
				from secondStage.gasOutPort.gas to dischargeValve.gasInPort.gas;
			flow pressureFlow4 of PressureValue
				from secondStage.gasOutPort.pressure to dischargeValve.gasInPort.pressure;
			flow tempFlow4 of TemperatureValue
				from secondStage.gasOutPort.temperature to dischargeValve.gasInPort.temperature;

			flow gasFlow5 of Gas
				from dischargeValve.gasOutPort.gas to gasDischargePort.gas;
			flow pressureFlow5 of PressureValue
				from dischargeValve.gasOutPort.pressure to gasDischargePort.pressure;
			flow tempFlow5 of TemperatureValue
				from dischargeValve.gasOutPort.temperature to gasDischargePort.temperature;

			flow sensorGasFlow of Gas
				from dischargeValve.gasOutPort.gas to pressureSensor.gasInPort.gas;
			flow sensorPressureFlow of PressureValue
				from dischargeValve.gasOutPort.pressure to pressureSensor.gasInPort.pressure;
			flow sensorTempFlow of TemperatureValue
				from dischargeValve.gasOutPort.temperature to pressureSensor.gasInPort.temperature;

			flow sensedPressureFlow of PressureValue
				from pressureSensor.sensorPort.sensedPressure
				to controller.sensedPressurePort.sensedPressure;

			flow driveSpeed1 of RotationalSpeedValue
				from electricMotor.drivePort.rotationalSpeed
				to firstStage.drivePort.rotationalSpeed;
			flow driveTorque1 of TorqueValue
				from electricMotor.drivePort.torque
				to firstStage.drivePort.torque;
			flow driveSpeed2 of RotationalSpeedValue
				from electricMotor.drivePort.rotationalSpeed
				to secondStage.drivePort.rotationalSpeed;
			flow driveTorque2 of TorqueValue
				from electricMotor.drivePort.torque
				to secondStage.drivePort.torque;

			flow motorCmdFlow of MotorSpeedCmd
				from controller.motorCmdPort.motorSpeedCmd
				to electricMotor.motorCmdPort.motorSpeedCmd;
			flow valveCmdFlow of ValvePositionCmd
				from controller.valveCmdPort.valvePositionCmd
				to dischargeValve.cmdPort.valvePositionCmd;

			flow motorOverloadFlow of MotorOverloadAlert
				from electricMotor.alertPort.motorOverloadAlert
				to controller.alertPort.motorOverloadAlert;

			exhibit state 'compressor states' : 'Compressor States' parallel {
				state 'operational states' {
					entry; then idle;
					state idle;
					accept StartSignal
						then startup;
					state startup {
						entry action 'initialize motor' : 'Initialize Motor';
						do action 'pressurize first stage' : 'Pressurize First Stage';
						do action 'pressurize second stage' : 'Pressurize Second Stage';
					}
					accept when dischargePressure >= minDischargePressure
						then 'normal running';
					state 'normal running' {
						do action 'compress gas continuously' {
							action 'compress stage 1' : 'Compress Gas' {
								in gas = gasFlow1;
								in inletPressure = pressureFlow1;
								in inletTemperature = tempFlow1;
								in rotationalSpeed = driveSpeed1;
								in torque = driveTorque1;
								out outletGas;
								out outletPressure;
								out outletTemperature;
							}
							flow 'compress stage 1'.outletGas to 'cool gas'.gas;
							flow 'compress stage 1'.outletPressure to 'cool gas'.inletPressure;
							flow 'compress stage 1'.outletTemperature to 'cool gas'.inletTemperature;
							action 'cool gas' : 'Cool Gas' {
								in gas;
								in inletPressure;
								in inletTemperature;
								out outletGas;
								out outletPressure;
								out outletTemperature;
							}
							flow 'cool gas'.outletGas to 'compress stage 2'.gas;
							flow 'cool gas'.outletPressure to 'compress stage 2'.inletPressure;
							flow 'cool gas'.outletTemperature to 'compress stage 2'.inletTemperature;
							action 'compress stage 2' : 'Compress Gas' {
								in gas;
								in inletPressure;
								in inletTemperature;
								in rotationalSpeed = driveSpeed2;
								in torque = driveTorque2;
								out outletGas;
								out outletPressure;
								out outletTemperature;
							}
							flow 'compress stage 2'.outletGas to 'regulate'.gas;
							flow 'compress stage 2'.outletPressure to 'regulate'.inletPressure;
							flow 'compress stage 2'.outletTemperature to 'regulate'.inletTemperature;
							action 'regulate' : 'Regulate Flow' {
								in gas;
								in inletPressure;
								in inletTemperature;
								in valvePosition = valveCmdFlow;
								out outletGas;
								out outletPressure;
								out outletTemperature;
								out flowRate;
							}
						}
					}
					accept StopSignal
						then shutdown;
					state shutdown {
						entry action 'close discharge valve' : 'Close Discharge Valve';
						do action 'ramp down motor' : 'Ramp Down Motor';
						do action 'vent pressure' : 'Vent Pressure';
					}
					accept when dischargePressure < minDischargePressure
						then idle;
				}
				state 'safety states' {
					entry; then 'safe normal';
					state 'safe normal';
					accept when dischargePressure > maxSafePressure
						do send new OverPressureAlert() to controller
						then 'emergency shutdown';
					accept when electricMotor.overload
						do send new MotorOverloadAlert() to controller
						then 'emergency shutdown';
					state 'emergency shutdown' {
						entry action 'cut motor power' : 'Cut Motor Power';
						do action 'open vent valve' : 'Open Vent Valve';
					}
					accept ResetSignal
						then 'safe normal';
				}
			}

			part :>> controller : SystemController {
				exhibit state 'controller states' : 'Controller States' {
					entry; then 'controller idle';
					state 'controller idle';
					accept StartSignal
						then 'controller active';
					state 'controller active' {
						do action 'control loop' : 'Control System' {
							in desiredPressure = compressorSystem.desiredPressurePort.desiredPressure;
							in sensedPressure = sensedPressureFlow;
							out motorSpeedCmd;
							out valvePositionCmd;
						}
						flow 'control loop'.motorSpeedCmd to motorCmdPort.motorSpeedCmd;
						flow 'control loop'.valvePositionCmd to valveCmdPort.valvePositionCmd;
					}
					accept OverPressureAlert
						do send new EmergencyStopSignal() to compressorSystem
						then 'controller emergency';
					accept MotorOverloadAlert
						do send new EmergencyStopSignal() to compressorSystem
						then 'controller emergency';
					state 'controller emergency' {
						do action 'issue emergency commands' : 'Issue Emergency Commands' {
							out motorSpeedCmd;
							out valvePositionCmd;
						}
						flow 'issue emergency commands'.motorSpeedCmd to motorCmdPort.motorSpeedCmd;
						flow 'issue emergency commands'.valvePositionCmd to valveCmdPort.valvePositionCmd;
					}
					accept ResetSignal
						then 'controller idle';
					accept StopSignal
						then 'controller idle';
				}
			}
		}

		requirement 'maintain discharge pressure req' : 'Maintain Discharge Pressure' {
			subject :>> compressor = compressorSystem;
		}
		requirement 'emergency shutdown req' : 'Emergency Shutdown on Overpressure' {
			subject :>> compressor = compressorSystem;
		}
		requirement 'interstage cooling req' : 'Interstage Cooling' {
			subject :>> intercooler = compressorSystem.intercooler;
		}
	}
}
