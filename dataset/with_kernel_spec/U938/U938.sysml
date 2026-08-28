package RotationalViscometerSystem {
	private import ISQ::*;
	private import ScalarValues::*;

	value def TorqueValue :> ISQ::torque;
	value def AngularSpeedValue :> ISQ::angular_velocity;
	value def TemperatureValue :> ISQ::thermodynamic_temperature;
	value def DynamicViscosityValue :> ISQ::dynamic_viscosity;

	item def FluidSample;

	item def ViscosityResult {
		attribute viscosity : DynamicViscosityValue;
		attribute temperature : TemperatureValue;
	}

	item def MeasurementRecord {
		attribute timestamp : String;
		attribute result : ViscosityResult;
	}

	part def Spindle {
		attribute spindleConstant : Real;
		port mechanicalPort {
			in driveSpeed : AngularSpeedValue;
		}
	}

	part def SampleChamber {
		port samplePort {
			in sample : FluidSample;
		}
		part spindle : Spindle;
	}

	part def PrecisionMotor {
		port drivePort {
			out speed : AngularSpeedValue;
		}
		port controlPort {
			in targetSpeed : AngularSpeedValue;
		}
	}

	part def TorqueSensor {
		port readingPort {
			out torque : TorqueValue;
		}
	}

	part def HeatingElement {
		port controlPort {
			in powerLevel : Real;
		}
	}

	part def TemperatureSensor {
		port readingPort {
			out temperature : TemperatureValue;
		}
	}

	part def TemperatureController {
		port sensorPort {
			in currentTemp : TemperatureValue;
		}
		port heaterPort {
			out powerLevel : Real;
		}
		port targetPort {
			in targetTemp : TemperatureValue;
		}
	}

	part def TemperatureControlSystem {
		part heatingElement : HeatingElement;
		part temperatureSensor : TemperatureSensor;
		part controller : TemperatureController;

		flow tempFlow of TemperatureValue
			from temperatureSensor.readingPort.temperature to controller.sensorPort.currentTemp;
		flow powerFlow of Real
			from controller.heaterPort.powerLevel to heatingElement.controlPort.powerLevel;
	}

	calc def CalculateViscosity {
		in torque : TorqueValue;
		in speed : AngularSpeedValue;
		in constant : Real;
		return : DynamicViscosityValue = (torque * constant) / speed;
	}

	part def CentralProcessingUnit {
		port torquePort {
			in torque : TorqueValue;
		}
		port speedPort {
			in speed : AngularSpeedValue;
		}
		port tempPort {
			in temperature : TemperatureValue;
		}
		port displayPort {
			out result : ViscosityResult;
		}
		port loggerPort {
			out record : MeasurementRecord;
		}
	}

	part def DisplayUnit {
		port inputPort {
			in result : ViscosityResult;
		}
	}

	part def DataLogger {
		port inputPort {
			in record : MeasurementRecord;
		}
	}

	part def RotationalViscometer {
		part sampleChamber : SampleChamber;
		part motor : PrecisionMotor;
		part torqueSensor : TorqueSensor;
		part tempControl : TemperatureControlSystem;
		part cpu : CentralProcessingUnit;
		part display : DisplayUnit;
		part logger : DataLogger;

		connect motor.drivePort to sampleChamber.spindle.mechanicalPort;

		flow speedFlow of AngularSpeedValue
			from motor.drivePort.speed to sampleChamber.spindle.mechanicalPort.driveSpeed;
		flow torqueFlow of TorqueValue
			from torqueSensor.readingPort.torque to cpu.torquePort.torque;
		flow speedReadingFlow of AngularSpeedValue
			from motor.drivePort.speed to cpu.speedPort.speed;
		flow tempReadingFlow of TemperatureValue
			from tempControl.temperatureSensor.readingPort.temperature to cpu.tempPort.temperature;
		flow resultFlow of ViscosityResult
			from cpu.displayPort.result to display.inputPort.result;
		flow recordFlow of MeasurementRecord
			from cpu.loggerPort.record to logger.inputPort.record;
	}

	action def MeasurementProcess {
		in sample : FluidSample;
		in targetTemp : TemperatureValue;
		in targetSpeed : AngularSpeedValue;
		in spindleConstant : Real;
		out result : ViscosityResult;
		out record : MeasurementRecord;

		action loadSample;
		then action stabilizeTemperature;
		then action performMeasurement;
		then action calculateResult;
		then action reportAndLog;
		then action unloadSample;
	}

	state machine def MeasurementSequence {
		state LoadingSample;
		state StabilizingTemperature;
		state PerformingMeasurement;
		state CalculatingResult;
		state ReportingAndLogging;
		state UnloadingSample;

		transition from LoadingSample to StabilizingTemperature;
		transition from StabilizingTemperature to PerformingMeasurement;
		transition from PerformingMeasurement to CalculatingResult;
		transition from CalculatingResult to ReportingAndLogging;
		transition from ReportingAndLogging to UnloadingSample;
		transition from UnloadingSample to LoadingSample;
	}

	requirement def ViscosityMeasurementRequirement {
		subject viscometer : RotationalViscometer;
		doc "The viscometer shall measure the dynamic viscosity of a fluid sample using a rotating spindle.";
	}

	requirement def TemperatureStabilityRequirement {
		subject tempSystem : TemperatureControlSystem;
		doc "The temperature control system shall maintain the sample temperature within +/- 0.1 degrees Celsius of the setpoint.";
	}

	requirement def DataLoggingRequirement {
		subject logger : DataLogger;
		doc "The system shall log each measurement with a timestamp, viscosity value, and temperature value.";
	}

	requirement def MeasurementSequenceRequirement {
		subject viscometer : RotationalViscometer;
		doc "The system shall execute measurements in the sequence: load sample, stabilize temperature, perform measurement, calculate result, report and log, then unload sample.";
	}
}
