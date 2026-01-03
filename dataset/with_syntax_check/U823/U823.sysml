package 'Pirani Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureRange {
		attribute minPressure : PressureValue;
		attribute maxPressure : PressureValue;
	}
	
	attribute def ResistanceValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def CurrentValue :> Real;
	
	port def ElectricalPowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : CurrentValue;
	}
	
	port def VacuumInterfacePort {
		in attribute ambientPressure : PressureValue;
		in attribute gasTemperature : ThermodynamicTemperatureValue;
	}
	
	port def SignalPort {
		out attribute outputVoltage : VoltageValue;
		out attribute pressureReading : PressureValue;
	}
	
	item def VacuumEnvironment {
		attribute pressure : PressureValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute gasComposition : String;
	}
	
	part def SensingFilament {
		doc /* Heated wire element whose resistance changes with heat loss to surrounding gas. */
		
		attribute baseResistance : ResistanceValue;
		attribute operatingTemperature : ThermodynamicTemperatureValue;
		attribute heatingPower : PowerValue;
		
		port electricalConnection : ElectricalPowerPort;
		port vacuumExposure : VacuumInterfacePort;
	}
	
	part def BridgeCircuit {
		doc /* Wheatstone bridge configuration that converts resistance changes to voltage signals. */
		
		attribute referenceResistance : ResistanceValue;
		attribute bridgeVoltage : VoltageValue;
		attribute sensitivity : Real;
		
		port sensorInput : ElectricalPowerPort;
		port powerSupply : ElectricalPowerPort;
		port voltageOutput : SignalPort;
	}
	
	part def SignalConditioner {
		doc /* Amplifies and linearizes the bridge output for pressure calculation. */
		
		attribute amplificationGain : Real;
		attribute calibrationCoefficients : Real[*];
		
		port analogInput : SignalPort;
		port processedOutput : SignalPort;
	}
	
	part def PowerSupplyUnit {
		doc /* Provides stable electrical power to the gauge components. */
		
		attribute nominalVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
		attribute regulationAccuracy : Real;
		
		port powerOutput : ElectricalPowerPort;
	}
	
	part def VacuumChamberInterface {
		doc /* Physical connection to the vacuum system being monitored. */
		
		attribute chamberVolume : VolumeValue;
		attribute connectionType : String;
		
		port vacuumPort : VacuumInterfacePort;
	}
	
	part def DisplayController {
		doc /* Processes and displays pressure measurements to the user. */
		
		attribute displayResolution : Real;
		attribute updateRate : FrequencyValue;
		
		port dataInput : SignalPort;
	}
	
	action def HeatFilament {
		doc /* Apply electrical power to heat the sensing filament to operating temperature. */
		
		in supplyVoltage : VoltageValue;
		in targetTemperature : ThermodynamicTemperatureValue;
		out filamentCurrent : CurrentValue;
		out actualTemperature : ThermodynamicTemperatureValue;
	}
	
	action def MeasureThermalLoss {
		doc /* Determine heat loss from filament based on surrounding gas pressure. */
		
		in filamentTemperature : ThermodynamicTemperatureValue;
		in ambientPressure : PressureValue;
		in gasType : String;
		out heatTransferRate : PowerValue;
		out resistanceChange : ResistanceValue;
	}
	
	action def ConvertResistanceToBridgeVoltage {
		doc /* Convert filament resistance change to bridge output voltage. */
		
		in filamentResistance : ResistanceValue;
		in referenceResistance : ResistanceValue;
		in bridgeSupplyVoltage : VoltageValue;
		out outputVoltage : VoltageValue;
	}
	
	action def CalculatePressure {
		doc /* Convert bridge voltage to pressure reading using calibration data. */
		
		in measuredVoltage : VoltageValue;
		in calibrationCurve : Real[*];
		in temperatureCompensation : ThermodynamicTemperatureValue;
		out pressureValue : PressureValue;
	}
	
	action def DisplayPressure {
		doc /* Update display with current pressure reading. */
		
		in pressureReading : PressureValue;
		in displayFormat : String;
	}
	
	action def MeasureVacuumPressure {
		doc /* Complete measurement cycle from filament heating to pressure display. */
		
		in attribute vacuumPressure :> ISQ::pressure;
		in attribute supplyVoltage : VoltageValue;
		out attribute measuredPressure :> ISQ::pressure;
		out attribute outputSignal : VoltageValue;
		
		first start;
		then merge continuousMeasurement;
		
		then action heatFilament : HeatFilament {
			in supplyVoltage = supplyVoltage;
			in targetTemperature : ThermodynamicTemperatureValue;
			out filamentCurrent : CurrentValue;
			out actualTemperature : ThermodynamicTemperatureValue;
		}
		
		then action measureLoss : MeasureThermalLoss {
			in filamentTemperature = heatFilament.actualTemperature;
			in ambientPressure = vacuumPressure;
			in gasType : String;
			out heatTransferRate : PowerValue;
			out resistanceChange : ResistanceValue;
		}
		
		then action convertToBridge : ConvertResistanceToBridgeVoltage {
			in filamentResistance = measureLoss.resistanceChange;
			in referenceResistance : ResistanceValue;
			in bridgeSupplyVoltage : VoltageValue;
			out outputVoltage : VoltageValue;
		}
		
		then action calculatePressure : CalculatePressure {
			in measuredVoltage = convertToBridge.outputVoltage;
			in calibrationCurve : Real[*];
			in temperatureCompensation : ThermodynamicTemperatureValue;
			out pressureValue : PressureValue;
		}
		
		then action displayPressure : DisplayPressure {
			in pressureReading = calculatePressure.pressureValue;
			in displayFormat : String;
		}
		
		then assign measuredPressure := calculatePressure.pressureValue;
		then assign outputSignal := convertToBridge.outputVoltage;
		then continuousMeasurement;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The Pirani gauge shall measure vacuum pressure from 1e-4 Pa to 100000 Pa. */
		
		subject gauge : PiraniGaugeSystem;
		
		require constraint {
			gauge.operatingRange.minPressure == 1.0e-4 [SI::Pa] and
			gauge.operatingRange.maxPressure == 100000.0 [SI::Pa]
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The pressure measurement accuracy shall be within ±15% of reading. */
		
		subject gauge : PiraniGaugeSystem;
		
		require constraint {
			gauge.measurementAccuracy <= 0.15
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The gauge shall respond to pressure changes within 200 milliseconds. */
		
		subject gauge : PiraniGaugeSystem;
		
		require constraint {
			gauge.responseTime <= 0.2 [SI::s]
		}
	}
	
	requirement def FilamentStabilityRequirement {
		doc /* The sensing filament temperature shall stabilize within ±2 K during operation. */
		
		subject filament : SensingFilament;
		
		require constraint {
			filament.operatingTemperature >= 373.0 [SI::K] and
			filament.operatingTemperature <= 473.0 [SI::K]
		}
	}
	
	requirement def PowerStabilityRequirement {
		doc /* The power supply voltage regulation shall be within ±0.1% of nominal. */
		
		subject power : PowerSupplyUnit;
		
		require constraint {
			power.regulationAccuracy <= 0.001
		}
	}
	
	part def PiraniGaugeSystem {
		doc /* 
		A Pirani gauge system measures vacuum pressure by detecting thermal conductivity 
		changes in gas molecules. Its primary function is to continuously monitor and 
		report pressure levels in vacuum environments by measuring heat loss from a 
		heated filament, which varies proportionally with gas pressure and molecular density.
		*/
		
		attribute operatingRange : PressureRange {
			attribute minPressure = 1.0e-4 [SI::Pa];
			attribute maxPressure = 100000.0 [SI::Pa];
		}
		
		attribute measurementAccuracy : Real = 0.15;
		attribute responseTime : DurationValue = 0.2 [SI::s];
		attribute operatingTemperature : ThermodynamicTemperatureValue = 298.15 [SI::K];
		attribute calibrationDate : String;
		
		port vacuumInput : VacuumInterfacePort;
		port powerInput : ElectricalPowerPort;
		port signalOutput : SignalPort;
		
		part filament : SensingFilament {
			attribute baseResistance = 100.0;
			attribute operatingTemperature = 423.15 [SI::K];
			attribute heatingPower = 0.5 [SI::W];
		}
		
		part bridge : BridgeCircuit {
			attribute referenceResistance = 100.0;
			attribute bridgeVoltage = 5.0;
			attribute sensitivity = 0.05;
		}
		
		part conditioner : SignalConditioner {
			attribute amplificationGain = 100.0;
			attribute calibrationCoefficients = (1.0, 0.95, 0.02);
		}
		
		part power : PowerSupplyUnit {
			attribute nominalVoltage = 24.0;
			attribute maxCurrent = 0.5;
			attribute regulationAccuracy = 0.0005;
		}
		
		part chamber : VacuumChamberInterface {
			attribute chamberVolume = 0.001 [SI::'m³'];
			attribute connectionType = "KF25";
		}
		
		part display : DisplayController {
			attribute displayResolution = 0.01;
			attribute updateRate = 10.0 [SI::Hz];
		}
		
		connection powerToFilament : ElectricalPowerPort connect 
			power.powerOutput to filament.electricalConnection;
		
		connection filamentToBridge : ElectricalPowerPort connect 
			filament.electricalConnection to bridge.sensorInput;
		
		connection powerToBridge : ElectricalPowerPort connect 
			power.powerOutput to bridge.powerSupply;
		
		connection bridgeToConditioner : SignalPort connect 
			bridge.voltageOutput to conditioner.analogInput;
		
		connection conditionerToDisplay : SignalPort connect 
			conditioner.processedOutput to display.dataInput;
		
		connection chamberToFilament : VacuumInterfacePort connect 
			chamber.vacuumPort to filament.vacuumExposure;
		
		connection systemOutput : SignalPort connect 
			conditioner.processedOutput to signalOutput;
		
		perform action measurePressure : MeasureVacuumPressure {
			in vacuumPressure = vacuumInput.ambientPressure;
			in supplyVoltage = power.nominalVoltage;
			out measuredPressure;
			out outputSignal;
		}
	}
	
	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def FilamentStableSignal;
	attribute def FilamentFailureSignal;
	attribute def BridgeFailureSignal;
	attribute def ResetSignal;
	
	state def GaugeOperatingStates {
		entry; then idle;
		
		state idle {
			doc /* Gauge is powered but not actively measuring. */
			accept powerOn : PowerOnSignal;
			then warmup;
		}
		
		state warmup {
			doc /* Filament heating to stable operating temperature. */
			accept filamentStable : FilamentStableSignal;
			then measuring;
		}
		
		state measuring {
			doc /* Continuous pressure measurement and reporting. */
			accept powerOff : PowerOffSignal;
			then idle;
			accept filamentFailure : FilamentFailureSignal;
			then error;
			accept bridgeFailure : BridgeFailureSignal;
			then error;
		}
		
		state error {
			doc /* Fault condition detected, measurement suspended. */
			accept reset : ResetSignal;
			then idle;
		}
	}
	
	part piraniGaugeInstance : PiraniGaugeSystem {
		satisfy MeasurementRangeRequirement by piraniGaugeInstance;
		satisfy AccuracyRequirement by piraniGaugeInstance;
		satisfy ResponseTimeRequirement by piraniGaugeInstance;
		satisfy FilamentStabilityRequirement by piraniGaugeInstance.filament;
		satisfy PowerStabilityRequirement by piraniGaugeInstance.power;
	}
}
