package SmartGarmentHealthMonitoring {
	import ScalarValues::*;
	import SI::*;

	value type HeartRate :> Real { unit "beats/min"; }
	value type Temperature :> Real { unit "degC"; }
	value type Acceleration :> Real { unit "m/s^2"; }
	value type Impedance :> Real {> 'ohm'; }
	value type BatteryLevel :> Real { unit "%"; }
	value type Voltage :> Real { unit "V"; }
	value type DataRate :> Real { unit "bit/s"; }
	value type Frequency :> Real { unit "Hz"; }

	item def ECGSignal;
	item def TemperatureSignal;
	item def IMUData;
	item def ImpedanceSignal;
	item def ElectricalPower;
	item def HealthDataPacket {
		value heartRate : HeartRate;
		value skinTemp : Temperature;
		value accelX : Acceleration;
		value accelY : Acceleration;
		value accelZ : Acceleration;
		value hydration : Real;
		value batteryLevel : BatteryLevel;
		value timestamp : Integer;
	}
	item def EmergencyPacket {
		value lastHeartRate : HeartRate;
		value lastTemp : Temperature;
		value lastHydration : Real;
		value batteryLevel : BatteryLevel;
		value reason : String;
	}

	port def ECGOut { out ecg : ECGSignal; }
	port def TempOut { out tempSignal : TemperatureSignal; }
	port def IMUOut { out imuData : IMUData; }
	port def ImpedanceOut { out impSignal : ImpedanceSignal; }
	port def PowerOut { out power : ElectricalPower; }
	port def DataIn { in packet : HealthDataPacket; }
	port def DataOut { out packet : HealthDataPacket; }
	port def EmergencyOut { out emergency : EmergencyPacket; }

	part def FabricSubstrate {
		attribute flexible : Boolean = true;
		attribute stretchable : Boolean = true;
		attribute washable : Boolean = true;
		attribute thickness : Real = 0.5;
	}

	part def ConductiveFiber {
		attribute conductivity : Real;
		attribute resistance : Impedance;
	}

	part def ECGSensor {
		port ecgOut : ECGOut;
		attribute samplingRate : Frequency = 250;
		action acquireECG {
			out signal : ECGSignal;
		}
		action calculateHeartRate {
			in raw : ECGSignal;
			out hr : HeartRate;
		}
	}

	part def Thermistor {
		port tempOut : TempOut;
		attribute range : Temperature;
		action measureTemperature {
			out signal : TemperatureSignal;
		}
	}

	part def IMU {
		port imuOut : IMUOut;
		attribute accelX : Acceleration;
		attribute accelY : Acceleration;
		attribute accelZ : Acceleration;
		attribute samplingRate : Frequency = 100;
		action measureMotion {
			out data : IMUData;
		}
	}

	part def ImpedanceSensor {
		port impOut : ImpedanceOut;
		attribute excitationFreq : Frequency;
		action measureImpedance {
			out signal : ImpedanceSignal;
		}
	}

	part def FlexibleBattery {
		port powerOut : PowerOut;
		attribute level : BatteryLevel;
		attribute capacity : Voltage = 3.7;
		attribute chargeMah : Real;
		action discharge {
			out power : ElectricalPower;
		}
	}

	part def SignalProcessingUnit {
		in port ecgIn : ECGOut;
		in port tempIn : TempOut;
		in port imuIn : IMUOut;
		in port impIn : ImpedanceOut;
		in port powerIn : PowerOut;
		out port dataOut : DataOut;
		out port emergencyOut : EmergencyOut;

		attribute heartRate : HeartRate;
		attribute skinTemp : Temperature;
		attribute accelX : Acceleration;
		attribute accelY : Acceleration;
		attribute accelZ : Acceleration;
		attribute hydration : Real;
		attribute batteryLevel : BatteryLevel;
		attribute lowBatteryThreshold : BatteryLevel = 20;
		attribute criticalBatteryThreshold : BatteryLevel = 5;

		action deriveHeartRate {
			in ecg : ECGSignal;
			out hr : HeartRate;
		}
		action deriveHydration {
			in imp : ImpedanceSignal;
			out hyd : Real;
		}
		action assemblePacket {
			in hr : HeartRate;
			in temp : Temperature;
			in ax : Acceleration;
			in ay : Acceleration;
			in az : Acceleration;
			in hyd : Real;
			in batt : BatteryLevel;
			out packet : HealthDataPacket;
		}
		action processSignals {
			in ecg : ECGSignal;
			in temp : TemperatureSignal;
			in imu : IMUData;
			in imp : ImpedanceSignal;
			in pwr : ElectricalPower;
			out packet : HealthDataPacket;
		}

		state def HealthMonitoringStateMachine {
			entry action selfTestAndCalibrate;
			state Initializing {
				entry action runSelfTest;
				entry action calibrateSensors;
			}
			state Monitoring {
				entry action startCollection;
				do action collectAndTransmit;
			}
			state ReducedMonitoring {
				entry action reduceSamplingRate;
				do action collectAndTransmit;
			}
			state EmergencyShutdown {
				entry action transmitEmergencyPacket;
				entry action saveCurrentReadings;
			}
			state Off;
			transition Initializing -> Monitoring when selfTestComplete;
			transition Monitoring -> ReducedMonitoring when batteryLevel <= lowBatteryThreshold;
			transition Monitoring -> EmergencyShutdown when batteryLevel <= criticalBatteryThreshold;
			transition ReducedMonitoring -> EmergencyShutdown when batteryLevel <= criticalBatteryThreshold;
			transition ReducedMonitoring -> Monitoring when batteryLevel > lowBatteryThreshold;
			transition EmergencyShutdown -> Off when shutdownComplete;
		}
	}

	part def BluetoothTransceiver {
		in port dataIn : DataOut;
		out port wirelessOut : DataOut;
		attribute dataRate : DataRate;
		attribute protocol : String = "BLE";
		action transmit {
			in packet : HealthDataPacket;
		}
	}

	part def ExternalDevice {
		in port receiver : DataIn;
		attribute deviceType : String;
		action receiveData {
			in packet : HealthDataPacket;
		}
		action analyzeHealthData {
			in packet : HealthDataPacket;
		}
	}

	part def SmartGarment {
		part fabric : FabricSubstrate;
		part fibers : ConductiveFiber[4..*];
		part ecgSensor : ECGSensor;
		part thermistor : Thermistor;
		part imu : IMU;
		part impedanceSensor : ImpedanceSensor;
		part battery : FlexibleBattery;
		part processor : SignalProcessingUnit;
		part bluetooth : BluetoothTransceiver;

		connection ecgConn connect ecgSensor.ecgOut to processor.ecgIn;
		connection tempConn connect thermistor.tempOut to processor.tempIn;
		connection imuConn connect imu.imuOut to processor.imuIn;
		connection impConn connect impedanceSensor.impOut to processor.impIn;
		connection powerConn connect battery.powerOut to processor.powerIn;
		connection dataConn connect processor.dataOut to bluetooth.dataIn;
	}

	part def SmartGarmentSystem {
		part garment : SmartGarment;
		part externalDevice : ExternalDevice;

		connection wirelessConn connect garment.bluetooth.wirelessOut to externalDevice.receiver;
	}

	requirement def HealthMonitoringRequirement {
		doc "Requirements for the smart garment health monitoring system.";
		subject system : SmartGarmentSystem;

		requirement shallMonitorVitalSigns {
			doc "The system shall continuously monitor ECG, skin temperature, body motion, and hydration.";
		}
		requirement shallCalculateHeartRate {
			doc "The system shall calculate heart rate in beats per minute from ECG signals.";
		}
		requirement shallTransmitWirelessly {
			doc "The system shall transmit health data packets via Bluetooth to an external device.";
		}
		requirement shallIncludeBatteryLevel {
			doc "Each health data packet shall include the current battery level.";
		}
		requirement shallSelfTestOnStartup {
			doc "The system shall run a self-test and calibrate sensors on startup.";
		}
		requirement shallConservePower {
			doc "The system shall enter reduced monitoring mode when battery level is low.";
		}
		requirement shallEmergencyShutdown {
			doc "The system shall transmit a final emergency packet and save current readings before safe shutdown when battery is critically low.";
		}
		requirement shallBeWashable {
			doc "The garment substrate shall be flexible, stretchable, and washable.";
		}
	}

	requirement def PowerRequirement {
		subject battery : FlexibleBattery;
		requirement shallProvideLongTermPower {
			doc "The flexible battery shall provide power for continuous long-term wear.";
		}
	}

	requirement def FabricRequirement {
		subject fabric : FabricSubstrate;
		requirement shallEmbedConductiveFibers {
			doc "The fabric shall embed conductive fibers acting as wiring between components.";
		}
	}
}
