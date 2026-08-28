package 'Optical Linear Encoder' {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		attribute def Length :> ISQ::LengthValue;
		attribute def Velocity :> ISQ::SpeedValue;
		attribute def Time :> ISQ::TimeValue;
		attribute def Voltage :> ISQ::ElectricPotentialValue;

		attribute def PowerOnSignal;
		attribute def SelfTestCompleteSignal;
		attribute def CalibrationCompleteSignal;
		attribute def StartMeasurementCmd;
		attribute def StopMeasurementCmd;
		attribute def ResetCmd;
		attribute def ErrorEvent;
		attribute def RecoverCmd;

		attribute def RawAnalogSignal {
			attribute amplitude : Voltage;
			attribute phase : Real;
		}

		attribute def PositionData {
			attribute position : Length;
			attribute timestamp : Time;
		}

		attribute def MeasurementResult {
			attribute position : Length;
			attribute velocity : Velocity;
			attribute timestamp : Time;
		}

		port def RawSignalPort {
			out rawSignal : RawAnalogSignal;
		}

		port def DigitalDataPort {
			out positionData : PositionData;
		}

		port def MeasurementOutputPort {
			out result : MeasurementResult;
		}

		port def CommandPort {
			in startCmd : StartMeasurementCmd;
			in stopCmd : StopMeasurementCmd;
			in resetCmd : ResetCmd;
		}

		action def 'Run Self Test' {
			out success : Boolean;
		}

		action def 'Run Calibration' {
			out calibrated : Boolean;
		}

		action def 'Acquire Optical Signal' {
			out rawSignal : RawAnalogSignal;
		}

		action def 'Interpolate Signal' {
			in rawSignal : RawAnalogSignal;
			out positionData : PositionData;
		}

		action def 'Calculate Velocity' {
			in currentPosition : PositionData;
			out result : MeasurementResult;
		}

		action def 'Transmit Result' {
			in result : MeasurementResult;
		}

		action def 'Diagnose Error' {
			out recovered : Boolean;
		}

		action def 'Measurement Cycle' {
			loop {
				action 'acquire optical signal': 'Acquire Optical Signal' {
					out rawSignal;
				}
				flow 'acquire optical signal'.rawSignal to 'interpolate signal'.rawSignal;
				action 'interpolate signal': 'Interpolate Signal' {
					in rawSignal;
					out positionData;
				}
				flow 'interpolate signal'.positionData to 'calculate velocity'.currentPosition;
				action 'calculate velocity': 'Calculate Velocity' {
					in currentPosition;
					out result;
				}
				flow 'calculate velocity'.result to 'transmit result'.result;
				action 'transmit result': 'Transmit Result' {
					in result;
				}
			}
		}

		part def GraduatedScale {
			attribute markingPitch : Length = 20e-6;
			attribute length : Length = 1.0;
		}

		part def LED {
			attribute wavelength : Length = 850e-9;
		}

		part def Photodetector {
			attribute sensitivity : Voltage = 1.0;
		}

		part def ReadHead {
			part led : LED;
			part photodetectors : Photodetector[2..4];
			port rawOut : RawSignalPort;
		}

		part def SignalProcessor {
			attribute resolution : Length = 0.5e-6;
			attribute interpolationFactor : Integer = 40;
			port rawIn : ~RawSignalPort;
			port digitalOut : DigitalDataPort;
		}

		part def Controller {
			attribute previousPosition : PositionData;
			port digitalIn : ~DigitalDataPort;
			port measurementOut : MeasurementOutputPort;
			port cmdIn : CommandPort;
		}

		part def MountingAssembly {
			attribute material : String = "Aluminum";
			attribute thermalExpansionCoeff : Real = 23.1e-6;
		}

		part def OpticalLinearEncoder {
			part graduatedScale : GraduatedScale;
			part readHead : ReadHead;
			part signalProcessor : SignalProcessor;
			part controller : Controller;
			part mountingAssembly : MountingAssembly;
			port externalCmd : CommandPort;
			port externalOutput : MeasurementOutputPort;

			connection readHeadToProcessor connect readHead.rawOut to signalProcessor.rawIn;
			connection processorToController connect signalProcessor.digitalOut to controller.digitalIn;
			connection controllerOutput connect controller.measurementOut to externalOutput;
			connection externalCommands connect externalCmd to controller.cmdIn;

			exhibit state 'encoder states': 'Encoder States';
		}

		state def 'Encoder States' {
			entry; then poweredOff;
			state poweredOff;
			accept PowerOnSignal
				then selfTest;
			state selfTest {
				entry action 'run self test': 'Run Self Test' { out success; }
			}
			accept SelfTestCompleteSignal
				then calibrating;
			accept ErrorEvent
				then error;
			state calibrating {
				entry action 'run calibration': 'Run Calibration' { out calibrated; }
			}
			accept CalibrationCompleteSignal
				then ready;
			accept ErrorEvent
				then error;
			state ready;
			accept StartMeasurementCmd
				then measuring;
			state measuring {
				do action 'measurement cycle': 'Measurement Cycle';
			}
			accept StopMeasurementCmd
				then stopped;
			accept ErrorEvent
				then error;
			state stopped;
			accept StartMeasurementCmd
				then measuring;
			accept ResetCmd
				then poweredOff;
			state error {
				entry action 'diagnose error': 'Diagnose Error' { out recovered; }
			}
			accept RecoverCmd
				then ready;
			accept ResetCmd
				then poweredOff;
		}

		requirement def 'Resolution Requirement' {
			doc /* The encoder shall achieve a measurement resolution of 0.5 micrometers. */
			attribute requiredResolution : Length = 0.5e-6;
		}

		requirement def 'Accuracy Requirement' {
			doc /* The encoder shall maintain positional accuracy within 1 micrometer over its full length. */
			attribute maxError : Length = 1.0e-6;
		}

		requirement def 'Operational Lifecycle Requirement' {
			doc /* The encoder shall perform self-test and calibration upon power-on before entering ready state. */
		}

		requirement def 'Error Recovery Requirement' {
			doc /* The encoder shall enter an error state upon detecting a fault and attempt automatic recovery. */
		}
	}

	public import Definitions::*;

	package Usages {
		private import Definitions::*;

		part 'optical linear encoder' : OpticalLinearEncoder {
			requirement 'resolution req' : 'Resolution Requirement';
			requirement 'accuracy req' : 'Accuracy Requirement';
			requirement 'lifecycle req' : 'Operational Lifecycle Requirement';
			requirement 'error recovery req' : 'Error Recovery Requirement';
		}
	}
}
