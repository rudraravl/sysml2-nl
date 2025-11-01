// Model a weather station that collects temperature, humidity, and wind speed data and is able to transmit it.
package 'Weather Station System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	// Value Type Definitions
	attribute def RelativeHumidity :> Real {
		doc /* Represents relative humidity as a percentage. */
		constraint Bounded { 0.0 <= self and self <= 100.0 }
	}

	// Item Definition for Data Packet
	item def WeatherReport {
		attribute temperature : ISQ::TemperatureValue;
		attribute humidity : RelativeHumidity;
		attribute windSpeed : ISQ::VelocityValue;
		attribute timestamp : String;
	}

	// Port Definitions for typed interactions
	port def TemperatureDataPort {
		out item reading : ISQ::TemperatureValue;
	}

	port def HumidityDataPort {
		out item reading : RelativeHumidity;
	}

	port def WindSpeedDataPort {
		out item reading : ISQ::VelocityValue;
	}

	port def ReportDataPort {
		in item report : WeatherReport;
	}

	// Abstract Sensor Definition
	abstract part def Sensor {
		attribute accuracy : Real;
		action read;
	}

	// Concrete Component Definitions
	part def TemperatureSensor :> Sensor {
		attribute :>> accuracy = 0.5; // in Celsius
		port dataOut : TemperatureDataPort;
		action read {
			out result : ISQ::TemperatureValue;
		}
	}

	part def HumiditySensor :> Sensor {
		attribute :>> accuracy = 2.0; // in Percent
		port dataOut : HumidityDataPort;
		action read {
			out result : RelativeHumidity;
		}
	}

	part def Anemometer :> Sensor {
		attribute :>> accuracy = 0.1; // in m/s
		port dataOut : WindSpeedDataPort;
		action read {
			out result : ISQ::VelocityValue;
		}
	}

	part def ControlUnit {
		port tempIn : TemperatureDataPort { in; }
		port humidityIn : HumidityDataPort { in; }
		port windIn : WindSpeedDataPort { in; }
		port reportOut : ReportDataPort { out; }

		action aggregate {
			in temp : ISQ::TemperatureValue;
			in humid : RelativeHumidity;
			in wind : ISQ::VelocityValue;
			out report : WeatherReport;
		}
	}

	part def Transmitter {
		port dataIn : ReportDataPort;
		action transmit {
			in report : WeatherReport;
		}
	}

	// System Assembly
	part def WeatherStation {
		part tempSensor : TemperatureSensor;
		part humiditySensor : HumiditySensor;
		part windSensor : Anemometer;
		part controller : ControlUnit;
		part transmitter : Transmitter;

		connect from tempSensor.dataOut to controller.tempIn;
		connect from humiditySensor.dataOut to controller.humidityIn;
		connect from windSensor.dataOut to controller.windIn;
		connect from controller.reportOut to transmitter.dataIn;

		state machine MainBehavior {
			initial state Idle;

			state Sensing {
				entry do {
					tempSensor.read();
					humiditySensor.read();
					windSensor.read();
				}
				transition to Aggregating on completion;
			}

			state Aggregating {
				entry do controller.aggregate(
					temp = controller.tempIn.reading,
					humid = controller.humidityIn.reading,
					wind = controller.windIn.reading
				);
				transition to Transmitting on completion;
			}

			state Transmitting {
				entry do transmitter.transmit(report = transmitter.dataIn.report);
				transition to Idle on completion;
			}

			state Idle {
				transition to Sensing after 60 s;
			}
		}
	}

	// Requirements Definition
	package Requirements {
		requirement def DataCollection {
			id = "R-1";
			doc "The system shall collect key environmental data.";
		}
		requirement def TemperatureSensing refines DataCollection {
			id = "R-1.1";
			doc "The system shall measure ambient temperature with an accuracy of at least +/- 0.5 degrees Celsius.";
		}
		requirement def HumiditySensing refines DataCollection {
			id = "R-1.2";
			doc "The system shall measure relative humidity with an accuracy of at least +/- 2%.";
		}
		requirement def WindSpeedSensing refines DataCollection {
			id = "R-1.3";
			doc "The system shall measure wind speed with an accuracy of at least +/- 0.1 m/s.";
		}
		requirement def DataTransmission {
			id = "R-2";
			doc "The system shall periodically transmit the collected data package.";
		}
		requirement def TransmissionPeriod refines DataTransmission {
			id = "R-2.1";
			doc "The data transmission shall occur once every 60 seconds.";
		}
	}

	// Allocation of Requirements to Model Elements
	satisfy by WeatherStation::tempSensor { from Requirements::TemperatureSensing; }
	satisfy by WeatherStation::humiditySensor { from Requirements::HumiditySensing; }
	satisfy by WeatherStation::windSensor { from Requirements::WindSpeedSensing; }
	satisfy by WeatherStation::transmitter { from Requirements::DataTransmission; }
	satisfy by WeatherStation::MainBehavior { from Requirements::TransmissionPeriod; }
}
