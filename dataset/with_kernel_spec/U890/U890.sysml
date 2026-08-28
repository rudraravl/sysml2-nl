package SSMI {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SequenceFunctions::*;
	
	item def MicrowaveRadiation;
	
	enum def Polarization {
		Horizontal;
		Vertical;
	}
	
	attribute def BrightnessTemperature :> TemperatureValue;
	
	attribute def CalibrationData {
		attribute warmTargetTemp : TemperatureValue;
		attribute coldTargetTemp : TemperatureValue;
	}
	
	attribute def PositionInfo {
		attribute latitude : AngleValue;
		attribute longitude : AngleValue;
	}
	
	attribute def SensorDataProduct {
		attribute timestamp : TimeValue;
		attribute qualityMetrics : Real;
		attribute brightnessTemps : BrightnessTemperature[*];
		attribute scanPositions : PositionInfo[*];
	}
	
	port def RadiationInPort {
		in radiation : MicrowaveRadiation;
	}
	port def RadiationOutPort {
		out radiation : MicrowaveRadiation;
	}
	port def VoltageOutPort {
		out voltage : ElectricPotentialValue;
	}
	port def VoltageInPort {
		in voltage : ElectricPotentialValue[*];
	}
	port def CalibrationDataOutPort {
		out calibrationData : CalibrationData;
	}
	port def CalibrationDataInPort {
		in calibrationData : CalibrationData;
	}
	port def BrightnessTempOutPort {
		out brightnessTemps : BrightnessTemperature[*];
	}
	port def BrightnessTempInPort {
		in brightnessTemps : BrightnessTemperature[*];
	}
	port def PositionOutPort {
		out position : PositionInfo;
	}
	port def PositionInPort {
		in position : PositionInfo;
	}
	port def DataProductOutPort {
		out dataProduct : SensorDataProduct;
	}
	
	part def AntennaSubsystem {
		port radiationIn : RadiationInPort;
		port radiationOut : RadiationOutPort;
	}
	
	part def ScanningMechanism {
		port positionOut : PositionOutPort;
		attribute swathWidth : LengthValue;
	}
	
	part def ReceiverChannel {
		attribute centerFrequency : FrequencyValue;
		attribute polarizationType : Polarization;
		port radiationIn : RadiationInPort;
		port voltageOut : VoltageOutPort;
	}
	
	part def RadiometerSubsystem {
		port voltageIn : VoltageInPort;
		port calibrationIn : CalibrationDataInPort;
		port brightnessTempOut : BrightnessTempOutPort;
	}
	
	part def CalibrationSubsystem {
		port calibrationOut : CalibrationDataOutPort;
	}
	
	part def SignalProcessor {
		port brightnessTempIn : BrightnessTempInPort;
		port positionIn : PositionInPort;
		port dataProductOut : DataProductOutPort;
	}
	
	action def CalibrateMeasurements {
		in voltages : ElectricPotentialValue[*];
		in calibrationData : CalibrationData;
		out brightnessTemps : BrightnessTemperature[*];
	}
	
	action def PackageData {
		in brightnessTemps : BrightnessTemperature[*];
		in scanPosition : PositionInfo;
		out dataProduct : SensorDataProduct;
	}
	
	action def ActiveSensingCycle {
		in voltages : ElectricPotentialValue[*];
		in calibrationData : CalibrationData;
		in scanPosition : PositionInfo;
		out dataProduct : SensorDataProduct;
		
		action calibrate : CalibrateMeasurements {
			in voltages;
			in calibrationData;
			out brightnessTemps;
		}
		flow calibrate.brightnessTemps to packageData.brightnessTemps;
		action packageData : PackageData {
			in brightnessTemps;
			in scanPosition;
			out dataProduct;
		}
	}
	
	state machine def OperatingStates {
		initial state powerOff;
		state initialization;
		state calibration;
		state standby;
		state activeSensing;
		state dataProcessing;
		
		transition from powerOff to initialization;
		transition from initialization to calibration;
		transition from calibration to standby;
		transition from standby to activeSensing;
		transition from activeSensing to dataProcessing;
		transition from dataProcessing to activeSensing;
	}
	
	part def SSMIInstrument {
		part antenna : AntennaSubsystem;
		part scanner : ScanningMechanism;
		part receivers : ReceiverChannel[7];
		part radiometer : RadiometerSubsystem;
		part calibrator : CalibrationSubsystem;
		part processor : SignalProcessor;
		
		interface antennaToReceivers connect antenna.radiationOut to receivers.radiationIn {
			flow radiationFlow of MicrowaveRadiation 
				from antenna.radiationOut.radiation to receivers.radiationIn.radiation;
		}
		
		interface receiversToRadiometer connect receivers.voltageOut to radiometer.voltageIn {
			flow voltageFlow of ElectricPotentialValue 
				from receivers.voltageOut.voltage to radiometer.voltageIn.voltage;
		}
		
		interface calibratorToRadiometer connect calibrator.calibrationOut to radiometer.calibrationIn {
			flow calibrationFlow of CalibrationData 
				from calibrator.calibrationOut.calibrationData to radiometer.calibrationIn.calibrationData;
		}
		
		interface radiometerToProcessor connect radiometer.brightnessTempOut to processor.brightnessTempIn {
			flow brightnessTempFlow of BrightnessTemperature[*] 
				from radiometer.brightnessTempOut.brightnessTemps to processor.brightnessTempIn.brightnessTemps;
		}
		
		interface scannerToProcessor connect scanner.positionOut to processor.positionIn {
			flow positionFlow of PositionInfo 
				from scanner.positionOut.position to processor.positionIn.position;
		}
		
		state machine operatingStates : OperatingStates;
	}
	
	part ssmiInstance : SSMIInstrument;
	
	requirement def SSMIRequirements {
		subject instrument : SSMIInstrument;
		
		constraint swathConstraint { instrument.scanner.swathWidth == 1400 [km] }
		constraint channelConstraint { instrument.receivers->size() == 7 }
	}
	
	requirement ssmiReq : SSMIRequirements {
		subject instrument = ssmiInstance;
	}
}
