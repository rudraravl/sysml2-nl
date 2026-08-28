package 'Scintillometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQSpaceTime::*;
	private import ISQThermodynamics::*;

	package Definitions {
		attribute def IntensityValue :> Real;
		attribute def Cn2Value :> Real;
		attribute def SensibleHeatFluxValue :> Real;
		attribute def HumidityValue :> Real;

		item def OpticalBeam {
			attribute intensity : IntensityValue;
			attribute pathLength : LengthValue;
		}
		item def IntensityFluctuation;
		item def AtmosphericData {
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
			attribute humidity : HumidityValue;
		}
		item def MeasurementData {
			attribute cn2 : Cn2Value;
			attribute heatFlux : SensibleHeatFluxValue;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def CalibrateCommand;
		attribute def CalibrationComplete;

		port def OpticalPort {
			out beam : OpticalBeam;
		}
		port def FluctuationPort {
			out fluctuation : IntensityFluctuation;
		}
		port def AtmosphericDataPort {
			out atmData : AtmosphericData;
		}
		port def MeasurementPort {
			out measurement : MeasurementData;
		}

		action def EmitBeam { out beam : OpticalBeam; }
		action def ReceiveBeam { in beam : OpticalBeam; out fluctuation : IntensityFluctuation; }
		action def AnalyzeScintillation { in fluctuation : IntensityFluctuation; out cn2 : Cn2Value; }
		action def DeriveHeatFlux { in cn2 : Cn2Value; in atmData : AtmosphericData; out heatFlux : SensibleHeatFluxValue; }
		action def SenseAtmosphere { out atmData : AtmosphericData; }
		action def LogData { in data : MeasurementData; }
		action def PerformCalibration;
		action def MeasureTurbulence;

		state def SystemStates;

		part def LaserSource {
			perform action emit : EmitBeam;
		}

		part def TransmitterOptics;

		part def Transmitter {
			part laser : LaserSource;
			part optics : TransmitterOptics;
			port opticalOut : OpticalPort;
		}

		part def Detector {
			port opticalIn : ~OpticalPort;
			perform action receive : ReceiveBeam;
		}

		part def ReceiverOptics;

		part def Receiver {
			part optics : ReceiverOptics;
			part detector : Detector;
			port opticalIn : ~OpticalPort;
			port fluctuationOut : FluctuationPort;
		}

		part def AtmosphericSensor {
			port atmOut : AtmosphericDataPort;
			perform action sense : SenseAtmosphere;
		}

		part def SignalProcessor {
			port fluctuationIn : ~FluctuationPort;
			port atmIn : ~AtmosphericDataPort;
			port measurementOut : MeasurementPort;
			perform action analyze : AnalyzeScintillation;
			perform action derive : DeriveHeatFlux;
		}

		part def DataAcquisitionUnit {
			port measurementIn : ~MeasurementPort;
			port dataOut : MeasurementPort;
			perform action log : LogData;
		}

		part def Scintillometer {
			part transmitter : Transmitter;
			part receiver : Receiver;
			part processor : SignalProcessor;
			part atmSensor : AtmosphericSensor;
			part dau : DataAcquisitionUnit;

			connect transmitter.opticalOut to receiver.opticalIn;
			connect receiver.fluctuationOut to processor.fluctuationIn;
			connect atmSensor.atmOut to processor.atmIn;
			connect processor.measurementOut to dau.measurementIn;

			perform action 'measure turbulence' : MeasureTurbulence;
			exhibit state systemStates : SystemStates;
		}

		requirement def 'Path Length Requirement' {
			doc
			/*
			 * The optical beam shall traverse an open-air path ranging from 50 meters to 5 kilometers.
			 */
			subject scint : Scintillometer;
			attribute pathLength : LengthValue;
			constraint { pathLength >= 50 [m] && pathLength <= 5000 [m] }
		}

		requirement def 'Environmental Robustness' {
			doc
			/*
			 * The system shall operate reliably from -40 to +60 degrees Celsius
			 * for continuous long-term field deployment.
			 */
			subject scint : Scintillometer;
			attribute minOperatingTemp : TemperatureValue;
			attribute maxOperatingTemp : TemperatureValue;
			constraint { minOperatingTemp <= 233.15 [K] && maxOperatingTemp >= 333.15 [K] }
		}

		requirement def 'Measurement Capability' {
			doc
			/*
			 * The system shall continuously analyze intensity fluctuations to calculate
			 * the Refractive Index Structure Parameter (Cn2) and derive sensible heat flux
			 * using integrated atmospheric sensor data.
			 */
			subject scint : Scintillometer;
		}

		requirement def 'Data Logging' {
			doc
			/*
			 * Calculated measurements shall be logged by the data acquisition unit
			 * and made available through the external output interface.
			 */
			subject scint : Scintillometer;
		}
	}

	package Usages {
		private import Definitions::*;

		action 'measure turbulence' : MeasureTurbulence;
		action 'perform calibration' : PerformCalibration;

		requirement 'path length req' : 'Path Length Requirement';
		requirement 'environmental req' : 'Environmental Robustness';
		requirement 'measurement req' : 'Measurement Capability';
		requirement 'data logging req' : 'Data Logging';

		part scintillometer : Scintillometer;

		state 'system states' : SystemStates {
			entry; then idle;
			state idle;
			accept StartCommand
				then activeMeasuring;
			accept CalibrateCommand
				then calibrating;
			state calibrating {
				do 'perform calibration';
			}
			accept CalibrationComplete
				then idle;
			state activeMeasuring {
				do 'measure turbulence';
			}
			accept StopCommand
				then idle;
			accept CalibrateCommand
				then calibrating;
		}
	}
}
