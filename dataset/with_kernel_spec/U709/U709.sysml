package 'Hook Gauge Evaporimeter' {
	doc /* A scientific instrument system for measuring the rate of evaporation from an open water surface. */

	private import ScalarValues::Real;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	item def StartMeasurement;
	item def MeasurementComplete;
	item def DataRecorded;
	item def ComputationComplete;

	attribute def DepthReading {
		attribute depth : LengthValue;
		attribute timestamp : TimeInstantValue;
	}

	attribute def WeatherData {
		attribute airTemp : TemperatureValue;
		attribute relativeHumidity : Real;
		attribute windSpeed : SpeedValue;
		attribute timestamp : TimeInstantValue;
		constraint { relativeHumidity >= 0 && relativeHumidity <= 100 }
	}

	attribute def EvaporationResult {
		attribute evaporationRate : SpeedValue;
		attribute levelChange : LengthValue;
		attribute interval : DurationValue;
		attribute initialReading : DepthReading;
		attribute finalReading : DepthReading;
		attribute weather : WeatherData;
	}

	port def WaterLevelPort {
		attribute waterLevel : LengthValue;
	}

	port def DepthOutputPort {
		out reading : DepthReading;
	}

	port def DepthInputPort {
		in reading : DepthReading;
	}

	port def WeatherOutputPort {
		out data : WeatherData;
	}

	port def WeatherInputPort {
		in data : WeatherData;
	}

	part def EvaporationPan {
		doc /* A standardized cylindrical pan holding water exposed to the atmosphere. */
		attribute diameter : LengthValue = 1.2 [m];
		attribute panDepth : LengthValue = 0.25 [m];
		attribute waterLevel : LengthValue;
		port surfacePort : WaterLevelPort;
		constraint { waterLevel >= 0 [m] && waterLevel <= panDepth }
	}

	part def StillingWell {
		doc /* A smaller vertical tube that dampens waves and ripples on the water surface. */
		attribute wellDiameter : LengthValue = 0.1 [m];
		attribute wellHeight : LengthValue = 0.3 [m];
		port panSide : WaterLevelPort;
		port gaugeSide : WaterLevelPort;
	}

	part def HookGauge {
		doc /* A high-precision mechanical device with a pointed hook to determine water level. */
		attribute resolution : LengthValue = 0.1 [mm];
		attribute hookPosition : LengthValue;
		port wellPort : WaterLevelPort;
		port dataPort : DepthOutputPort;

		action measureDepth {
			in waterLevel : LengthValue;
			out reading : DepthReading;
		}
	}

	part def DataLogger {
		doc /* Records depth readings and weather data with timestamps, and computes evaporation rate. */
		attribute depthReadings : DepthReading[0..*];
		attribute weatherRecords : WeatherData[0..*];
		attribute results : EvaporationResult[0..*];
		port depthPort : DepthInputPort;
		port weatherPort : WeatherInputPort;

		action recordData {
			in reading : DepthReading;
			in weather : WeatherData;
		}

		calc computeEvaporationRate {
			in initial : DepthReading;
			in final : DepthReading;
			in delta_t : DurationValue;
			in weather : WeatherData;
			attribute delta : LengthValue = initial.depth - final.depth;
			return attribute result : EvaporationResult {
				:>> evaporationRate = delta / delta_t;
				:>> levelChange = delta;
				:>> interval = delta_t;
				:>> initialReading = initial;
				:>> finalReading = final;
				:>> weather = weather;
			}
		}
	}

	part def WeatherStation {
		doc /* Monitors environmental factors that influence evaporation. */
		port dataPort : WeatherOutputPort;

		action observeWeather {
			out data : WeatherData;
		}
	}

	requirement def MeasureEvaporationRate {
		doc /* The system shall measure the rate of evaporation from an open water surface. */
		subject instrument : HookGaugeEvaporimeterSystem;
	}

	requirement def DampenSurfaceWaves {
		doc /* The stilling well shall dampen waves and ripples to enable precise hook gauge readings. */
		subject well : StillingWell;
	}

	requirement def RecordTimestampedReadings {
		doc /* The data logger shall record depth readings with their timestamps. */
		subject logger : DataLogger;
	}

	requirement def MonitorEnvironmentalFactors {
		doc /* The weather station shall monitor air temperature, relative humidity, and wind speed. */
		subject station : WeatherStation;
	}

	requirement def ComputeEvaporationRateRequirement {
		doc /* The system shall compute evaporation rate by comparing water level change over the measurement interval. */
		subject logger : DataLogger;
	}

	part def HookGaugeEvaporimeterSystem {
		doc /* Complete evaporimeter system integrating pan, stilling well, hook gauge, data logger, and weather station. */
		attribute measurementInterval : DurationValue = 24 [h];
		attribute stabilizationPeriod : DurationValue = 10 [min];
		attribute panDiameter : LengthValue = 1.2 [m];

		part pan : EvaporationPan {
			:>> diameter = panDiameter;
		}
		part stillingWell : StillingWell;
		part hookGauge : HookGauge;
		part dataLogger : DataLogger;
		part weatherStation : WeatherStation;

		connection panToWell connect pan.surfacePort to stillingWell.panSide;
		connection wellToGauge connect stillingWell.gaugeSide to hookGauge.wellPort;
		connection gaugeToLogger connect hookGauge.dataPort to dataLogger.depthPort;
		connection weatherToLogger connect weatherStation.dataPort to dataLogger.weatherPort;

		state operationCycle {
			entry; then idle;

			state idle;
			accept StartMeasurement then measuring;

			state measuring {
				entry perform hookGauge.measureDepth;
			}
			accept MeasurementComplete then stabilizing;

			state stabilizing;
			accept after stabilizationPeriod then recording;

			state recording {
				entry perform dataLogger.recordData;
			}
			accept DataRecorded then computing;

			state computing {
				entry perform dataLogger.computeEvaporationRate;
			}
			accept ComputationComplete then idle;
		}
	}
}
