package WaterSensingUnitModel {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def WaterLevelValue :> ScalarValues::Real;
		attribute def FlowRateValue :> ScalarValues::Real;
		attribute def TurbidityValue :> ScalarValues::Real;
		attribute def pHValue :> ScalarValues::Real;
		attribute def ConductivityValue :> ScalarValues::Real;
		attribute def VoltageValue :> ScalarValues::Real;
		attribute def CurrentValue :> ScalarValues::Real;
		attribute def BatteryCapacityValue :> ScalarValues::Real;

		item def QualityIndex {
			attribute turbidity : TurbidityValue;
			attribute pH : pHValue;
			attribute conductivity : ConductivityValue;
		}
		item def RawSensorData {
			attribute waterLevel : WaterLevelValue;
			attribute flowRate : FlowRateValue;
			attribute temperature : TemperatureValue;
			attribute quality : QualityIndex;
		}
		item def ProcessedData {
			attribute waterLevel : WaterLevelValue;
			attribute flowRate : FlowRateValue;
			attribute temperature : TemperatureValue;
			attribute quality : QualityIndex;
		}
		item def DataPackage {
			attribute payload : ProcessedData;
			attribute timestamp : String;
		}

		attribute def MeasurementTrigger;
		attribute def CalibrationCommand;
		attribute def CalibrationComplete;
		attribute def FaultDetected;
		attribute def ResetCommand;
		attribute def ReadingsComplete;
		attribute def ProcessingComplete;
		attribute def TransmissionComplete;

		port def RawDataOutPort {
			out data : RawSensorData;
		}
		port def RawDataInPort {
			in data : RawSensorData;
		}
		port def ProcessedDataOutPort {
			out data : ProcessedData;
		}
		port def ProcessedDataInPort {
			in data : ProcessedData;
		}
		port def PowerOutPort {
			out voltage : VoltageValue;
			out current : CurrentValue;
		}
		port def PowerInPort {
			in voltage : VoltageValue;
			in current : CurrentValue;
		}

		interface def RawDataFlow {
			end source : RawDataOutPort;
			end target : RawDataInPort;
		}
		interface def ProcessedDataFlow {
			end source : ProcessedDataOutPort;
			end target : ProcessedDataInPort;
		}
		interface def PowerFlow {
			end source : PowerOutPort;
			end target : PowerInPort;
		}

		action def TakeReadings {
			out raw : RawSensorData;
		}
		action def ProcessData {
			in raw : RawSensorData;
			out processed : ProcessedData;
		}
		action def TransmitData {
			in processed : ProcessedData;
			out packet : DataPackage;
		}
		action def Calibrate;

		part def WaterSensor {
			port dataOut : RawDataOutPort;
			port powerIn : PowerInPort;
			perform action takeReadings : TakeReadings;
		}
		part def SignalProcessor {
			port dataIn : RawDataInPort;
			port dataOut : ProcessedDataOutPort;
			port powerIn : PowerInPort;
			perform action processData : ProcessData;
		}
		part def DataTransmitter {
			port dataIn : ProcessedDataInPort;
			port powerIn : PowerInPort;
			perform action transmitData : TransmitData;
		}
		part def PowerSupply {
			port powerOut : PowerOutPort;
			attribute batteryCapacity : BatteryCapacityValue;
		}

		part def WaterSensingUnit {
			part waterSensor : WaterSensor;
			part signalProcessor : SignalProcessor;
			part dataTransmitter : DataTransmitter;
			part powerSupply : PowerSupply;

			interface sensorToProcessor : RawDataFlow connect waterSensor.dataOut to signalProcessor.dataIn;
			interface processorToTransmitter : ProcessedDataFlow connect signalProcessor.dataOut to dataTransmitter.dataIn;

			interface powerToSensor : PowerFlow connect powerSupply.powerOut to waterSensor.powerIn;
			interface powerToProcessor : PowerFlow connect powerSupply.powerOut to signalProcessor.powerIn;
			interface powerToTransmitter : PowerFlow connect powerSupply.powerOut to dataTransmitter.powerIn;

			exhibit state unitStates : WaterSensingUnitStates;
		}

		state def WaterSensingUnitStates;

		requirement def BatteryLifeRequirement {
			doc /* The Power Supply shall provide power for at least one year of continuous operation. */
			subject supply : PowerSupply;
			attribute minDurationMonths : Integer = 12;
		}

		requirement def LoRaWANTransmissionRequirement {
			doc /* The Data Transmitter shall transmit data using the LoRaWAN protocol. */
			subject transmitter : DataTransmitter;
		}

		requirement def WaterParametersRequirement {
			doc /* The Water Sensor shall measure water level, flow rate, temperature, turbidity, pH, and conductivity. */
			subject sensor : WaterSensor;
		}
	}

	package Usages {
		private import Definitions::*;

		part waterSensingUnit : WaterSensingUnit;

		action takeReadings : TakeReadings;
		action processData : ProcessData;
		action transmitData : TransmitData;
		action calibrate : Calibrate;

		state unitStates : WaterSensingUnitStates {
			entry; then idle;
			state idle;
			accept MeasurementTrigger then measuring;
			accept CalibrationCommand then calibration;
			accept FaultDetected then error;

			state measuring {
				do takeReadings;
			}
			accept ReadingsComplete then processing;

			state processing {
				do processData;
			}
			accept ProcessingComplete then transmitting;

			state transmitting {
				do transmitData;
			}
			accept TransmissionComplete then idle;

			state calibration {
				do calibrate;
			}
			accept CalibrationComplete then idle;

			state error;
			accept ResetCommand then idle;
		}

		requirement batteryLifeReq : BatteryLifeRequirement;
		requirement transmissionReq : LoRaWANTransmissionRequirement;
		requirement parametersReq : WaterParametersRequirement;
	}
}
