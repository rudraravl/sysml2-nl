package CO2SensingUnitModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	value def CO2Concentration :> Real { unit 'ppm'; }
	value def Temperature :> Real { unit 'K'; }
	value def RelativeHumidity :> Real { unit '%'; }
	value def Voltage :> Real { unit 'V'; }
	value def Duration :> Real { unit 's'; }

	item def AirSample {
		attribute temp : Temperature;
		attribute humidity : RelativeHumidity;
	}
	item def RawCO2Reading {
		attribute value : CO2Concentration;
	}
	item def CompensatedReading {
		attribute value : CO2Concentration;
	}
	item def MeasurementReport {
		attribute concentration : CO2Concentration;
		attribute timestamp : String;
		attribute status : String;
	}

	attribute def WarmUpCommand;
	attribute def MeasureCommand;
	attribute def ResetCommand;
	attribute def ErrorEvent;
	attribute def WarmedUpEvent;
	attribute def MeasurementCompleteEvent;

	port def AirIntakePort {
		in sample : AirSample;
	}
	port def PowerPort {
		out voltage : Voltage;
	}
	port def DataOutPort {
		out report : MeasurementReport;
	}
	port def RawDataPort {
		out reading : RawCO2Reading;
	}

	requirement def MeasurementAccuracy {
		doc /* The unit must measure CO2 with an accuracy of ±50 ppm. */
		attribute maxError : CO2Concentration := 50;
	}
	requirement def MeasurementRange {
		doc /* The unit must measure CO2 concentrations from 0 to 5000 ppm. */
		attribute minRange : CO2Concentration := 0;
		attribute maxRange : CO2Concentration := 5000;
	}
	requirement def ResponseTime {
		doc /* The unit must provide a valid measurement within 30 seconds of a command. */
		attribute maxTime : Duration := 30;
	}
	requirement def OperatingTempRange {
		doc /* The unit must operate reliably within a temperature range of -10°C to 50°C (263.15K to 323.15K). */
		attribute minTemp : Temperature := 263.15;
		attribute maxTemp : Temperature := 323.15;
	}

	action def WarmUp {
		out ready : Boolean;
	}
	action def DetectCO2 {
		in sample : AirSample;
		out raw : RawCO2Reading;
	}
	action def CompensateReading {
		in raw : RawCO2Reading;
		in sample : AirSample;
		out compensated : CompensatedReading;
	}
	action def ValidateReading {
		in compensated : CompensatedReading;
		out valid : Boolean;
	}
	action def CreateReport {
		in valid : Boolean;
		in compensated : CompensatedReading;
		out report : MeasurementReport;
	}

	part def PowerSupply {
		port powerIn : ~PowerPort;
		port powerOut : PowerPort;
		attribute outputVoltage : Voltage := 5.0;
		action regulate {
			in inputVoltage : Voltage;
			out outputVoltage : Voltage := 5.0;
		}
	}

	part def CO2Sensor {
		port airIntake : AirIntakePort;
		port powerIn : ~PowerPort;
		port rawDataOut : RawDataPort;

		perform action warmUp : WarmUp;
		perform action detect : DetectCO2;

		exhibit state sensorStates : SensorStates;
	}

	part def SignalProcessor {
		port rawDataIn : ~RawDataPort;
		port dataOut : DataOutPort;

		perform action compensate : CompensateReading;
		perform action validate : ValidateReading;
		perform action report : CreateReport;
	}

	state def SensorStates {
		entry; then idle;
		state idle;
		accept WarmUpCommand then warming;
		state warming {
			do warmUp;
		}
		accept when warmUp.ready then ready;
		state ready;
		accept MeasureCommand then measuring;
		state measuring {
			do detect;
		}
		accept ErrorEvent then error;
		state error;
		accept ResetCommand then idle;
	}

	part def CO2SensingUnit {
		port airIntake : AirIntakePort;
		port powerIn : ~PowerPort;
		port dataOut : DataOutPort;

		part powerSupply : PowerSupply;
		part co2Sensor : CO2Sensor;
		part signalProcessor : SignalProcessor;

		perform action warmUp : WarmUp;
		perform action detect : DetectCO2;
		perform action compensate : CompensateReading;
		perform action validate : ValidateReading;
		perform action report : CreateReport;

		satisfy MeasurementAccuracy;
		satisfy MeasurementRange;
		satisfy ResponseTime;
		satisfy OperatingTempRange;

		connection powerConn1 connect powerIn to powerSupply.powerIn;
		connection powerConn2 connect powerSupply.powerOut to co2Sensor.powerIn;
		connection airConn connect airIntake to co2Sensor.airIntake;
		connection dataConn1 connect co2Sensor.rawDataOut to signalProcessor.rawDataIn;
		connection dataConn2 connect signalProcessor.dataOut to dataOut;

		exhibit state unitStates : UnitStates;
	}

	state def UnitStates {
		entry; then idle;
		state idle;
		accept WarmUpCommand then warming;
		state warming {
			do warmUp;
		}
		accept when warmUp.ready then ready;
		state ready;
		accept MeasureCommand then measuring;
		state measuring {
			do detect;
			do compensate;
			do validate;
			do report;
		}
		accept when validate.valid then ready;
		accept ErrorEvent then error;
		state error;
		accept ResetCommand then idle;
	}

	part sensingUnit : CO2SensingUnit;
}
