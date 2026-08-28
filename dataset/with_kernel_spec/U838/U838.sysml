package PyranometerModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import Time::*;
	
	public import Definitions::*;
	
	package Definitions {
		value type ElectricalVoltage :> ScalarValues::Real;
		value type ConditionedVoltage :> ScalarValues::Real;
		value type DigitalValue :> ScalarValues::Real;
		value type IrradianceValue :> ScalarValues::Real;
		
		item def SolarRadiation;
		item def IrradianceMeasurement {
			attribute value : IrradianceValue;
			attribute timestamp : Time::DateTime;
		}
		
		attribute def CalibrationFactor;
		attribute def PowerOn;
		attribute def MaintenanceMode;
		attribute def MaintenanceComplete;
		attribute def Shutdown;
		
		port def SolarRadiationPort;
		port def VoltagePort;
		port def ConditionedVoltagePort;
		port def TemperaturePort;
		port def DigitalPort;
		port def MeasurementPort;
		port def PowerPort;
		
		action def PerformSelfTest;
		action def ContinuousMeasurement;
		action def GenerateVoltage;
		action def MeasureTemperature;
		action def AmplifyAndFilter;
		action def ConvertAndCalculate;
		action def StoreData;
		action def TransmitData;
		action def DistributePower;
		
		part def GlassDome {
			port radiationIn : SolarRadiationPort;
			port radiationOut : SolarRadiationPort;
		}
		part def ThermopileSensor {
			port radiationIn : SolarRadiationPort;
			port voltageOut : VoltagePort;
			port powerIn : PowerPort;
			perform action generateVoltage : GenerateVoltage;
		}
		part def TemperatureSensor {
			port tempOut : TemperaturePort;
			port powerIn : PowerPort;
			perform action measureTemperature : MeasureTemperature;
		}
		part def SignalConditioner {
			port voltageIn : VoltagePort;
			port voltageOut : ConditionedVoltagePort;
			port powerIn : PowerPort;
			perform action amplifyAndFilter : AmplifyAndFilter;
		}
		part def DataAcquisitionUnit {
			port voltageIn : ConditionedVoltagePort;
			port tempIn : TemperaturePort;
			port digitalOut : DigitalPort;
			port measurementOut : MeasurementPort;
			port powerIn : PowerPort;
			attribute calibrationFactor : CalibrationFactor;
			perform action convertAndCalculate : ConvertAndCalculate;
		}
		part def DataStorageModule {
			port measurementIn : MeasurementPort;
			port powerIn : PowerPort;
			perform action storeData : StoreData;
		}
		part def CommunicationInterface {
			port measurementIn : MeasurementPort;
			port dataOut : MeasurementPort;
			port powerIn : PowerPort;
			perform action transmitData : TransmitData;
		}
		part def PowerManagementUnit {
			port powerIn : PowerPort;
			port powerOut : PowerPort;
			perform action distributePower : DistributePower;
		}
		
		part def Pyranometer {
			part glassDome : GlassDome;
			part thermopileSensor : ThermopileSensor;
			part tempSensor : TemperatureSensor;
			part signalConditioner : SignalConditioner;
			part dataAcquisitionUnit : DataAcquisitionUnit;
			part dataStorage : DataStorageModule;
			part commInterface : CommunicationInterface;
			part powerManagement : PowerManagementUnit;
			
			port externalRadiationIn : SolarRadiationPort;
			port externalDataOut : MeasurementPort;
			port externalPowerIn : PowerPort;
			
			connect externalRadiationIn to glassDome.radiationIn;
			connect glassDome.radiationOut to thermopileSensor.radiationIn;
			connect thermopileSensor.voltageOut to signalConditioner.voltageIn;
			connect signalConditioner.voltageOut to dataAcquisitionUnit.voltageIn;
			connect tempSensor.tempOut to dataAcquisitionUnit.tempIn;
			connect dataAcquisitionUnit.measurementOut to dataStorage.measurementIn;
			connect dataAcquisitionUnit.measurementOut to commInterface.measurementIn;
			connect commInterface.dataOut to externalDataOut;
			connect externalPowerIn to powerManagement.powerIn;
			connect powerManagement.powerOut to thermopileSensor.powerIn;
			connect powerManagement.powerOut to signalConditioner.powerIn;
			connect powerManagement.powerOut to dataAcquisitionUnit.powerIn;
			connect powerManagement.powerOut to dataStorage.powerIn;
			connect powerManagement.powerOut to commInterface.powerIn;
			connect powerManagement.powerOut to tempSensor.powerIn;
			
			exhibit state pyranometerStates : PyranometerStates;
		}
		
		state def PyranometerStates {
			entry; then Off;
			state Off;
			accept PowerOn then PoweringOn;
			state PoweringOn {
				entry action performSelfTest;
				state SelfTest;
				transition 'SelfTest-WarmUp' first SelfTest then WarmUp;
				state WarmUp;
				transition 'WarmUp-LoadCalibration' first WarmUp then LoadCalibration;
				state LoadCalibration;
				transition 'LoadCalibration-Measuring' first LoadCalibration then Measuring;
			}
			state Measuring {
				do action continuousMeasurement;
			}
			accept MaintenanceMode then Maintenance;
			state Maintenance;
			accept MaintenanceComplete then Measuring;
			accept Shutdown then ShuttingDown;
			state ShuttingDown;
			transition 'ShuttingDown-Off' first ShuttingDown then Off;
		}
	}
}
