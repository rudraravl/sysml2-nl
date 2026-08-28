package 'Snow Monitoring System' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import Time::TimeInstantValue;
	private import Time::DurationValue;
	private import SI::min;

	attribute def SnowData {
		attribute timestamp : TimeInstantValue;
		attribute snowDepth : LengthValue;
		attribute snowWaterEquivalent : MassValue;
		attribute snowDensity : MassDensityValue;
		attribute ambientTemperature : TemperatureValue;
	}

	attribute def DataAcquired;
	attribute def DataProcessed;
	attribute def DataStored;
	attribute def SensorFault;
	attribute def FaultCleared;

	port def SensorDataPort {
		in/out distance : LengthValue;
		in/out weight : MassValue;
		in/out temperature : TemperatureValue;
	}

	port def DataOutPort {
		in/out snowData : SnowData;
	}

	port def DataInPort {
		in/out snowData : SnowData;
	}

	port def PowerInPort {
		in/out power : PowerValue;
	}

	port def PowerOutPort {
		in/out power : PowerValue;
	}

	part def SnowGaugeStation {
		attribute measurementInterval : DurationValue = 30 [min];

		part sensorSet : SensorSet;
		part cpu : CentralProcessingUnit;
		part storage : DataStorageUnit;
		part power : PowerSystem;

		connect sensorSet.dataOut to cpu.sensorDataIn;
		connect cpu.dataOut to storage.dataIn;
		connect power.powerOut to sensorSet.powerIn;
		connect power.powerOut to cpu.powerIn;
		connect power.powerOut to storage.powerIn;

		exhibit state operationalStates {
			entry; then standby;
			state standby;
			accept after measurementInterval then readingSensors;
			state readingSensors;
			accept DataAcquired then processing;
			state processing;
			accept DataProcessed then storing;
			state storing;
			accept DataStored then standby;
			state faulted;
			accept SensorFault then faulted;
			accept FaultCleared then standby;
		}
	}

	part def SensorSet {
		port powerIn : PowerInPort;
		port dataOut : SensorDataPort;

		part ultrasonic : UltrasonicDistanceSensor;
		part loadCell : LoadCell;
		part tempProbe : TemperatureProbe;

		connect ultrasonic.distance to dataOut.distance;
		connect loadCell.weight to dataOut.weight;
		connect tempProbe.temperature to dataOut.temperature;

		exhibit state sensorStates {
			state normal;
			accept SensorFault then faulted;
			state faulted;
			accept FaultCleared then normal;
		}
	}

	part def UltrasonicDistanceSensor {
		out distance : LengthValue;
	}

	part def LoadCell {
		out weight : MassValue;
	}

	part def TemperatureProbe {
		out temperature : TemperatureValue;
	}

	action def ProcessData {
		in sensorHeight : LengthValue;
		in distance : LengthValue;
		in weight : MassValue;
		in temperature : TemperatureValue;
		out snowData : SnowData;
	}

	part def CentralProcessingUnit {
		attribute sensorHeight : LengthValue;
		port powerIn : PowerInPort;
		port sensorDataIn : SensorDataPort;
		port dataOut : DataOutPort;

		perform action processData : ProcessData {
			in sensorHeight = sensorHeight;
			in distance = sensorDataIn.distance;
			in weight = sensorDataIn.weight;
			in temperature = sensorDataIn.temperature;
			out snowData = dataOut.snowData;
		}
	}

	part def DataStorageUnit {
		port powerIn : PowerInPort;
		port dataIn : DataInPort;

		attribute storedData : SnowData[*] := ( );
	}

	part def PowerSystem {
		port powerOut : PowerOutPort;

		part battery : Battery;
		part solarPanel : SolarPanel;

		connect solarPanel.powerOut to battery.powerIn;
		connect battery.powerOut to powerOut;
	}

	part def Battery {
		port powerIn : PowerInPort;
		port powerOut : PowerOutPort;
		attribute capacity : EnergyValue;
		attribute chargeLevel : Real;
	}

	part def SolarPanel {
		port powerOut : PowerOutPort;
		attribute powerOutput : PowerValue;
	}

	requirement def AutonomousOperation {
		subject station : SnowGaugeStation;
		constraint { station.power.battery.capacity > 0 }
	}

	requirement def MeasurementIntervalRequirement {
		subject station : SnowGaugeStation;
		constraint { station.measurementInterval == 30 [min] }
	}
}
