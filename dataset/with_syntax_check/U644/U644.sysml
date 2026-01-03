package 'CylinderHeadTemperatureGaugeSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureReading :> ISQ::ThermodynamicTemperatureValue;
	attribute def VoltageLevel :> ISQ::ElectricPotentialValue;
	attribute def ResistanceLevel :> ISQ::ResistanceValue;
	
	item def ThermalSignal;
	item def ElectricalSignal;
	
	port def SensorOutputPort {
		out item signal : ElectricalSignal;
		out attribute voltage : VoltageLevel;
		attribute resistance : ResistanceLevel;
	}
	
	port def GaugeInputPort {
		in item signal : ElectricalSignal;
		in attribute voltage : VoltageLevel;
	}
	
	port def ThermalContactPort {
		attribute contactTemperature : TemperatureReading;
		in item thermalEnergy : ThermalSignal;
	}
	
	enum def GaugeIndicationStatus {
		NORMAL;
		CAUTION;
		OVERHEAT;
	}
	
	part def CylinderHead {
		port thermalPort : ThermalContactPort;
		attribute operatingTemperature : TemperatureReading;
	}
	
	part def TemperatureSensor {
		port thermalContact : ThermalContactPort;
		port electricalOutput : SensorOutputPort;
		attribute measuredTemperature : TemperatureReading;
		attribute sensorResistance : ResistanceLevel;
	}
	
	part def IndicatorGauge {
		port gaugeInput : GaugeInputPort;
		attribute displayedTemperature : TemperatureReading;
		attribute needleDeflection : Real;
		attribute indicationStatus : GaugeIndicationStatus;
		
		state def GaugeStatusMachine {
			entry; then NORMAL;
			
			state NORMAL {
				entry assign indicationStatus := GaugeIndicationStatus::NORMAL;
			}
			
			state CAUTION {
				entry assign indicationStatus := GaugeIndicationStatus::CAUTION;
			}
			
			state OVERHEAT {
				entry assign indicationStatus := GaugeIndicationStatus::OVERHEAT;
			}
			
			transition normalToCaution
				first NORMAL
				accept at gaugeInput
				if displayedTemperature >= 473.15[K]
				then CAUTION;
			
			transition cautionToOverheat
				first CAUTION
				accept at gaugeInput
				if displayedTemperature >= 523.15[K]
				then OVERHEAT;
			
			transition overheatToCaution
				first OVERHEAT
				accept at gaugeInput
				if displayedTemperature < 523.15[K]
				then CAUTION;
			
			transition cautionToNormal
				first CAUTION
				accept at gaugeInput
				if displayedTemperature < 473.15[K]
				then NORMAL;
		}
	}
	
	part def WarningLight {
		port warningInput : GaugeInputPort;
		attribute warningThreshold : TemperatureReading;
		attribute isActive : Boolean;
	}
	
	action def SenseTemperature {
		in cylinderTemp : TemperatureReading;
		out sensorVoltage : VoltageLevel;
		out resistance : ResistanceLevel;
	}
	
	action def ConvertVoltageToTemperature {
		in inputVoltage : VoltageLevel;
		out temperature : TemperatureReading;
	}
	
	action def UpdateNeedlePosition {
		in temperature : TemperatureReading;
		out deflection : Real;
	}
	
	action def EvaluateWarningCondition {
		in currentTemperature : TemperatureReading;
		in threshold : TemperatureReading;
		out activateWarning : Boolean;
	}
	
	action def MonitorCylinderHeadTemperature {
		doc /*
		 * Continuously monitors cylinder head temperature by sensing thermal conditions,
		 * converting sensor signals to temperature readings, updating the gauge display,
		 * and activating warnings when temperature exceeds safe operating limits.
		 */
		
		first start;
		then merge continuousMonitoring;
		
		then action sense : SenseTemperature {
			in cylinderTemp;
			out sensorVoltage;
			out resistance;
		}
		
		then action convert : ConvertVoltageToTemperature {
			in inputVoltage = sense.sensorVoltage;
			out temperature;
		}
		
		then action updateGauge : UpdateNeedlePosition {
			in temperature = convert.temperature;
			out deflection;
		}
		
		then action evaluateWarning : EvaluateWarningCondition {
			in currentTemperature = convert.temperature;
			in threshold;
			out activateWarning;
		}
		
		then continuousMonitoring;
	}
	
	part def CHTGaugeSystem {
		doc /*
		 * The Cylinder Head Temperature Gauge System monitors and displays the temperature
		 * of an engine cylinder head in real-time. The system uses a temperature sensor in
		 * thermal contact with the cylinder head to measure operating temperature. The sensor
		 * generates an electrical signal proportional to temperature, which is transmitted to
		 * an analog indicator gauge. The gauge converts the electrical signal to a visual
		 * needle deflection, providing the operator with immediate temperature information.
		 * When temperature exceeds predefined thresholds, the system transitions through
		 * caution and overheat states, activating warning indicators to alert the operator
		 * of potentially dangerous thermal conditions requiring corrective action.
		 */
		
		part cylinderHead : CylinderHead;
		part sensor : TemperatureSensor;
		part gauge : IndicatorGauge;
		part warning : WarningLight;
		
		attribute normalOperatingTemp : TemperatureReading;
		attribute cautionThreshold : TemperatureReading;
		attribute overheatThreshold : TemperatureReading;
		
		connection thermalCoupling connect cylinderHead.thermalPort to sensor.thermalContact;
		connection sensorToGauge connect sensor.electricalOutput to gauge.gaugeInput;
		connection sensorToWarning connect sensor.electricalOutput to warning.warningInput;
		
		perform action monitoring[*] ordered references MonitorCylinderHeadTemperature;
	}
	
	part chtSystem : CHTGaugeSystem {
		part redefines sensor {
			perform monitoring.sense;
		}
		
		part redefines gauge {
			perform monitoring.convert;
			perform monitoring.updateGauge;
			exhibit state statusBehavior : GaugeStatusMachine;
		}
		
		part redefines warning {
			perform monitoring.evaluateWarning;
		}
	}
	
	requirement def <'CHT-REQ-001'> TemperatureMeasurementAccuracy {
		doc /*
		 * The system shall measure cylinder head temperature with an accuracy of +/- 3 degrees Celsius
		 * across the full operating range of 0 to 300 degrees Celsius.
		 */
		
		subject system : CHTGaugeSystem;
		
		require constraint {
			system.sensor.measuredTemperature >= 273.15[K] and
			system.sensor.measuredTemperature <= 573.15[K]
		}
	}
	
	requirement def <'CHT-REQ-002'> DisplayUpdateRate {
		doc /*
		 * The gauge display shall update within 1 second of a temperature change to ensure
		 * timely operator awareness of thermal conditions.
		 */
	}
	
	requirement def <'CHT-REQ-003'> WarningThresholdActivation {
		doc /*
		 * The warning light shall activate when cylinder head temperature reaches or exceeds
		 * 523.15 K (250 degrees Celsius) and shall remain active until temperature drops below 518.15 K
		 * to provide hysteresis and prevent oscillation.
		 */
		
		subject warningSystem : WarningLight;
		
		require constraint {
			warningSystem.warningThreshold == 523.15[K]
		}
	}
	
	requirement def <'CHT-REQ-004'> CautionIndicationThreshold {
		doc /*
		 * The gauge shall transition to caution indication when temperature reaches 473.15 K
		 * to provide early warning of elevated thermal conditions.
		 */
	}
	
	requirement <'CHT-SYS-REQ'> cylinderHeadTemperatureGaugeSystemRequirements {
		doc /*
		 * The Cylinder Head Temperature Gauge System shall provide continuous, accurate
		 * monitoring of engine cylinder head temperature with visual indication and
		 * progressive warning states to enable operator intervention before thermal damage occurs.
		 */
		
		subject chtGaugeSystem : CHTGaugeSystem;
		
		require measurementAccuracy : TemperatureMeasurementAccuracy;
		require displayUpdate : DisplayUpdateRate;
		require warningActivation : WarningThresholdActivation;
		require cautionIndication : CautionIndicationThreshold;
	}
}
