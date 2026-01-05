package 'Tide Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WaterLevelReading;
	attribute def TidePhase;
	attribute def AlarmCondition;
	attribute def SystemStatus;
	attribute def CalibrationData;
	
	value def TideMeasurement {
		attribute waterLevel : LengthValue;
		attribute timestamp : TimeValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute atmosphericPressure : PressureValue;
	}
	
	value def TideAnalysis {
		attribute currentLevel : LengthValue;
		attribute tideRate : SpeedValue;
		attribute highTide : LengthValue;
		attribute lowTide : LengthValue;
		attribute nextHighTide : TimeValue;
		attribute nextLowTide : TimeValue;
	}
	
	value def AlarmThresholds {
		attribute floodLevel : LengthValue;
		attribute lowWaterLevel : LengthValue;
		attribute rapidRiseRate : SpeedValue;
	}
	
	port def SensorPort {
		out rawPressure : PressureValue;
		out temperature : ThermodynamicTemperatureValue;
		out sensorHealth : SystemStatus;
	}
	
	port def DataPort {
		out tideData : TideAnalysis;
		out alarmState : AlarmCondition;
	}
	
	port def PowerPort {
		in voltage : ElectricPotentialValue;
		in current : ElectricCurrentValue;
	}
	
	port def CommunicationPort {
		out transmitData : TideAnalysis;
		in configurationData : CalibrationData;
	}
	
	part def PressureTransducer {
		port sensorOut : SensorPort;
		port powerIn : PowerPort;
		
		attribute measurementRange : PressureValue;
		attribute resolution : PressureValue;
		attribute accuracy : Real;
	}
	
	part def TemperatureSensor {
		port powerIn : PowerPort;
		out port tempOut;
		
		attribute tempRange : ThermodynamicTemperatureValue;
		attribute tempAccuracy : ThermodynamicTemperatureValue;
	}
	
	part def DataAcquisitionUnit {
		in port sensorInput : SensorPort;
		out port processedOutput : DataPort;
		port powerIn : PowerPort;
		
		attribute samplingRate : FrequencyValue;
		attribute dataBuffer : TideMeasurement[*];
		attribute thresholds : AlarmThresholds;
	}
	
	part def TelemetrySystem {
		in port dataInput : DataPort;
		port commPort : CommunicationPort;
		port powerIn : PowerPort;
		
		attribute transmissionInterval : TimeValue;
		attribute networkProtocol : String;
	}
	
	part def PowerManagementUnit {
		out port mainPower : PowerPort;
		
		attribute batteryCapacity : EnergyValue;
		attribute solarInput : PowerValue;
		attribute batteryVoltage : ElectricPotentialValue;
	}
	
	part def MountingStructure {
		attribute installationDepth : LengthValue;
		attribute structuralRating : PressureValue;
		attribute corrosionResistance : String;
	}
	
	action def AcquirePressureReading {
		in rawPressure : PressureValue;
		in atmosphericPressure : PressureValue;
		out waterPressure : PressureValue;
	}
	
	action def ConvertPressureToLevel {
		in waterPressure : PressureValue;
		in waterDensity : MassDensityValue;
		in gravity : AccelerationValue;
		out waterLevel : LengthValue;
	}
	
	action def AnalyzeTidePattern {
		in measurements : TideMeasurement[*];
		out analysis : TideAnalysis;
	}
	
	action def EvaluateAlarms {
		in currentLevel : LengthValue;
		in tideRate : SpeedValue;
		in thresholds : AlarmThresholds;
		out alarmStatus : AlarmCondition;
	}
	
	action def TransmitTideData {
		in tideAnalysis : TideAnalysis;
		in alarmStatus : AlarmCondition;
	}
	
	action def CalibrateSystem {
		in referenceLevel : LengthValue;
		out calibrationOffset : LengthValue;
	}
	
	action def MonitorTideLevel {
		in rawPressure : PressureValue;
		in atmosphericPressure : PressureValue;
		in waterDensity : MassDensityValue;
		in gravity : AccelerationValue;
		in thresholds : AlarmThresholds;
		out tideAnalysis : TideAnalysis;
		out alarmStatus : AlarmCondition;
		
		first start;
		then merge continuousMonitoring;
		
		action acquirePressure : AcquirePressureReading {
			in rawPressure = MonitorTideLevel::rawPressure;
			in atmosphericPressure = MonitorTideLevel::atmosphericPressure;
			out waterPressure : PressureValue;
		}
		
		then action convertLevel : ConvertPressureToLevel {
			in waterPressure = acquirePressure.waterPressure;
			in waterDensity = MonitorTideLevel::waterDensity;
			in gravity = MonitorTideLevel::gravity;
			out waterLevel : LengthValue;
		}
		
		then action analyzeTide : AnalyzeTidePattern {
			in measurements : TideMeasurement[*];
			out analysis : TideAnalysis;
		}
		
		then action evaluateAlarms : EvaluateAlarms {
			in currentLevel = convertLevel.waterLevel;
			in tideRate = analyzeTide.analysis.tideRate;
			in thresholds = MonitorTideLevel::thresholds;
			out alarmStatus : AlarmCondition;
		}
		
		then decide;
			if evaluateAlarms.alarmStatus != null then transmitUrgent;
			else transmitNormal;
		
		action transmitUrgent : TransmitTideData {
			in tideAnalysis = analyzeTide.analysis;
			in alarmStatus = evaluateAlarms.alarmStatus;
		}
		then continuousMonitoring;
		
		action transmitNormal : TransmitTideData {
			in tideAnalysis = analyzeTide.analysis;
			in alarmStatus = evaluateAlarms.alarmStatus;
		}
		then continuousMonitoring;
	}
	
	part def TideGaugeSystem;
	
	part tideGaugeSystem : TideGaugeSystem {
		doc /*
		A tide gauge system continuously monitors and records water level variations
		in coastal, estuarine, and harbor environments. The primary function is to
		measure sea level changes over time by converting hydrostatic pressure
		measurements into accurate water level readings. The system acquires pressure
		data from submerged sensors, compensates for atmospheric pressure and water
		density variations, analyzes tidal patterns to identify high and low tides,
		evaluates alarm conditions against configurable thresholds for flood warning,
		and transmits processed oceanographic data to remote monitoring stations for
		maritime navigation, coastal engineering, climate research, and public safety
		applications.
		*/
		
		part pressureSensor : PressureTransducer {
			attribute :>> measurementRange = 200.0 [SI::kPa];
			attribute :>> resolution = 0.01 [SI::kPa];
			attribute :>> accuracy = 0.05;
		}
		
		part tempSensor : TemperatureSensor {
			attribute :>> tempRange = 50.0 [SI::K];
			attribute :>> tempAccuracy = 0.1 [SI::K];
		}
		
		part dataAcquisition : DataAcquisitionUnit {
			attribute :>> samplingRate = 1.0 [SI::Hz];
			attribute :>> thresholds = AlarmThresholds {
				attribute :>> floodLevel = 5.0 [SI::m];
				attribute :>> lowWaterLevel = 0.2 [SI::m];
				attribute :>> rapidRiseRate = 0.5 [SI::'m/s'];
			}
		}
		
		part telemetry : TelemetrySystem {
			attribute :>> transmissionInterval = 300.0 [SI::s];
			attribute :>> networkProtocol = "MQTT";
		}
		
		part powerManagement : PowerManagementUnit {
			attribute :>> batteryCapacity = 1000.0 [SI::Wh];
			attribute :>> solarInput = 100.0 [SI::W];
			attribute :>> batteryVoltage = 12.0 [SI::V];
		}
		
		part mounting : MountingStructure {
			attribute :>> installationDepth = 10.0 [SI::m];
			attribute :>> structuralRating = 500.0 [SI::kPa];
			attribute :>> corrosionResistance = "Marine Grade Stainless Steel";
		}
		
		connect powerManagement.mainPower to pressureSensor.powerIn;
		connect powerManagement.mainPower to tempSensor.powerIn;
		connect powerManagement.mainPower to dataAcquisition.powerIn;
		connect powerManagement.mainPower to telemetry.powerIn;
		
		connect pressureSensor.sensorOut to dataAcquisition.sensorInput;
		connect dataAcquisition.processedOutput to telemetry.dataInput;
		
		perform action monitorTides : MonitorTideLevel;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def EnvironmentalRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'TG-F-001'> measureWaterLevel : FunctionalRequirement {
		doc /* The tide gauge system shall continuously measure water level with 
		     respect to a defined datum. */
		subject system : TideGaugeSystem;
	}
	
	requirement <'TG-P-001'> measurementAccuracy : PerformanceRequirement {
		doc /* The tide gauge shall measure water level with an accuracy of ±1 cm 
		     or better. */
		subject system : TideGaugeSystem;
		require constraint {
			system.pressureSensor.accuracy <= 0.01
		}
	}
	
	requirement <'TG-P-002'> samplingRate : PerformanceRequirement {
		doc /* The tide gauge shall sample water level at a minimum rate of 1 Hz. */
		subject system : TideGaugeSystem;
		require constraint {
			system.dataAcquisition.samplingRate >= 1.0 [SI::Hz]
		}
	}
	
	requirement <'TG-P-003'> dataTransmission : PerformanceRequirement {
		doc /* The tide gauge shall transmit processed tide data at intervals not 
		     exceeding 5 minutes. */
		subject system : TideGaugeSystem;
		require constraint {
			system.telemetry.transmissionInterval <= 300.0 [SI::s]
		}
	}
	
	requirement <'TG-F-002'> floodDetection : FunctionalRequirement {
		doc /* The tide gauge shall detect and alarm when water level exceeds 
		     configurable flood thresholds. */
		subject system : TideGaugeSystem;
	}
	
	requirement <'TG-E-001'> operatingDepth : EnvironmentalRequirement {
		doc /* The tide gauge shall operate at depths up to 10 meters below mean 
		     sea level. */
		subject system : TideGaugeSystem;
		require constraint {
			system.mounting.installationDepth >= 10.0 [SI::m]
		}
	}
	
	requirement <'TG-R-001'> powerAutonomy : ReliabilityRequirement {
		doc /* The tide gauge shall operate autonomously for a minimum of 30 days 
		     without external power input. */
		subject system : TideGaugeSystem;
		require constraint {
			system.powerManagement.batteryCapacity >= 720.0 [SI::h] * 1.4 [SI::W]
		}
	}
	
	requirement <'TG-E-002'> corrosionResistance : EnvironmentalRequirement {
		doc /* The tide gauge enclosure and mounting shall resist marine corrosion 
		     for a minimum operational life of 10 years. */
		subject system : TideGaugeSystem;
	}
}
