package 'Atmospheric Ozone Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		enum def AirQualityLevel { good, moderate, unhealthy, hazardous }
		
		item def SampleData {
			attribute ozoneLevel : Real;
			attribute temperature : TemperatureValue;
			attribute humidity : Real;
		}
		
		item def ProcessedData {
			attribute ozoneConcentration : Real;
			attribute aqi : Integer;
			attribute level : AirQualityLevel;
			attribute isHazardous : Boolean;
		}
		
		attribute def AlarmSignal;
		attribute def PowerSignal;
		attribute def StartSignal;
		attribute def ResetSignal;
		attribute def MeasurementCompleteSignal;
		attribute def ProcessingCompleteSignal;
		attribute def DisplayCompleteSignal;
		
		port def PowerOutPort { out power : PowerSignal; }
		port def PowerInPort { in power : PowerSignal; }
		port def SampleOutPort { out sample : SampleData; }
		port def SampleInPort { in sample : SampleData; }
		port def ProcessedOutPort { out processed : ProcessedData; }
		port def ProcessedInPort { in processed : ProcessedData; }
		port def AlarmOutPort { out alarm : AlarmSignal; }
		port def AlarmInPort { in alarm : AlarmSignal; }
		
		action def SampleAir {
			out sample : SampleData;
		}
		
		action def ProcessData {
			in sample : SampleData;
			out processed : ProcessedData;
			out alarm : AlarmSignal;
			out isHazardous : Boolean;
		}
		
		action def DisplayResults {
			in processed : ProcessedData;
		}
		
		action def LogRecord {
			in processed : ProcessedData;
		}
		
		action def ActivateAlarm {
			in alarm : AlarmSignal;
		}
		
		state def SystemStates;
		
		part def OzoneSensor {
			port powerIn : PowerInPort;
			port sampleOut : SampleOutPort;
			perform action sample : SampleAir;
		}
		
		part def DataProcessor {
			port powerIn : PowerInPort;
			port sampleIn : SampleInPort;
			port processedOut : ProcessedOutPort;
			port alarmOut : AlarmOutPort;
			perform action process : ProcessData;
			attribute hazardThreshold : Real;
		}
		
		part def DisplayUnit {
			port powerIn : PowerInPort;
			port processedIn : ProcessedInPort;
			perform action display : DisplayResults;
		}
		
		part def DataLogger {
			port powerIn : PowerInPort;
			port processedIn : ProcessedInPort;
			perform action log : LogRecord;
		}
		
		part def AlarmUnit {
			port powerIn : PowerInPort;
			port alarmIn : AlarmInPort;
			perform action alarm : ActivateAlarm;
		}
		
		part def PowerModule {
			port powerOut : PowerOutPort;
		}
		
		part def OzoneMonitoringSystem {
			attribute sampleInterval : TimeValue;
			attribute hazardThreshold : Real;
			
			part ozoneSensor : OzoneSensor;
			part dataProcessor : DataProcessor;
			part displayUnit : DisplayUnit;
			part dataLogger : DataLogger;
			part alarmUnit : AlarmUnit;
			part powerModule : PowerModule;
			
			exhibit state systemStates : SystemStates;
		}
		
		requirement def ContinuousMonitoring {
			doc /* The system shall continuously measure ozone concentration in the air. */
		}
		requirement def AQICalculation {
			doc /* The system shall calculate the Air Quality Index from ozone concentration. */
		}
		requirement def HazardAlert {
			doc /* The system shall alert users when ozone levels become hazardous. */
		}
		requirement def DataLogging {
			doc /* The system shall store historical measurement data for trend analysis. */
		}
		requirement def RealtimeDisplay {
			doc /* The system shall provide a real-time visual readout of ozone concentration, AQI, and alert status. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part ozoneSystem : OzoneMonitoringSystem {
			action measure : SampleAir;
			action process : ProcessData {
				in sample = measure.sample;
				out processed;
				out alarm;
				out isHazardous;
			}
			action display : DisplayResults {
				in processed = process.processed;
			}
			action log : LogRecord {
				in processed = process.processed;
			}
			action triggerAlarm : ActivateAlarm {
				in alarm = process.alarm;
			}
			
			flow powerFlow1 of PowerSignal from powerModule.powerOut.power to ozoneSensor.powerIn.power;
			flow powerFlow2 of PowerSignal from powerModule.powerOut.power to dataProcessor.powerIn.power;
			flow powerFlow3 of PowerSignal from powerModule.powerOut.power to displayUnit.powerIn.power;
			flow powerFlow4 of PowerSignal from powerModule.powerOut.power to dataLogger.powerIn.power;
			flow powerFlow5 of PowerSignal from powerModule.powerOut.power to alarmUnit.powerIn.power;
			flow sampleFlow of SampleData from ozoneSensor.sampleOut.sample to dataProcessor.sampleIn.sample;
			flow displayFlow of ProcessedData from dataProcessor.processedOut.processed to displayUnit.processedIn.processed;
			flow logFlow of ProcessedData from dataProcessor.processedOut.processed to dataLogger.processedIn.processed;
			flow alarmFlow of AlarmSignal from dataProcessor.alarmOut.alarm to alarmUnit.alarmIn.alarm;
			
			exhibit state systemStates : SystemStates parallel {
				state 'monitoring cycle' {
					entry; then idle;
					state idle;
					accept StartSignal
						then measuring;
					state measuring {
						entry measure;
					}
					accept MeasurementCompleteSignal
						then processing;
					state processing {
						entry process;
					}
					accept ProcessingCompleteSignal
						then displaying;
					state displaying {
						entry display;
						do log;
					}
					accept DisplayCompleteSignal
						then idle;
				}
				state 'alarm management' {
					entry; then normal;
					state normal;
					accept when process.isHazardous
						then alarming;
					state alarming {
						entry triggerAlarm;
					}
					accept ResetSignal
						then normal;
				}
			}
		}
		
		requirement continuousMonitoring : ContinuousMonitoring;
		requirement aqiCalculation : AQICalculation;
		requirement hazardAlert : HazardAlert;
		requirement dataLogging : DataLogging;
		requirement realtimeDisplay : RealtimeDisplay;
		
		satisfy continuousMonitoring by ozoneSystem;
		satisfy aqiCalculation by ozoneSystem;
		satisfy hazardAlert by ozoneSystem;
		satisfy dataLogging by ozoneSystem;
		satisfy realtimeDisplay by ozoneSystem;
	}
}
