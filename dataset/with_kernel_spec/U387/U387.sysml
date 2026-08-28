package 'Somanatics INVOS Cerebral Oximeter' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	import Definitions::*;

	package Definitions {
		item def NearInfraredLight {
			attribute wavelength : LengthValue;
		}
		item def ReflectedLight {
			attribute wavelength : LengthValue;
			attribute intensity : Real;
		}
		item def SensorReading {
			attribute absorption730 : Real;
			attribute absorption810 : Real;
			attribute side : String;
		}
		item def RegionalOxygenSaturation {
			attribute value : Real;
			attribute side : String;
		}
		item def AlarmEvent {
			attribute severity : String;
			attribute currentValue : Real;
		}
		item def DisplayData {
			attribute leftRSO2 : Real;
			attribute rightRSO2 : Real;
			attribute trendData : Real[*];
		}
		item def StartMonitoring;
		item def StopMonitoring;
		item def InitializationComplete;

		port def LightOutputPort {
			out light : NearInfraredLight;
		}
		port def LightInputPort {
			in reflected : ReflectedLight;
		}
		port def ReadingOutputPort {
			out reading : SensorReading;
		}
		port def ReadingInputPort {
			in reading : SensorReading;
		}
		port def RSO2OutputPort {
			out rSO2 : RegionalOxygenSaturation;
		}
		port def RSO2InputPort {
			in rSO2 : RegionalOxygenSaturation;
		}
		port def PowerOutputPort {
			out power : Boolean;
		}
		port def PowerInputPort {
			in power : Boolean;
		}

		part def Patient {
			attribute brainOxygenSaturation : Real;
		}

		part def LightEmitter {
			attribute wavelength1 : LengthValue = 730 [nm];
			attribute wavelength2 : LengthValue = 810 [nm];
			port lightOut : LightOutputPort;
			perform action emitLight : EmitLight;
		}

		part def Photodetector {
			port reflectedIn : LightInputPort;
			port readingOut : ReadingOutputPort;
			perform action detectLight : DetectLight;
		}

		part def SensorHead {
			attribute side : String;
			part emitter : LightEmitter;
			part detector : Photodetector;
		}

		part def SignalProcessingUnit {
			port sensorData1 : ReadingInputPort;
			port sensorData2 : ReadingInputPort;
			port rSO2Output : RSO2OutputPort;
			port powerIn : PowerInputPort;
			perform action calculateRSO2 : CalculateRSO2;
			perform action analyzeTrends : AnalyzeTrends;
		}

		part def DisplayModule {
			port dataIn : RSO2InputPort;
			port powerIn : PowerInputPort;
			perform action updateDisplay : UpdateDisplay;
		}

		part def AlarmModule {
			attribute lowThreshold : Real = 50;
			attribute criticalThreshold : Real = 40;
			port dataIn : RSO2InputPort;
			port powerIn : PowerInputPort;
			perform action checkThresholds : CheckThresholds;
			perform action triggerAudibleAlarm : TriggerAudibleAlarm;
			perform action triggerVisualAlarm : TriggerVisualAlarm;
		}

		part def PowerSupplyUnit {
			attribute batteryBackupDuration : DurationValue = 60 [min];
			port powerOut : PowerOutputPort;
			perform action supplyPower : SupplyPower;
		}

		part def DataStorageUnit {
			port dataIn : RSO2InputPort;
			port powerIn : PowerInputPort;
			perform action storeData : StoreData;
		}

		part def INVOSOximeter {
			part patient : Patient;
			part leftSensor : SensorHead {
				attribute side : String = "left";
			}
			part rightSensor : SensorHead {
				attribute side : String = "right";
			}
			part processor : SignalProcessingUnit;
			part display : DisplayModule;
			part alarm : AlarmModule;
			part power : PowerSupplyUnit;
			part storage : DataStorageUnit;

			connect leftSensor.detector.readingOut to processor.sensorData1;
			connect rightSensor.detector.readingOut to processor.sensorData2;
			connect processor.rSO2Output to display.dataIn;
			connect processor.rSO2Output to storage.dataIn;
			connect processor.rSO2Output to alarm.dataIn;
			connect power.powerOut to processor.powerIn;
			connect power.powerOut to display.powerIn;
			connect power.powerOut to alarm.powerIn;
			connect power.powerOut to storage.powerIn;

			exhibit state systemStates : SystemStates;
		}

		action def EmitLight {
			out light : NearInfraredLight;
		}
		action def DetectLight {
			in reflected : ReflectedLight;
			out reading : SensorReading;
		}
		action def CalculateRSO2 {
			in reading1 : SensorReading;
			in reading2 : SensorReading;
			out rSO2 : RegionalOxygenSaturation;
		}
		action def AnalyzeTrends {
			in data : RegionalOxygenSaturation[*];
			out trend : DisplayData;
		}
		action def UpdateDisplay {
			in data : RegionalOxygenSaturation;
		}
		action def CheckThresholds {
			in rSO2 : RegionalOxygenSaturation;
			out alarmTriggered : Boolean;
		}
		action def TriggerAudibleAlarm;
		action def TriggerVisualAlarm;
		action def SupplyPower;
		action def StoreData {
			in data : RegionalOxygenSaturation;
		}
		action def PerformSelfTest {
			out passed : Boolean;
		}
		action def PerformMonitoring {
			out alarmTriggered : Boolean;
			action calculateRSO2 : CalculateRSO2;
			action storeData : StoreData;
			action updateDisplay : UpdateDisplay;
			action checkThresholds : CheckThresholds;
		}
		action def TriggerAlarms {
			action triggerAudibleAlarm : TriggerAudibleAlarm;
			action triggerVisualAlarm : TriggerVisualAlarm;
		}

		state def SystemStates {
			action performSelfTest : PerformSelfTest;
			action performMonitoring : PerformMonitoring;
			action triggerAlarms : TriggerAlarms;

			entry; then initialization;
			state initialization {
				entry performSelfTest;
			}
			accept InitializationComplete then standby;
			state standby;
			accept StartMonitoring then activeMonitoring;
			state activeMonitoring {
				do performMonitoring;
			}
			accept when performMonitoring.alarmTriggered == true then alarmState;
			state alarmState {
				do triggerAlarms;
			}
			accept when performMonitoring.alarmTriggered == false then activeMonitoring;
			accept StopMonitoring then standby;
		}
	}

	package Usages {
		private import Definitions::*;

		part oximeter : INVOSOximeter;

		state oximeterStates : SystemStates;
	}
}
