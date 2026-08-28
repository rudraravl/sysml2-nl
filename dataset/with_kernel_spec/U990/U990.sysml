package 'Industrial Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def PressureMeasurement;
		attribute def TemperatureMeasurement;
		attribute def ValveCommand;
		attribute def MotorCommand;
		attribute def ProcessStatus;
		attribute def AlarmSignal;
		attribute def OperatorCommand;

		part def ProcessReactor {
			attribute maxPressure : PressureValue = 500000 [Pa];
			attribute maxTemperature : TemperatureValue = 250 [Cel];
			attribute currentPressure : PressureValue;
			attribute currentTemperature : TemperatureValue;
			
			port pressurePort {
				out pressure : PressureMeasurement;
			}
			port temperaturePort {
				out temperature : TemperatureMeasurement;
			}
		}

		part def PressureSensor {
			port reactorPort {
				in pressure : PressureMeasurement;
			}
			port plcPort {
				out reading : PressureMeasurement;
			}
			action sensePressure {
				in pressure : PressureMeasurement;
				out reading : PressureMeasurement;
			}
		}

		part def TemperatureSensor {
			port reactorPort {
				in temperature : TemperatureMeasurement;
			}
			port plcPort {
				out reading : TemperatureMeasurement;
			}
			action senseTemperature {
				in temperature : TemperatureMeasurement;
				out reading : TemperatureMeasurement;
			}
		}

		part def ProgrammableLogicController {
			port pressureInPort {
				in pressureReading : PressureMeasurement;
			}
			port tempInPort {
				in temperatureReading : TemperatureMeasurement;
			}
			port valveOutPort {
				out valveCmd : ValveCommand;
			}
			port motorOutPort {
				out motorCmd : MotorCommand;
			}
			port hmiOutPort {
				out status : ProcessStatus;
				out alarm : AlarmSignal;
			}
			port hmiInPort {
				in cmd : OperatorCommand;
			}
			
			attribute pressureSetpoint : PressureValue = 300000 [Pa];
			attribute temperatureSetpoint : TemperatureValue = 180 [Cel];
			
			action computeControl {
				in pressureReading : PressureMeasurement;
				in temperatureReading : TemperatureMeasurement;
				in pressureSetpoint : PressureValue;
				in temperatureSetpoint : TemperatureValue;
				out valveCmd : ValveCommand;
				out motorCmd : MotorCommand;
				out alarm : AlarmSignal;
			}
		}

		part def ControlValve {
			port plcPort {
				in cmd : ValveCommand;
			}
			action adjustFlow {
				in cmd : ValveCommand;
			}
		}

		part def ConveyorMotor {
			port plcPort {
				in cmd : MotorCommand;
			}
			action adjustSpeed {
				in cmd : MotorCommand;
			}
		}

		part def HumanMachineInterface {
			port plcInPort {
				in status : ProcessStatus;
				in alarm : AlarmSignal;
			}
			port plcOutPort {
				out cmd : OperatorCommand;
			}
			action displayStatus {
				in status : ProcessStatus;
			}
			action displayAlarm {
				in alarm : AlarmSignal;
			}
			action receiveOperatorInput {
				out cmd : OperatorCommand;
			}
		}

		state def ReactorStates {
			in reactor : ProcessReactor;
			entry; then idle;
			state idle;
			transition first idle accept OperatorCommand then filling;
			state filling;
			transition first filling accept after 30 [min] then heating;
			state heating;
			transition first heating accept when reactor.currentTemperature >= 180 [Cel] then reacting;
			state reacting;
			transition first reacting accept after 60 [min] then cooling;
			state cooling;
			transition first cooling accept when reactor.currentTemperature <= 30 [Cel] then draining;
			state draining;
			transition first draining accept after 15 [min] then idle;
		}

		state def PLCStates {
			in plc : ProgrammableLogicController;
			in hmi : HumanMachineInterface;
			entry; then startup;
			state startup;
			transition first startup accept after 5 [s] then running;
			state running {
				do action computeControl {
					in pressureReading = plc.pressureInPort.pressureReading;
					in temperatureReading = plc.tempInPort.temperatureReading;
					in pressureSetpoint = plc.pressureSetpoint;
					in temperatureSetpoint = plc.temperatureSetpoint;
					out valveCmd = plc.valveOutPort.valveCmd;
					out motorCmd = plc.motorOutPort.motorCmd;
					out alarm = plc.hmiOutPort.alarm;
				}
			}
			transition first running accept when plc.pressureInPort.pressureReading > plc.pressureSetpoint or plc.tempInPort.temperatureReading > plc.temperatureSetpoint
				do send new AlarmSignal() to hmi.plcInPort
				then fault;
			state fault;
			transition first fault accept OperatorCommand then maintenance;
			state maintenance;
			transition first maintenance accept OperatorCommand then startup;
		}

		requirement def SafeOperatingLimits {
			doc /* The reactor must operate within defined temperature and pressure limits. Exceeding these limits triggers an automatic alarm and fault state. */
			attribute maxPressure : PressureValue = 500000 [Pa];
			attribute maxTemperature : TemperatureValue = 250 [Cel];
		}

		requirement def AutoAlarmGeneration {
			doc /* If conditions exceed safe operating limits, the system must automatically generate an alarm on the HMI. */
		}
	}

	package Usages {
		private import Definitions::*;

		part automationSystem {
			part reactor : ProcessReactor;
			part pressureSensor : PressureSensor;
			part temperatureSensor : TemperatureSensor;
			part plc : ProgrammableLogicController;
			part controlValve : ControlValve;
			part conveyorMotor : ConveyorMotor;
			part hmi : HumanMachineInterface;
			
			interface pressureInterface connect reactor.pressurePort to pressureSensor.reactorPort {
				flow pressureFlow of PressureMeasurement from reactor.pressurePort.pressure to pressureSensor.reactorPort.pressure;
			}
			interface tempInterface connect reactor.temperaturePort to temperatureSensor.reactorPort {
				flow tempFlow of TemperatureMeasurement from reactor.temperaturePort.temperature to temperatureSensor.reactorPort.temperature;
			}
			interface pressureDataInterface connect pressureSensor.plcPort to plc.pressureInPort {
				flow pressureDataFlow of PressureMeasurement from pressureSensor.plcPort.reading to plc.pressureInPort.pressureReading;
			}
			interface tempDataInterface connect temperatureSensor.plcPort to plc.tempInPort {
				flow tempDataFlow of TemperatureMeasurement from temperatureSensor.plcPort.reading to plc.tempInPort.temperatureReading;
			}
			interface valveInterface connect plc.valveOutPort to controlValve.plcPort {
				flow valveCmdFlow of ValveCommand from plc.valveOutPort.valveCmd to controlValve.plcPort.cmd;
			}
			interface motorInterface connect plc.motorOutPort to conveyorMotor.plcPort {
				flow motorCmdFlow of MotorCommand from plc.motorOutPort.motorCmd to conveyorMotor.plcPort.cmd;
			}
			interface hmiStatusInterface connect plc.hmiOutPort to hmi.plcInPort {
				flow statusFlow of ProcessStatus from plc.hmiOutPort.status to hmi.plcInPort.status;
				flow alarmFlow of AlarmSignal from plc.hmiOutPort.alarm to hmi.plcInPort.alarm;
			}
			interface hmiCommandInterface connect hmi.plcOutPort to plc.hmiInPort {
				flow operatorCmdFlow of OperatorCommand from hmi.plcOutPort.cmd to plc.hmiInPort.cmd;
			}
			
			exhibit reactorStates : ReactorStates {
				in reactor = reactor;
			}
			exhibit plcStates : PLCStates {
				in plc = plc;
				in hmi = hmi;
			}
			
			satisfy SafeOperatingLimits by reactor;
			satisfy AutoAlarmGeneration by plc;
		}
	}
}
