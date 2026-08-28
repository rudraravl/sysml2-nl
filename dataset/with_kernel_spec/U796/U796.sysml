package 'Optode Dissolved Oxygen Sensor' {
	public import Definitions::*;
	public import Usages::*;
	public import Requirements::*;

	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;

		alias Temperature for ISQ::ThermodynamicTemperatureValue;
		alias Pressure for ISQ::PressureValue;
		alias Time for ISQ::TimeValue;
		alias LuminousIntensity for ISQ::LuminousIntensityValue;

		attribute def DOConcentration :> Real;
		attribute def PowerVoltage :> Real;

		item def Light;
		item def BlueLight :> Light;
		item def FluorescentLight :> Light;

		attribute def FluorescentSignal {
			attribute intensity : LuminousIntensity;
			attribute decayTime : Time;
		}
		attribute def Timestamp;
		attribute def DOReading {
			attribute concentration : DOConcentration;
			attribute temperature : Temperature;
			attribute pressure : Pressure;
			attribute timestamp : Timestamp;
		}
		attribute def StartCmd;
		attribute def StopCmd;

		action def 'Emit Blue Light' {
			out bluePulse : BlueLight;
		}
		action def 'Deliver Light to Tip' {
			in bluePulse : BlueLight;
			out deliveredLight : BlueLight;
		}
		action def 'Excite and Quench Dye' {
			in deliveredLight : BlueLight;
			out emittedFluorescence : FluorescentLight;
		}
		action def 'Collect Emission' {
			in emittedFluorescence : FluorescentLight;
			out collectedFluorescence : FluorescentLight;
		}
		action def 'Detect Fluorescence' {
			in collectedFluorescence : FluorescentLight;
			out fluorescentSignal : FluorescentSignal;
		}
		action def 'Measure Temperature' {
			out temperature : Temperature;
		}
		action def 'Measure Pressure' {
			out pressure : Pressure;
		}
		action def 'Calculate DO Concentration' {
			in fluorescentSignal : FluorescentSignal;
			in temperature : Temperature;
			in pressure : Pressure;
			out concentration : DOConcentration;
		}
		action def 'Format Data' {
			in concentration : DOConcentration;
			in temperature : Temperature;
			in pressure : Pressure;
			out doReading : DOReading;
		}
		action def 'Transmit Data' {
			in doReading : DOReading;
		}
		action def 'Measurement Cycle' {
			out doReading : DOReading;
		}

		part def PowerSupply {
			port powerOut {
				out voltage : PowerVoltage;
			}
		}
		part def LEDSource {
			port powerIn {
				in voltage : PowerVoltage;
			}
			port lightOut {
				out bluePulse : BlueLight;
			}
		}
		part def DeliveryFiber {
			port lightIn {
				in bluePulse : BlueLight;
			}
			port lightOut {
				out deliveredLight : BlueLight;
			}
		}
		part def SensorTip {
			port lightIn {
				in deliveredLight : BlueLight;
			}
			port lightOut {
				out emittedFluorescence : FluorescentLight;
			}
		}
		part def CollectionFiber {
			port lightIn {
				in emittedFluorescence : FluorescentLight;
			}
			port lightOut {
				out collectedFluorescence : FluorescentLight;
			}
		}
		part def Photodetector {
			port powerIn {
				in voltage : PowerVoltage;
			}
			port lightIn {
				in collectedFluorescence : FluorescentLight;
			}
			port signalOut {
				out fluorescentSignal : FluorescentSignal;
			}
		}
		part def TemperatureSensor {
			port powerIn {
				in voltage : PowerVoltage;
			}
			port readingOut {
				out temperature : Temperature;
			}
		}
		part def PressureSensor {
			port powerIn {
				in voltage : PowerVoltage;
			}
			port readingOut {
				out pressure : Pressure;
			}
		}
		part def SignalProcessor {
			port powerIn {
				in voltage : PowerVoltage;
			}
			port signalIn {
				in fluorescentSignal : FluorescentSignal;
			}
			port tempIn {
				in temperature : Temperature;
			}
			port pressureIn {
				in pressure : Pressure;
			}
			port concentrationOut {
				out concentration : DOConcentration;
			}
		}
		part def DataInterface {
			port powerIn {
				in voltage : PowerVoltage;
			}
			port concentrationIn {
				in concentration : DOConcentration;
			}
			port tempIn {
				in temperature : Temperature;
			}
			port pressureIn {
				in pressure : Pressure;
			}
			port dataOut {
				out doReading : DOReading;
			}
		}
		part def Optode {
			port commandIn {
				in startCmd : StartCmd;
				in stopCmd : StopCmd;
			}
			port dataOut {
				out doReading : DOReading;
			}
		}
		part def ExternalMonitor {
			port dataIn {
				in doReading : DOReading;
			}
		}
	}

	package Usages {
		part optode : Optode {
			part powerSupply : PowerSupply;
			part ledSource : LEDSource;
			part deliveryFiber : DeliveryFiber;
			part sensorTip : SensorTip;
			part collectionFiber : CollectionFiber;
			part photodetector : Photodetector;
			part temperatureSensor : TemperatureSensor;
			part pressureSensor : PressureSensor;
			part signalProcessor : SignalProcessor;
			part dataInterface : DataInterface;

			flow powerFlow1 of PowerVoltage
				from powerSupply.powerOut.voltage to ledSource.powerIn.voltage;
			flow powerFlow2 of PowerVoltage
				from powerSupply.powerOut.voltage to photodetector.powerIn.voltage;
			flow powerFlow3 of PowerVoltage
				from powerSupply.powerOut.voltage to temperatureSensor.powerIn.voltage;
			flow powerFlow4 of PowerVoltage
				from powerSupply.powerOut.voltage to pressureSensor.powerIn.voltage;
			flow powerFlow5 of PowerVoltage
				from powerSupply.powerOut.voltage to signalProcessor.powerIn.voltage;
			flow powerFlow6 of PowerVoltage
				from powerSupply.powerOut.voltage to dataInterface.powerIn.voltage;

			flow blueLightFlow of BlueLight
				from ledSource.lightOut.bluePulse to deliveryFiber.lightIn.bluePulse;
			flow deliveredLightFlow of BlueLight
				from deliveryFiber.lightOut.deliveredLight to sensorTip.lightIn.deliveredLight;
			flow emittedFluorescenceFlow of FluorescentLight
				from sensorTip.lightOut.emittedFluorescence to collectionFiber.lightIn.emittedFluorescence;
			flow collectedFluorescenceFlow of FluorescentLight
				from collectionFiber.lightOut.collectedFluorescence to photodetector.lightIn.collectedFluorescence;

			flow signalFlow of FluorescentSignal
				from photodetector.signalOut.fluorescentSignal to signalProcessor.signalIn.fluorescentSignal;
			flow tempFlow1 of Temperature
				from temperatureSensor.readingOut.temperature to signalProcessor.tempIn.temperature;
			flow pressureFlow1 of Pressure
				from pressureSensor.readingOut.pressure to signalProcessor.pressureIn.pressure;

			flow concentrationFlow of DOConcentration
				from signalProcessor.concentrationOut.concentration to dataInterface.concentrationIn.concentration;
			flow tempFlow2 of Temperature
				from temperatureSensor.readingOut.temperature to dataInterface.tempIn.temperature;
			flow pressureFlow2 of Pressure
				from pressureSensor.readingOut.pressure to dataInterface.pressureIn.pressure;

			flow outputFlow of DOReading
				from dataInterface.dataOut.doReading to optode.dataOut.doReading;
		}

		part monitor : ExternalMonitor;

		interface optodeToMonitorInterface connect optode.dataOut to monitor.dataIn {
			flow outputDataFlow of DOReading
				from optode.dataOut.doReading to monitor.dataIn.doReading;
		}

		action 'measurement cycle' : 'Measurement Cycle' {
			out doReading : DOReading;
			action emit : 'Emit Blue Light' {
				out bluePulse : BlueLight;
			}
			flow emit.bluePulse to deliver.bluePulse;
			action deliver : 'Deliver Light to Tip' {
				in bluePulse : BlueLight;
				out deliveredLight : BlueLight;
			}
			flow deliver.deliveredLight to excite.deliveredLight;
			action excite : 'Excite and Quench Dye' {
				in deliveredLight : BlueLight;
				out emittedFluorescence : FluorescentLight;
			}
			flow excite.emittedFluorescence to collect.emittedFluorescence;
			action collect : 'Collect Emission' {
				in emittedFluorescence : FluorescentLight;
				out collectedFluorescence : FluorescentLight;
			}
			flow collect.collectedFluorescence to detect.collectedFluorescence;
			action detect : 'Detect Fluorescence' {
				in collectedFluorescence : FluorescentLight;
				out fluorescentSignal : FluorescentSignal;
			}
			action measureTemp : 'Measure Temperature' {
				out temperature : Temperature;
			}
			action measurePressure : 'Measure Pressure' {
				out pressure : Pressure;
			}
			action calc : 'Calculate DO Concentration' {
				in fluorescentSignal : FluorescentSignal;
				in temperature : Temperature;
				in pressure : Pressure;
				out concentration : DOConcentration;
			}
			flow detect.fluorescentSignal to calc.fluorescentSignal;
			flow measureTemp.temperature to calc.temperature;
			flow measurePressure.pressure to calc.pressure;
			action format : 'Format Data' {
				in concentration : DOConcentration;
				in temperature : Temperature;
				in pressure : Pressure;
				out doReading : DOReading;
			}
			flow calc.concentration to format.concentration;
			flow measureTemp.temperature to format.temperature;
			flow measurePressure.pressure to format.pressure;
			flow format.doReading to 'measurement cycle'::doReading;
			action transmit : 'Transmit Data' {
				in doReading : DOReading;
			}
			flow format.doReading to transmit.doReading;
			first start;
			then merge continue;
			then action engineStarted accept startCmd : StartCmd;
			then action engineStopped accept stopCmd : StopCmd;
			then continue;
			first engineStarted then emit;
			first emit then deliver;
			first deliver then excite;
			first excite then collect;
			first collect then detect;
			first engineStarted then measureTemp;
			first engineStarted then measurePressure;
			first detect then calc;
			first measureTemp then calc;
			first measurePressure then calc;
			first calc then format;
			first format then transmit;
			first transmit then engineStopped;
		}
	}

	package Requirements {
		requirement def MeasureDORequirement {
			doc
				"The optode shall measure dissolved oxygen concentration in liquid samples using the principle of fluorescence quenching.";
		}
		requirement def CompensationRequirement {
			doc
				"The signal processor shall compensate for temperature and pressure to ensure high accuracy of the dissolved oxygen reading.";
		}
		requirement def OutputFormatRequirement {
			doc
				"The data interface shall transmit a complete reading including concentration, temperature, pressure, and timestamp using RS-485 protocol.";
		}
		requirement def ContinuousOperationRequirement {
			doc
				"The optode shall continuously repeat the measurement cycle to provide real-time dissolved oxygen measurements.";
		}

		requirement measureDOReq : MeasureDORequirement;
		requirement compensationReq : CompensationRequirement;
		requirement outputFormatReq : OutputFormatRequirement;
		requirement continuousOpReq : ContinuousOperationRequirement;
	}
}
