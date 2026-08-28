package 'Digital Temperature Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Types {
		item def RawReading {
			attribute temp : TemperatureValue;
			attribute timestamp : TimeValue;
			attribute quality : Real;
		}
		item def ProcessedReading {
			attribute temp : TemperatureValue;
			attribute status : AlertStatus;
		}
		enum def AlertStatus {
			normal;
			warning;
			critical;
		}
		
		attribute def Activate;
		attribute def Calibrate;
		attribute def ExitCalibration;
		attribute def ProcessingComplete;
		attribute def DisplayComplete;
	}
	
	package Definitions {
		private import Types::*;
		
		action def 'Evaluate Temperature' {
			in raw : RawReading;
			out processed : ProcessedReading;
		}
		
		part def TemperatureSensor {
			attribute minRange : TemperatureValue = -40 [degC];
			attribute maxRange : TemperatureValue = 150 [degC];
			attribute accuracy : TemperatureValue = 0.5 [degC];
			port rawOut { out rawReading : RawReading; }
			
			exhibit state sensorStates {
				entry; then sensing;
				state sensing;
			}
		}
		
		part def CentralProcessor {
			attribute warningThreshold : TemperatureValue = 80 [degC];
			attribute criticalThreshold : TemperatureValue = 100 [degC];
			attribute samplingInterval : TimeValue = 1 [s];
			attribute currentTemp : TemperatureValue;
			port rawIn { in rawReading : RawReading; }
			port processedOut { out processedReading : ProcessedReading; }
			
			perform action 'evaluate temperature' : 'Evaluate Temperature';
			
			exhibit state processorStates {
				entry; then idle;
				state idle;
				accept rawReading : RawReading via rawIn then processing;
				state processing {
					entry 'evaluate temperature';
				}
				accept ProcessingComplete then idle;
			}
		}
		
		part def DigitalDisplay {
			port processedIn { in processedReading : ProcessedReading; }
			
			exhibit state displayStates {
				entry; then blank;
				state blank;
				accept processedReading : ProcessedReading via processedIn then showing;
				state showing;
				accept DisplayComplete then blank;
			}
		}
		
		part def TemperatureGauge {
			part sensor : TemperatureSensor;
			part processor : CentralProcessor;
			part display : DigitalDisplay;
			
			exhibit state gaugeModes {
				entry; then standby;
				state standby;
				accept Activate then active;
				state active {
					entry; then normal;
					state normal;
					accept when processor.currentTemp > processor.warningThreshold then warning;
					state warning;
					accept when processor.currentTemp > processor.criticalThreshold then critical;
					state critical;
					accept when processor.currentTemp < processor.warningThreshold then normal;
				}
				accept Calibrate then calibration;
				state calibration;
				accept ExitCalibration then standby;
			}
		}
	}
	
	package Usages {
		private import Definitions::*;
		private import Types::*;
		
		part gauge : TemperatureGauge {
			flow rawFlow of RawReading 
				from sensor.rawOut.rawReading to processor.rawIn.rawReading;
			flow processedFlow of ProcessedReading 
				from processor.processedOut.processedReading to display.processedIn.processedReading;
		}
	}
	
	package Requirements {
		private import Definitions::*;
		
		requirement def 'Temperature Gauge Requirements' {
			requirement sensorRange {
				subject sensor : TemperatureSensor;
				constraint { sensor.minRange == -40 [degC] and sensor.maxRange == 150 [degC] }
			}
			requirement sensorAccuracy {
				subject sensor : TemperatureSensor;
				constraint { sensor.accuracy <= 0.5 [degC] }
			}
			requirement processorThresholds {
				subject processor : CentralProcessor;
				constraint { processor.warningThreshold == 80 [degC] and processor.criticalThreshold == 100 [degC] }
			}
			requirement processorSampling {
				subject processor : CentralProcessor;
				constraint { processor.samplingInterval == 1 [s] }
			}
		}
	}
}
