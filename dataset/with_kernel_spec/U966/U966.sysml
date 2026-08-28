package AirPollutionMonitoringAndControlSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	enum def PollutantKind {
		PM25;
		PM10;
		OZONE;
		NO2;
		CO;
		SO2;
	}

	enum def AQICategory {
		Good;
		Moderate;
		UnhealthySensitive;
		Unhealthy;
		VeryUnhealthy;
		Hazardous;
	}

	enum def FiltrationMode {
		standby;
		active;
		highEfficiency;
	}

	enum def AlertSeverity {
		Moderate;
		Severe;
	}

	// Concentration in micrograms per cubic meter for particulate matter; parts per billion for gaseous pollutants
	value type ConcentrationValue :> Real;
	// Air Quality Index score on a 0 to 500 scale
	value type AQIScoreValue :> Integer;
	// Airflow rate in cubic meters per hour
	value type AirflowRateValue :> Real;
	// Filtration efficiency as a percentage from 0 to 100
	value type EfficiencyLevelValue :> Real;
	// Unix epoch timestamp in seconds
	value type TimestampValue :> Real;

	item def PollutantReading {
		attribute pollutantKind : PollutantKind;
		attribute concentration : ConcentrationValue;
		attribute timestamp : TimestampValue;
		attribute locationId : String;
	}

	item def PollutantReadingSet {
		attribute readings : PollutantReading[0..*];
		attribute timestamp : TimestampValue;
		attribute locationId : String;
	}

	item def AirQualityIndex {
		attribute score : AQIScoreValue;
		attribute category : AQICategory;
		attribute dominantPollutant : PollutantKind;
		attribute timestamp : TimestampValue;
		attribute locationId : String;
	}

	item def Alert {
		attribute severity : AlertSeverity;
		attribute pollutantKind : PollutantKind;
		attribute aqiCategory : AQICategory;
		attribute recommendedAction : String;
		attribute timestamp : TimestampValue;
		attribute locationId : String;
	}

	item def FiltrationCommand {
		attribute mode : FiltrationMode;
		attribute airflowRate : AirflowRateValue;
		attribute efficiencyLevel : EfficiencyLevelValue;
		attribute timestamp : TimestampValue;
	}

	action def SensePollutants {
		out readings : PollutantReadingSet;
	}

	action def ArchiveReadings {
		in readings : PollutantReadingSet;
	}

	action def CalculateAQI {
		in readings : PollutantReadingSet;
		out aqi : AirQualityIndex;
	}

	action def GenerateAlert {
		in aqi : AirQualityIndex;
		out alert : Alert;
	}

	action def GenerateFiltrationCommand {
		in aqi : AirQualityIndex;
		out command : FiltrationCommand;
	}

	state def SensorOperation {
		entry; then sensing;
		state sensing {
			do sensePollutants : SensePollutants;
		}
	}

	state def ArchiveOperation {
		entry; then idle;
		state idle;
		accept PollutantReadingSet then archiving;
		state archiving {
			do archiveReadings : ArchiveReadings;
		}
		then idle;
	}

	state def AnalyzerOperation {
		entry; then ready;
		state ready;
		accept PollutantReadingSet then computing;
		state computing {
			do calculateAQI : CalculateAQI;
		}
		then ready;
	}

	state def AlertOperation {
		entry; then monitoring;
		state monitoring;
		accept aqi : AirQualityIndex
			if aqi.score > 100
			do generateAlert : GenerateAlert
			then alerting;
		state alerting;
		accept aqi : AirQualityIndex
			if aqi.score <= 100
			then monitoring;
	}

	state def ControllerOperation {
		entry; then inactive;
		state inactive;
		accept aqi : AirQualityIndex
			if aqi.score > 150 and aqi.score <= 200
			do generateCommand : GenerateFiltrationCommand
			then commanding;
		accept aqi : AirQualityIndex
			if aqi.score > 200
			do generateHighCommand : GenerateFiltrationCommand
			then highEffMode;
		state commanding;
		accept aqi : AirQualityIndex
			if aqi.score > 200
			then highEffMode;
		accept aqi : AirQualityIndex
			if aqi.score <= 150
			then inactive;
		state highEffMode;
		accept aqi : AirQualityIndex
			if aqi.score > 150 and aqi.score <= 200
			then commanding;
		accept aqi : AirQualityIndex
			if aqi.score <= 150
			then inactive;
	}

	state def FiltrationUnitOperation {
		entry; then standby;
		state standby;
		accept cmd : FiltrationCommand
			if cmd.mode == FiltrationMode::active
			then running;
		accept cmd : FiltrationCommand
			if cmd.mode == FiltrationMode::highEfficiency
			then highEfficiency;
		state running;
		accept cmd : FiltrationCommand
			if cmd.mode == FiltrationMode::highEfficiency
			then highEfficiency;
		accept cmd : FiltrationCommand
			if cmd.mode == FiltrationMode::standby
			then standby;
		state highEfficiency;
		accept cmd : FiltrationCommand
			if cmd.mode == FiltrationMode::active
			then running;
		accept cmd : FiltrationCommand
			if cmd.mode == FiltrationMode::standby
			then standby;
	}

	part def MultiPollutantSensor {
		attribute samplingInterval : Real = 60;
		port rawReadingsPort {
			out rawReadings : PollutantReadingSet;
		}
		exhibit state sensorOp : SensorOperation;
	}

	part def DataArchiveSystem {
		port archiveInPort {
			in archiveReadings : PollutantReadingSet;
		}
		exhibit state archiveOp : ArchiveOperation;
	}

	part def AirQualityAnalyzer {
		port readingsInPort {
			in readings : PollutantReadingSet;
		}
		port aqiOutPort {
			out aqiValue : AirQualityIndex;
		}
		exhibit state analyzerOp : AnalyzerOperation;
	}

	part def PublicInformationDisplay {
		port aqiInPort {
			in displayedAQI : AirQualityIndex;
		}
		port alertInPort {
			in displayedAlert : Alert;
		}
	}

	part def AlertManagementSystem {
		attribute alertThreshold : AQIScoreValue = 100;
		port aqiInPort {
			in monitoredAQI : AirQualityIndex;
		}
		port alertOutPort {
			out issuedAlert : Alert;
		}
		exhibit state alertOp : AlertOperation;
	}

	part def AirFiltrationController {
		attribute activationThreshold : AQIScoreValue = 150;
		attribute highEfficiencyThreshold : AQIScoreValue = 200;
		port aqiInPort {
			in controllerAQI : AirQualityIndex;
		}
		port commandOutPort {
			out filtrationCommand : FiltrationCommand;
		}
		exhibit state controllerOp : ControllerOperation;
	}

	part def AirFiltrationUnit {
		port commandInPort {
			in receivedCommand : FiltrationCommand;
		}
		exhibit state unitOp : FiltrationUnitOperation;
	}

	part def AirPollutionMonitoringSystem {
		attribute locationId : String;
		attribute alertThreshold : AQIScoreValue = 100;
		attribute activationThreshold : AQIScoreValue = 150;
		attribute highEfficiencyThreshold : AQIScoreValue = 200;

		part multiPollutantSensor : MultiPollutantSensor;
		part dataArchiveSystem : DataArchiveSystem;
		part airQualityAnalyzer : AirQualityAnalyzer;
		part publicInformationDisplay : PublicInformationDisplay;
		part alertManagementSystem : AlertManagementSystem;
		part airFiltrationController : AirFiltrationController;
		part airFiltrationUnit : AirFiltrationUnit;

		flow rawReadingsToArchive of PollutantReadingSet
			from multiPollutantSensor.rawReadingsPort.rawReadings
			to dataArchiveSystem.archiveInPort.archiveReadings;
		flow rawReadingsToAnalyzer of PollutantReadingSet
			from multiPollutantSensor.rawReadingsPort.rawReadings
			to airQualityAnalyzer.readingsInPort.readings;
		flow aqiToDisplay of AirQualityIndex
			from airQualityAnalyzer.aqiOutPort.aqiValue
			to publicInformationDisplay.aqiInPort.displayedAQI;
		flow aqiToAlert of AirQualityIndex
			from airQualityAnalyzer.aqiOutPort.aqiValue
			to alertManagementSystem.aqiInPort.monitoredAQI;
		flow aqiToController of AirQualityIndex
			from airQualityAnalyzer.aqiOutPort.aqiValue
			to airFiltrationController.aqiInPort.controllerAQI;
		flow alertToDisplay of Alert
			from alertManagementSystem.alertOutPort.issuedAlert
			to publicInformationDisplay.alertInPort.displayedAlert;
		flow commandToUnit of FiltrationCommand
			from airFiltrationController.commandOutPort.filtrationCommand
			to airFiltrationUnit.commandInPort.receivedCommand;
	}

	requirement def AirQualityMonitoringRequirement {
		text "The system shall continuously monitor air quality for PM2.5, PM10, ozone, NO2, CO, and SO2 and produce AQI values with timestamps and location identifiers.";
	}

	requirement def PublicAlertingRequirement {
		text "When AQI exceeds 100 the system shall issue a public alert including severity, pollutant type, and recommended health actions.";
	}

	requirement def ActiveFiltrationRequirement {
		text "When AQI exceeds 150 the system shall activate air filtration. When AQI exceeds 200 the filtration unit shall enter high-efficiency mode.";
	}

	requirement def DataArchivingRequirement {
		text "All pollutant readings shall be archived for historical analysis and regulatory compliance.";
	}

	requirement def PublicInformationRequirement {
		text "The current AQI and any active alerts shall be displayed on the public information display.";
	}

	part system : AirPollutionMonitoringSystem;

	requirement airQualityMonitoring : AirQualityMonitoringRequirement {
		satisfy system.multiPollutantSensor;
		satisfy system.airQualityAnalyzer;
	}
	requirement publicAlerting : PublicAlertingRequirement {
		satisfy system.alertManagementSystem;
	}
	requirement activeFiltration : ActiveFiltrationRequirement {
		satisfy system.airFiltrationController;
		satisfy system.airFiltrationUnit;
	}
	requirement dataArchiving : DataArchivingRequirement {
		satisfy system.dataArchiveSystem;
	}
	requirement publicInfo : PublicInformationRequirement {
		satisfy system.publicInformationDisplay;
	}
}
