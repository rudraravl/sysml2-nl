package 'Hot Filament Ionization Gauge' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	alias Temperature for ISQ::TemperatureValue;
	alias Pressure for ISQ::PressureValue;
	alias Current for ISQ::ElectricCurrentValue;
	alias Voltage for ISQ::ElectricPotentialValue;
	alias Charge for ISQ::ElectricChargeValue;

	item def Electron {
		attribute charge : Charge = 1.602e-19 [C];
	}
	item def GasMolecule;
	item def PositiveIon {
		attribute charge : Charge = 1.602e-19 [C];
	}

	attribute def SensitivityFactor :> Real;
	attribute def SafePressureThreshold :> Pressure;

	attribute def WarmUpComplete;
	attribute def HighPressureAlert;
	attribute def SystemReset;

	port def ElectronPort {
		out electronFlow : Current;
	}
	port def IonPort {
		out ionFlow : Current;
	}
	port def PowerPort {
		out voltage : Voltage;
	}
	port def CurrentPort {
		out current : Current;
	}
	port def PressurePort {
		out pressure : Pressure;
	}
	port def ControlPort {
		out shutdownCommand : Boolean;
	}

	part def HeatedFilament {
		attribute temperature : Temperature;
		in powerIn : PowerPort;
		out electronPort : ElectronPort;
		in controlIn : ControlPort;
	}
	part def AcceleratingGrid {
		attribute gridVoltage : Voltage;
		in powerIn : PowerPort;
		in electronPort : ElectronPort;
		out acceleratedElectronPort : ElectronPort;
	}
	part def IonizationRegion {
		attribute chamberPressure : Pressure;
		in electronPort : ElectronPort;
		out ionPort : IonPort;
	}
	part def IonCollector {
		attribute biasVoltage : Voltage;
		in powerIn : PowerPort;
		in ionPort : IonPort;
		out ionCurrentPort : CurrentPort;
	}
	part def SignalProcessor {
		attribute sensitivity : SensitivityFactor;
		in ionCurrentPort : CurrentPort;
		out pressurePort : PressurePort;
	}
	part def PowerSupplyUnit {
		out filamentPower : PowerPort;
		out gridPower : PowerPort;
		out collectorPower : PowerPort;
	}
	part def ProtectionCircuit {
		attribute threshold : SafePressureThreshold = 1.0e-3 [Pa];
		in pressurePort : PressurePort;
		out controlOut : ControlPort;
	}

	part def HotFilamentIonizationGauge {
		part filament : HeatedFilament;
		part grid : AcceleratingGrid;
		part ionRegion : IonizationRegion;
		part collector : IonCollector;
		part processor : SignalProcessor;
		part powerSupply : PowerSupplyUnit;
		part protection : ProtectionCircuit;

		connect powerSupply.filamentPower to filament.powerIn;
		connect powerSupply.gridPower to grid.powerIn;
		connect powerSupply.collectorPower to collector.powerIn;

		connect filament.electronPort to grid.electronPort;
		connect grid.acceleratedElectronPort to ionRegion.electronPort;
		connect ionRegion.ionPort to collector.ionPort;
		connect collector.ionCurrentPort to processor.ionCurrentPort;
		connect processor.pressurePort to protection.pressurePort;
		connect protection.controlOut to filament.controlIn;
	}

	action def HeatFilament {
		in voltage : Voltage;
		out temperature : Temperature;
	}
	action def EmitElectrons {
		in filamentTemperature : Temperature;
		out electronCurrent : Current;
	}
	action def AccelerateElectrons {
		in electronCurrent : Current;
		in gridVoltage : Voltage;
		out acceleratedCurrent : Current;
	}
	action def IonizeGas {
		in acceleratedCurrent : Current;
		in gasPressure : Pressure;
		out ionCurrent : Current;
	}
	action def CollectIons {
		in ionCurrent : Current;
		out measuredCurrent : Current;
	}
	action def ProcessSignal {
		in measuredCurrent : Current;
		in sensitivity : SensitivityFactor;
		out pressure : Pressure;
	}
	action def MonitorPressure {
		in pressure : Pressure;
		in safeThreshold : SafePressureThreshold;
		out isSafe : Boolean;
	}
	action def ShutdownFilament;

	action def PerformMeasurement {
		in filamentTemp : Temperature;
		in gridVolt : Voltage;
		in gasPress : Pressure;
		in sens : SensitivityFactor;
		in safeThresh : SafePressureThreshold;

		first start;
		then action emit : EmitElectrons {
			in filamentTemperature = filamentTemp;
			out electronCurrent : Current;
		}
		then action accelerate : AccelerateElectrons {
			in electronCurrent = emit.electronCurrent;
			in gridVoltage = gridVolt;
			out acceleratedCurrent : Current;
		}
		then action ionize : IonizeGas {
			in acceleratedCurrent = accelerate.acceleratedCurrent;
			in gasPressure = gasPress;
			out ionCurrent : Current;
		}
		then action collect : CollectIons {
			in ionCurrent = ionize.ionCurrent;
			out measuredCurrent : Current;
		}
		then action process : ProcessSignal {
			in measuredCurrent = collect.measuredCurrent;
			in sensitivity = sens;
			out pressure : Pressure;
		}
		then action monitor : MonitorPressure {
			in pressure = process.pressure;
			in safeThreshold = safeThresh;
			out isSafe : Boolean;
		}
		then done;
	}

	state def GaugeStates;

	requirement def FilamentOperatingTemperatureRequirement {
		doc /* The filament must reach approximately 2500 K to thermionically emit electrons. */
	}
	requirement def SafePressureShutdownRequirement {
		doc /* The protection circuit shall shut down the filament if pressure exceeds the safe threshold. */
	}
	requirement def PressureMeasurementRequirement {
		doc /* The signal processor shall convert ion current to pressure using a calibrated sensitivity factor. */
	}

	part gauge : HotFilamentIonizationGauge;

	state gaugeStates : GaugeStates {
		entry; then warmUp;
		state warmUp {
			do action heat : HeatFilament {
				in voltage = gauge.powerSupply.filamentPower.voltage;
				out temperature : Temperature;
			}
		}
		accept WarmUpComplete
			if gauge.filament.temperature >= 2500 [K]
			then normalOperation;
		state normalOperation {
			do action measure : PerformMeasurement {
				in filamentTemp = gauge.filament.temperature;
				in gridVolt = gauge.grid.gridVoltage;
				in gasPress = gauge.ionRegion.chamberPressure;
				in sens = gauge.processor.sensitivity;
				in safeThresh = gauge.protection.threshold;
			}
		}
		accept HighPressureAlert
			if gauge.ionRegion.chamberPressure > gauge.protection.threshold
			then emergencyShutdown;
		state emergencyShutdown {
			entry action shutdown : ShutdownFilament;
		}
		accept SystemReset then warmUp;
	}

	requirement 'filament operating temperature' : FilamentOperatingTemperatureRequirement {
		subject gauge : HotFilamentIonizationGauge;
		assert constraint { gauge.filament.temperature >= 2500 [K] }
	}
	requirement 'safe pressure shutdown' : SafePressureShutdownRequirement {
		subject gauge : HotFilamentIonizationGauge;
		assert constraint { gauge.ionRegion.chamberPressure <= gauge.protection.threshold }
	}
	requirement 'pressure measurement sensitivity' : PressureMeasurementRequirement {
		subject gauge : HotFilamentIonizationGauge;
		assert constraint { gauge.processor.sensitivity > 0.0 }
	}
}
