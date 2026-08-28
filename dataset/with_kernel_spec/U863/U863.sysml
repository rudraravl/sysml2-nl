package 'Scanning SQUID Microscope' {
	private import ISQ::*;
	private import SI::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		alias MagneticFluxValue for ISQ::MagneticFluxValue;
		alias TemperatureValue for ISQ::ThermodynamicTemperatureValue;
		alias VoltageValue for ISQ::ElectricPotentialDifferenceValue;
		alias LengthValue for ISQ::LengthValue;

		item def MagneticFieldImage;
		item def PositionXY {
			attribute x: LengthValue;
			attribute y: LengthValue;
		}

		port def CoolingPort {
			out temp: TemperatureValue;
		}
		port def VoltageOutPort {
			out voltage: VoltageValue;
		}
		port def FluxOutPort {
			out flux: MagneticFluxValue;
		}
		port def PositionOutPort {
			out position: PositionXY;
		}
		port def ImageOutPort {
			out image: MagneticFieldImage;
		}

		part def CryogenicDewar {
			attribute targetTemp: TemperatureValue;
			port coolingOut: CoolingPort;
		}
		part def SquidSensorHead {
			port coolingIn: ~CoolingPort;
			port voltageOut: VoltageOutPort;
		}
		part def PiezoelectricScanner {
			port positionOut: PositionOutPort;
		}
		part def SampleStage {
			port positionOut: PositionOutPort;
		}
		part def VibrationIsolationSystem;
		part def MagneticShieldingEnclosure;
		part def FeedbackElectronics {
			port voltageIn: ~VoltageOutPort;
			port fluxOut: FluxOutPort;
		}
		part def DataAcquisitionUnit {
			port fluxIn: ~FluxOutPort;
			port positionIn: ~PositionOutPort;
			port imageOut: ImageOutPort;
		}

		action def MeasureFlux {
			in position: PositionXY;
			out voltage: VoltageValue;
		}
		action def ProcessSignal {
			in voltage: VoltageValue;
			out flux: MagneticFluxValue;
		}
		action def RecordData {
			in flux: MagneticFluxValue;
			in position: PositionXY;
			out image: MagneticFieldImage;
		}
		action def ScanSample {
			out image: MagneticFieldImage;
			loop {
				action moveScanner {
					out position: PositionXY;
				}
				then action measureFlux : MeasureFlux {
					in position = moveScanner.position;
					out voltage: VoltageValue;
				}
				flow measureFlux.voltage to processSignal.voltage;
				then action processSignal : ProcessSignal {
					in voltage: VoltageValue;
					out flux: MagneticFluxValue;
				}
				flow processSignal.flux to recordData.flux;
				then action recordData : RecordData {
					in flux: MagneticFluxValue;
					in position = moveScanner.position;
					out image: MagneticFieldImage;
				}
			}
		}

		state def SsmOperation {
			entry; then Off;
			state Off;
			state Cooling;
			state Ready;
			state Scanning;
			transition off_to_cooling first Off then Cooling;
			transition cooling_to_ready first Cooling then Ready;
			transition ready_to_scanning first Ready then Scanning;
			transition scanning_to_ready first Scanning then Ready;
		}

		requirement def OperatingTempReq {
			doc /* The SQUID sensor must be maintained at an operating temperature of 4.2 Kelvin or lower. */
			attribute maxTemp: TemperatureValue = 4.2[K];
		}
		requirement def ShieldingReq {
			doc /* The magnetic shielding enclosure must attenuate external magnetic fields by at least 99.9%. */
		}
		requirement def VibrationDampingReq {
			doc /* The vibration isolation system must reduce ambient mechanical vibrations to below 10 nm RMS. */
		}

		part def ScanningSquidMicroscope {
			part cryogenicDewar : CryogenicDewar;
			part squidSensorHead : SquidSensorHead;
			part piezoelectricScanner : PiezoelectricScanner;
			part sampleStage : SampleStage;
			part vibrationIsolationSystem : VibrationIsolationSystem;
			part magneticShieldingEnclosure : MagneticShieldingEnclosure;
			part feedbackElectronics : FeedbackElectronics;
			part dataAcquisitionUnit : DataAcquisitionUnit;

			port imagePort : ImageOutPort;

			exhibit state ssmOperation : SsmOperation;

			perform action scanSample : ScanSample {
				out image = imagePort.image;
			}

			connection cryoToSensor connect cryogenicDewar.coolingOut to squidSensorHead.coolingIn;
			connection sensorToFeedback connect squidSensorHead.voltageOut to feedbackElectronics.voltageIn;
			connection feedbackToDau connect feedbackElectronics.fluxOut to dataAcquisitionUnit.fluxIn;
			connection scannerToDau connect piezoelectricScanner.positionOut to dataAcquisitionUnit.positionIn;
			connection dauToImage connect dataAcquisitionUnit.imageOut to imagePort;
		}
	}

	package Usages {
		private import Definitions::*;

		part ssmSystem : ScanningSquidMicroscope {
			part :>> cryogenicDewar {
				attribute :>> targetTemp = 4.2[K];
			}
		}

		requirement operatingTempUsage : OperatingTempReq;
		requirement shieldingUsage : ShieldingReq;
		requirement vibrationDampingUsage : VibrationDampingReq;

		satisfy operatingTempUsage by ssmSystem.cryogenicDewar;
		satisfy shieldingUsage by ssmSystem.magneticShieldingEnclosure;
		satisfy vibrationDampingUsage by ssmSystem.vibrationIsolationSystem;
	}
}
