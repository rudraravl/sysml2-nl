package 'Smart Gas Meter System' {
	private import ScalarValues::*;

	package Definitions {
		attribute def VolumeFlowRateValue :> Real;
		attribute def PressureValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def EnergyValue :> Real;

		attribute def FlowDetected;
		attribute def FlowStopped;
		attribute def AlarmTriggered;
		attribute def MaintenanceRequested;
		attribute def MaintenanceComplete;
		attribute def ReturnToNormal;

		item def FlowData {
			attribute flowRate : VolumeFlowRateValue;
		}
		item def PressureData {
			attribute pressure : PressureValue;
		}
		item def TempData {
			attribute temperature : TemperatureValue;
		}
		item def CorrectedData {
			attribute currentFlowRate : VolumeFlowRateValue;
			attribute correctedVolume : VolumeValue;
			attribute totalVolume : VolumeValue;
			attribute totalEnergy : EnergyValue;
		}
		item def DiagnosticAlert {
			attribute alertType : String;
			attribute description : String;
		}
		item def ConfigCommand {
			attribute param : String;
			attribute val : String;
		}

		port def FlowPort { out flow : FlowData; }
		port def PressurePort { out pressure : PressureData; }
		port def TempPort { out temp : TempData; }
		port def DataPort { out data : CorrectedData; }
		port def ConfigPort { out config : ConfigCommand; }
		port def AlertPort { out alert : DiagnosticAlert; }

		part def FlowMeasurementUnit {
			port flowOut : FlowPort;
			attribute isFlowing : Boolean;
			perform action measureFlow : MeasureFlow;
		}
		part def PressureTransducer {
			port pressureOut : PressurePort;
			perform action measurePressure : MeasurePressure;
		}
		part def TemperatureSensor {
			port tempOut : TempPort;
			perform action measureTemp : MeasureTemp;
		}
		part def ComputationModule {
			port flowIn : ~FlowPort;
			port pressureIn : ~PressurePort;
			port tempIn : ~TempPort;
			port dataOut : DataPort;
			port configIn : ~ConfigPort;
			attribute standardPressure : PressureValue;
			attribute standardTemp : TemperatureValue;
			attribute gasCalorificValue : Real;
			perform action correctVolume : CorrectVolume;
			perform action accumulateVolume : AccumulateVolume;
			perform action calculateEnergy : CalculateEnergy;
		}
		part def DisplayUnit {
			port dataIn : ~DataPort;
			perform action updateDisplay : UpdateDisplay;
		}
		part def DataStorageModule {
			port dataIn : ~DataPort;
			perform action logData : LogData;
		}
		part def CommunicationInterface {
			port dataIn : ~DataPort;
			port configOut : ConfigPort;
			port alertIn : ~AlertPort;
			perform action transmitData : TransmitData;
			perform action receiveConfig : ReceiveConfig;
		}
		part def DiagnosticModule {
			port flowIn : ~FlowPort;
			port pressureIn : ~PressurePort;
			port tempIn : ~TempPort;
			port alarmOut : AlertPort;
			attribute maxPressure : PressureValue;
			attribute minPressure : PressureValue;
			attribute leakFlowThreshold : VolumeFlowRateValue;
			perform action analyzeSensors : AnalyzeSensors;
			perform action raiseAlarm : RaiseAlarm;
		}

		part def SmartGasMeter;
		state def SmartGasMeterStates;

		action def MeasureFlow { out flow : FlowData; }
		action def MeasurePressure { out pressure : PressureData; }
		action def MeasureTemp { out temp : TempData; }
		action def CorrectVolume { in flow : FlowData; in pressure : PressureData; in temp : TempData; out data : CorrectedData; }
		action def AccumulateVolume { in data : CorrectedData; }
		action def CalculateEnergy { in data : CorrectedData; }
		action def UpdateDisplay { in data : CorrectedData; }
		action def LogData { in data : CorrectedData; }
		action def TransmitData { in data : CorrectedData; }
		action def ReceiveConfig { out config : ConfigCommand; }
		action def AnalyzeSensors { in flow : FlowData; in pressure : PressureData; in temp : TempData; out alert : DiagnosticAlert; }
		action def RaiseAlarm { in alert : DiagnosticAlert; }

		requirement def MeasurementAccuracyReq {
			doc
			/* The meter shall accurately measure gas volume flow rate. */
			attribute maxError : Real;
		}
		requirement def PressureTempCorrectionReq {
			doc
			/* The meter shall correct measured volume to standard conditions. */
			attribute refPressure : PressureValue;
			attribute refTemp : TemperatureValue;
		}
		requirement def EnergyCalculationReq {
			doc
			/* The meter shall calculate total energy consumed based on gas properties. */
		}
		requirement def LeakDetectionReq {
			doc
			/* The meter shall detect abnormal flow patterns indicating a leak. */
		}
		requirement def RemoteCommReq {
			doc
			/* The meter shall transmit data remotely and receive configuration. */
		}
		requirement def DataLoggingReq {
			doc
			/* The meter shall log all readings to create a historical record. */
		}
	}

	package Usages {
		private import Definitions::*;

		part smartGasMeter : SmartGasMeter {
			attribute meterId : String;
			attribute firmwareVersion : String;

			part flowMeasurementUnit : FlowMeasurementUnit;
			part pressureTransducer : PressureTransducer;
			part temperatureSensor : TemperatureSensor;
			part computationModule : ComputationModule;
			part displayUnit : DisplayUnit;
			part dataStorageModule : DataStorageModule;
			part communicationInterface : CommunicationInterface;
			part diagnosticModule : DiagnosticModule;

			connect flowMeasurementUnit.flowOut to computationModule.flowIn;
			connect pressureTransducer.pressureOut to computationModule.pressureIn;
			connect temperatureSensor.tempOut to computationModule.tempIn;

			connect computationModule.dataOut to displayUnit.dataIn;
			connect computationModule.dataOut to dataStorageModule.dataIn;
			connect computationModule.dataOut to communicationInterface.dataIn;
			connect communicationInterface.configOut to computationModule.configIn;

			connect flowMeasurementUnit.flowOut to diagnosticModule.flowIn;
			connect pressureTransducer.pressureOut to diagnosticModule.pressureIn;
			connect temperatureSensor.tempOut to diagnosticModule.tempIn;
			connect diagnosticModule.alarmOut to communicationInterface.alertIn;

			state smartGasMeterStates : SmartGasMeterStates {
				entry; then standby;
				state standby {
					do flowMeasurementUnit.measureFlow;
				}
				accept FlowDetected then measuring;
				accept MaintenanceRequested then maintenance;
				state measuring {
					do flowMeasurementUnit.measureFlow;
					do pressureTransducer.measurePressure;
					do temperatureSensor.measureTemp;
					do computationModule.correctVolume;
					do computationModule.accumulateVolume;
					do computationModule.calculateEnergy;
					do displayUnit.updateDisplay;
					do dataStorageModule.logData;
					do communicationInterface.transmitData;
					do diagnosticModule.analyzeSensors;
				}
				accept AlarmTriggered then alarm;
				accept MaintenanceRequested then maintenance;
				accept FlowStopped then standby;
				state alarm {
					do diagnosticModule.raiseAlarm;
				}
				accept ReturnToNormal then measuring;
				accept MaintenanceRequested then maintenance;
				state maintenance;
				accept MaintenanceComplete then standby;
			}

			requirement accuracyReq : MeasurementAccuracyReq {
				attribute maxError = 0.01;
			}
			requirement correctionReq : PressureTempCorrectionReq {
				attribute refPressure = 101325.0;
				attribute refTemp = 288.15;
			}
			requirement energyReq : EnergyCalculationReq;
			requirement leakReq : LeakDetectionReq;
			requirement commReq : RemoteCommReq;
			requirement loggingReq : DataLoggingReq;
		}
	}
}
