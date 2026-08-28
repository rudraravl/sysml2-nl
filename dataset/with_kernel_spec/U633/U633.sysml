package CooledCCDImagingSystem {
	private import ScalarValues::Integer;
	private import ScalarValues::Real;
	private import ISQ::ThermodynamicTemperatureValue;
	private import SI::K;

	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def Photon;
		item def Charge {
			attribute electrons : Integer;
		}
		item def AnalogVoltage {
			attribute level : Real;
		}
		item def DigitalPixelValue {
			attribute code : Integer;
		}
		item def ClockSignal;
		item def ThermalSignal {
			attribute temperature : ThermodynamicTemperatureValue;
		}

		port def LightPort {
			out item photons : Photon;
		}
		port def ChargePort {
			out item charge : Charge;
		}
		port def VoltagePort {
			out item voltage : AnalogVoltage;
		}
		port def DigitalPort {
			out item pixel : DigitalPixelValue;
		}
		port def ClockPort {
			out item clock : ClockSignal;
		}
		port def ThermalPort {
			out item thermal : ThermalSignal;
		}

		part def CCDSensor {
			attribute pixelRows : Integer = 2048;
			attribute pixelCols : Integer = 2048;
			attribute quantumEfficiency : Real = 0.90;
			attribute operatingTemp : ThermodynamicTemperatureValue = 233.15 [K];
			port lightIn : ~LightPort;
			port chargeOut : ChargePort;
			port clockIn : ~ClockPort;
			port thermalIn : ~ThermalPort;
		}
		part def VerticalRegister {
			port chargeIn : ~ChargePort;
			port chargeOut : ChargePort;
			port clockIn : ~ClockPort;
		}
		part def HorizontalRegister {
			port chargeIn : ~ChargePort;
			port chargeOut : ChargePort;
			port clockIn : ~ClockPort;
		}
		part def LowNoiseAmplifier {
			attribute gain : Real;
			port chargeIn : ~ChargePort;
			port voltageOut : VoltagePort;
			port clockIn : ~ClockPort;
		}
		part def ADC {
			attribute resolution : Integer = 16;
			port voltageIn : ~VoltagePort;
			port digitalOut : DigitalPort;
			port clockIn : ~ClockPort;
		}
		part def CoolingSystem {
			attribute targetTemp : ThermodynamicTemperatureValue = 233.15 [K];
			port thermalOut : ThermalPort;
		}
		part def TimingGenerator {
			port clockOut : ClockPort;
		}

		action def IntegrateLight {
			in photons : Photon;
			out charge : Charge;
		}
		action def ShiftVertical {
			in chargeIn : Charge;
			out chargeOut : Charge;
		}
		action def ShiftHorizontal {
			in chargeIn : Charge;
			out chargeOut : Charge;
		}
		action def AmplifyCharge {
			in charge : Charge;
			out voltage : AnalogVoltage;
		}
		action def DigitizeSignal {
			in voltage : AnalogVoltage;
			out pixel : DigitalPixelValue;
		}
		action def ImagingCycle {
			in photons : Photon;
			out pixel : DigitalPixelValue;
		}

		state def ImagingCycleStates {
			state integrating;
			then state shiftingVertical;
			then state shiftingHorizontal;
			then state amplifying;
			then state digitizing;
			then integrating;
		}

		requirement def HighSensitivity {
			doc /* The sensor shall achieve a quantum efficiency of at least 90 percent. */
			attribute minQE : Real = 0.90;
		}
		requirement def LowNoise {
			doc /* The cooling system shall maintain the sensor at 233.15 K to minimize dark current. */
			attribute targetTemp : ThermodynamicTemperatureValue = 233.15 [K];
		}
		requirement def HighFidelity {
			doc /* The analog-to-digital converter shall provide 16-bit resolution. */
			attribute bits : Integer = 16;
		}
		requirement def HighResolution {
			doc /* The sensor shall have 2048 by 2048 pixels. */
			attribute rows : Integer = 2048;
			attribute cols : Integer = 2048;
		}
	}

	package Usages {
		part imagingSystem {
			port lightIn : ~LightPort;
			port digitalOut : DigitalPort;

			part sensor : CCDSensor;
			part verticalReg : VerticalRegister;
			part horizontalReg : HorizontalRegister;
			part amplifier : LowNoiseAmplifier;
			part adc : ADC;
			part cooler : CoolingSystem;
			part timer : TimingGenerator;

			flow of photons : Photon from lightIn.photons to sensor.lightIn.photons;
			flow of charge : Charge from sensor.chargeOut.charge to verticalReg.chargeIn.charge;
			flow of charge : Charge from verticalReg.chargeOut.charge to horizontalReg.chargeIn.charge;
			flow of charge : Charge from horizontalReg.chargeOut.charge to amplifier.chargeIn.charge;
			flow of voltage : AnalogVoltage from amplifier.voltageOut.voltage to adc.voltageIn.voltage;
			flow of pixel : DigitalPixelValue from adc.digitalOut.pixel to digitalOut.pixel;

			flow of clock : ClockSignal from timer.clockOut.clock to sensor.clockIn.clock;
			flow of clock : ClockSignal from timer.clockOut.clock to verticalReg.clockIn.clock;
			flow of clock : ClockSignal from timer.clockOut.clock to horizontalReg.clockIn.clock;
			flow of clock : ClockSignal from timer.clockOut.clock to amplifier.clockIn.clock;
			flow of clock : ClockSignal from timer.clockOut.clock to adc.clockIn.clock;

			flow of thermal : ThermalSignal from cooler.thermalOut.thermal to sensor.thermalIn.thermal;

			perform action cycle : ImagingCycle {
				in photons = lightIn.photons;
				out pixel = digitalOut.pixel;

				action integrate : IntegrateLight {
					in photons = cycle::photons;
					out charge : Charge;
				}
				flow integrate.charge to vShift.chargeIn;

				action vShift : ShiftVertical {
					in chargeIn : Charge;
					out chargeOut : Charge;
				}
				flow vShift.chargeOut to hShift.chargeIn;

				action hShift : ShiftHorizontal {
					in chargeIn : Charge;
					out chargeOut : Charge;
				}
				flow hShift.chargeOut to amplify.charge;

				action amplify : AmplifyCharge {
					in charge : Charge;
					out voltage : AnalogVoltage;
				}
				flow amplify.voltage to digitize.voltage;

				action digitize : DigitizeSignal {
					in voltage : AnalogVoltage;
					out pixel : DigitalPixelValue;
				}
			}

			state imagingStates : ImagingCycleStates;

			requirement highSensitivityReq : HighSensitivity;
			requirement lowNoiseReq : LowNoise;
			requirement highFidelityReq : HighFidelity;
			requirement highResolutionReq : HighResolution;

			satisfy highSensitivityReq by sensor;
			satisfy lowNoiseReq by cooler;
			satisfy highFidelityReq by adc;
			satisfy highResolutionReq by sensor;
		}
	}
}
