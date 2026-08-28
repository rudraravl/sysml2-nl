package 'Continuous Glucose Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;
	import Definitions::*;

	package Definitions {
		attribute def GlucoseConcentration :> Real {
			doc /* Glucose concentration measured in mg/dL */
		}
		attribute def GlucoseRate :> Real {
			doc /* Rate of glucose change in mg/dL per minute */
		}
		attribute def BatteryLevel :> Real {
			doc /* Battery charge level as percentage 0 to 100 */
		}

		enum def TrendArrow {
			RISING;
			FALLING;
			STEADY;
			RISING_RAPIDLY;
			FALLING_RAPIDLY;
		}
		enum def AlertLevel {
			NONE;
			LOW;
			HIGH;
			CRITICAL_LOW;
			CRITICAL_HIGH;
		}
		enum def AlertDelivery {
			AUDIO;
			VIBRATION;
			AUDIO_AND_VIBRATION;
		}

		item def InterstitialFluid;
		item def RawSensorData {
			attribute glucoseLevel : GlucoseConcentration;
			attribute timestamp : Integer;
		}
		item def ProcessedReading {
			attribute glucoseLevel : GlucoseConcentration;
			attribute timestamp : Integer;
			attribute trend : TrendArrow;
			attribute rate : GlucoseRate;
			attribute predictedLevel : GlucoseConcentration;
		}
		item def CalibrationValue {
			attribute glucoseLevel : GlucoseConcentration;
			attribute timestamp : Integer;
		}
		item def AlertMessage {
			attribute level : AlertLevel;
			attribute glucoseLevel : GlucoseConcentration;
			attribute timestamp : Integer;
			attribute delivery : AlertDelivery;
		}

		port def FluidContactPort { in item fluid : InterstitialFluid; }
		port def RawDataOutputPort { out item data : RawSensorData; }
		port def RawDataInputPort { in item data : RawSensorData; }
		port def ProcessedDataOutputPort { out item data : ProcessedReading; }
		port def ProcessedDataInputPort { in item data : ProcessedReading; }
		port def AlertOutputPort { out item alert : AlertMessage; }
		port def AlertInputPort { in item alert : AlertMessage; }
		port def CalibrationOutputPort { out item calibration : CalibrationValue; }
		port def CalibrationInputPort { in item calibration : CalibrationValue; }

		action def MeasureGlucose {
			in item fluid : InterstitialFluid;
			out item data : RawSensorData;
		}
		action def FilterNoise {
			in item raw : RawSensorData;
			out item filtered : RawSensorData;
		}
		action def CalculateTrend {
			in item current : RawSensorData;
			in item previous : RawSensorData[0..*];
			out attribute rate : GlucoseRate;
			out attribute trend : TrendArrow;
		}
		action def PredictGlucose {
			in item readings : ProcessedReading[0..*];
			out attribute predicted : GlucoseConcentration;
		}
		action def ProcessData {
			in item raw : RawSensorData;
			in item calibration : CalibrationValue;
			in item history : ProcessedReading[0..*];
			out item processed : ProcessedReading;
		}
		action def TransmitData {
			in item data : ProcessedReading;
		}
		action def ReceiveData {
			out item data : ProcessedReading;
		}
		action def DisplayReading {
			in item reading : ProcessedReading;
		}
		action def GenerateAlert {
			in item reading : ProcessedReading;
			out item alert : AlertMessage;
		}
		action def DeliverAlert {
			in item alert : AlertMessage;
		}
		action def PerformCalibration {
			in attribute bloodGlucose : GlucoseConcentration;
			out item calibration : CalibrationValue;
		}
		action def StoreReading {
			in item reading : ProcessedReading;
		}
		action def OperateReceiver {
			in item data : ProcessedReading;
		}

		part def Sensor {
			attribute lifespanDays : Integer = 10;
			attribute measurementIntervalMin : Integer = 5;
			port fluidContactPort : FluidContactPort;
			port dataOutputPort : RawDataOutputPort;
			part filament;
			perform action measure : MeasureGlucose;
			exhibit state 'sensor states' : 'Sensor States';
		}
		part def Transmitter {
			attribute wirelessRangeMeters : Real = 6.0;
			attribute batteryLevel : BatteryLevel = 100;
			port dataInputPort : ProcessedDataInputPort;
			port wirelessOutputPort : ProcessedDataOutputPort;
			perform action process : ProcessData;
			perform action transmit : TransmitData;
			exhibit state 'transmitter states' : 'Transmitter States';
		}
		part def Receiver {
			attribute storageCapacityDays : Integer = 90;
			port wirelessInputPort : ProcessedDataInputPort;
			port alertPort : AlertInputPort;
			port calibrationSendPort : CalibrationOutputPort;
			perform action receive : ReceiveData;
			perform action display : DisplayReading;
			perform action deliverAlert : DeliverAlert;
			perform action store : StoreReading;
			perform action operate : OperateReceiver;
			exhibit state 'receiver states' : 'Receiver States';
		}
		part def DataAnalysisProcessor {
			port rawDataPort : RawDataInputPort;
			port calibrationPort : CalibrationInputPort;
			port processedDataPort : ProcessedDataOutputPort;
			perform action filterNoise : FilterNoise;
			perform action calculateTrend : CalculateTrend;
			perform action predict : PredictGlucose;
			perform action process : ProcessData;
		}
		part def AlertManager {
			attribute lowThreshold : GlucoseConcentration = 70;
			attribute highThreshold : GlucoseConcentration = 180;
			attribute criticalLowThreshold : GlucoseConcentration = 54;
			attribute criticalHighThreshold : GlucoseConcentration = 250;
			port readingInputPort : ProcessedDataInputPort;
			port alertOutputPort : AlertOutputPort;
			perform action generateAlert : GenerateAlert;
			exhibit state 'alert states' : 'Alert States';
		}
		part def CalibrationManager {
			attribute calibrationIntervalHours : Integer = 12;
			port bloodGlucoseInputPort : CalibrationInputPort;
			port calibrationOutputPort : CalibrationOutputPort;
			perform action performCalibration : PerformCalibration;
			exhibit state 'calibration states' : 'Calibration States';
		}
		part def CGMSystem {
			part sensor : Sensor;
			part transmitter : Transmitter;
			part receiver : Receiver;
			part dataProcessor : DataAnalysisProcessor;
			part alertManager : AlertManager;
			part calibrationManager : CalibrationManager;

			connect sensor.dataOutputPort to dataProcessor.rawDataPort;
			connect dataProcessor.processedDataPort to alertManager.readingInputPort;
			connect alertManager.alertOutputPort to receiver.alertPort;
			connect dataProcessor.processedDataPort to transmitter.dataInputPort;
			connect transmitter.wirelessOutputPort to receiver.wirelessInputPort;
			connect calibrationManager.calibrationOutputPort to dataProcessor.calibrationPort;
			connect receiver.calibrationSendPort to calibrationManager.bloodGlucoseInputPort;
		}

		state def 'Sensor States';
		state def 'Transmitter States';
		state def 'Receiver States';
		state def 'Alert States';
		state def 'Calibration States';

		attribute def 'Power On';
		attribute def 'Power Off';
		attribute def 'Sensor Inserted';
		attribute def 'Sensor Expired';
		attribute def 'Data Ready';
		attribute def 'Transmission Complete';
		attribute def 'Low Battery Warning';
		attribute def 'Calibration Due';
		attribute def 'Calibration Received';
		attribute def 'Alert Acknowledged';
		attribute def 'Glucose Low';
		attribute def 'Glucose High';
		attribute def 'Glucose Critical Low';
		attribute def 'Glucose Critical High';
	}

	package Usages {
		private import Definitions::*;

		action measure : MeasureGlucose;
		action filterNoise : FilterNoise;
		action calculateTrend : CalculateTrend;
		action predict : PredictGlucose;
		action processData : ProcessData;
		action transmit : TransmitData;
		action receive : ReceiveData;
		action display : DisplayReading;
		action generateAlert : GenerateAlert;
		action deliverAlert : DeliverAlert;
		action performCalibration : PerformCalibration;
		action storeReading : StoreReading;
		action operateReceiver : OperateReceiver;

		part cgmSystem : CGMSystem;

		state 'sensor states' : 'Sensor States' {
			entry; then inserted;
			state inserted;
			accept 'Sensor Inserted'
				then active;
			state active {
				do measure;
			}
			accept 'Sensor Expired'
				then expired;
			state expired;
		}

		state 'transmitter states' : 'Transmitter States' {
			entry; then idle;
			state idle;
			accept 'Data Ready'
				then processing;
			state processing {
				entry processData;
			}
			accept 'Transmission Complete'
				then idle;
			accept 'Low Battery Warning'
				then lowBattery;
			state lowBattery;
		}

		state 'receiver states' : 'Receiver States' {
			entry; then off;
			state off;
			accept 'Power On'
				then on;
			state on {
				do operateReceiver;
			}
			accept 'Power Off'
				then off;
		}

		state 'alert states' : 'Alert States' parallel {
			state 'standard monitoring' {
				entry; then normal;
				state normal {
					do generateAlert;
				}
				accept 'Glucose Low'
					do deliverAlert
					then lowAlert;
				accept 'Glucose High'
					do deliverAlert
					then highAlert;
				state lowAlert;
				accept 'Alert Acknowledged'
					then normal;
				state highAlert;
				accept 'Alert Acknowledged'
					then normal;
			}
			state 'critical monitoring' {
				entry; then stable;
				state stable {
					do generateAlert;
				}
				accept 'Glucose Critical Low'
					do deliverAlert
					then criticalLow;
				accept 'Glucose Critical High'
					do deliverAlert
					then criticalHigh;
				state criticalLow;
				accept 'Alert Acknowledged'
					then stable;
				state criticalHigh;
				accept 'Alert Acknowledged'
					then stable;
			}
		}

		state 'calibration states' : 'Calibration States' {
			entry; then calibrated;
			state calibrated;
			accept 'Calibration Due'
				then awaitingCalibration;
			state awaitingCalibration;
			accept 'Calibration Received'
				do performCalibration
				then calibrated;
		}

		requirement def 'CGM Accuracy Requirement' {
			doc /* The CGM system shall measure glucose within +/- 20 mg/dL of reference */
			attribute maxError : GlucoseConcentration = 20;
			subject cgm : CGMSystem;
		}
		requirement def 'Sensor Lifespan Requirement' {
			doc /* The sensor shall function accurately for at least 10 days before replacement */
			attribute minLifespanDays : Integer = 10;
			subject sensorPart : Sensor;
		}
		requirement def 'Wireless Range Requirement' {
			doc /* The transmitter shall transmit data wirelessly over a range of up to 6 meters */
			attribute minRangeMeters : Real = 6.0;
			subject transmitterPart : Transmitter;
		}
		requirement def 'Data Storage Requirement' {
			doc /* The receiver shall store up to 90 days of historical glucose data */
			attribute minStorageDays : Integer = 90;
			subject receiverPart : Receiver;
		}
		requirement def 'Alert Threshold Requirement' {
			doc /* The system shall alert when glucose falls below 70 mg/dL or rises above 180 mg/dL */
			attribute lowThreshold : GlucoseConcentration = 70;
			attribute highThreshold : GlucoseConcentration = 180;
			subject alertManagerPart : AlertManager;
		}
		requirement def 'Critical Alert Requirement' {
			doc /* The system shall generate urgent alerts for critically low or high glucose levels */
			attribute criticalLowThreshold : GlucoseConcentration = 54;
			attribute criticalHighThreshold : GlucoseConcentration = 250;
			subject alertManagerPart : AlertManager;
		}
		requirement def 'Calibration Interval Requirement' {
			doc /* The system shall require calibration via fingerstick at least once every 12 hours */
			attribute maxIntervalHours : Integer = 12;
			subject calibrationManagerPart : CalibrationManager;
		}
		requirement def 'Measurement Interval Requirement' {
			doc /* The sensor shall take a new glucose reading every 5 minutes */
			attribute intervalMinutes : Integer = 5;
			subject sensorPart : Sensor;
		}
		requirement def 'Prediction Requirement' {
			doc /* The system shall predict glucose levels up to 30 minutes into the future */
			attribute predictionHorizonMinutes : Integer = 30;
			subject dataProcessorPart : DataAnalysisProcessor;
		}

		requirement 'cgm accuracy' : 'CGM Accuracy Requirement';
		requirement 'sensor lifespan' : 'Sensor Lifespan Requirement';
		requirement 'wireless range' : 'Wireless Range Requirement';
		requirement 'data storage' : 'Data Storage Requirement';
		requirement 'alert thresholds' : 'Alert Threshold Requirement';
		requirement 'critical alerts' : 'Critical Alert Requirement';
		requirement 'calibration interval' : 'Calibration Interval Requirement';
		requirement 'measurement interval' : 'Measurement Interval Requirement';
		requirement 'prediction horizon' : 'Prediction Requirement';
	}
}
