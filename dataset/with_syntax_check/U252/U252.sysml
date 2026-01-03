package HydrocollatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def TimeValue :> ISQ::TimeValue;
	attribute def VolumeValue :> ISQ::VolumeValue;
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def MassValue :> ISQ::MassValue;
	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def CurrentValue :> ISQ::ElectricCurrentValue;
	
	item def Water {
		attribute temperature : TemperatureValue;
		attribute volume : VolumeValue;
	}
	
	item def MoistHeatPack {
		attribute mass : MassValue;
		attribute temperature : TemperatureValue;
		attribute isReady : Boolean;
	}
	
	item def TemperatureReading {
		attribute value : TemperatureValue;
		attribute timestamp : TimeValue;
	}
	
	port def PowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : CurrentValue;
	}
	
	port def TemperatureSensorPort {
		out item reading : TemperatureReading;
	}
	
	port def HeaterControlPort {
		in attribute powerLevel : PowerValue;
	}
	
	part def HeatingElement {
		attribute ratedPower : PowerValue;
		attribute currentPower : PowerValue;
		port powerInput : PowerPort;
		port controlInput : HeaterControlPort;
		
		action def Activate {
			assign currentPower := ratedPower;
		}
		
		action def Deactivate {
			assign currentPower := 0.0[W];
		}
	}
	
	part def InsulatedTank {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute waterTemperature : TemperatureValue;
		attribute heatLossRate : PowerValue;
	}
	
	part def TemperatureSensor {
		attribute measuredTemperature : TemperatureValue;
		attribute accuracy : TemperatureValue;
		port sensorOutput : TemperatureSensorPort;
		
		action def MeasureTemperature {
			in tankTemp : TemperatureValue;
			out reading : TemperatureReading;
		}
	}
	
	part def ThermostaticController {
		attribute setpointLow : TemperatureValue;
		attribute setpointHigh : TemperatureValue;
		attribute currentMode : String;
		port temperatureInput : TemperatureSensorPort;
		port heaterControl : HeaterControlPort;
		
		action def EvaluateTemperature {
			in currentTemp : TemperatureValue;
			in lowSetpoint : TemperatureValue;
			in highSetpoint : TemperatureValue;
			out heatingRequired : Boolean;
		}
		
		action def CommandHeater {
			in heatingRequired : Boolean;
			out powerCommand : PowerValue;
		}
	}
	
	part def PackHolder {
		attribute numberOfSlots : Integer;
		attribute occupiedSlots : Integer;
	}
	
	part def IndicatorLight {
		attribute isOn : Boolean;
		attribute color : String;
	}
	
	event def PowerOn;
	event def PowerOff;
	event def OperatingTemperatureReached;
	event def TemperatureBelowSetpoint;
	event def TemperatureAboveSetpoint;
	
	state def HydrocollatorOperatingStates {
		entry; then powerOff;
		
		state powerOff {
			entry assign hydrocollatorUnit.tank.waterTemperature := 20.0[SI::degC];
			entry assign hydrocollatorUnit.heatingIndicator.isOn := false;
		}
		
		transition powerOff_to_initialHeating
			first powerOff
			accept PowerOn
			then initialHeating;
		
		state initialHeating {
			entry assign hydrocollatorUnit.heatingIndicator.isOn := true;
			entry assign hydrocollatorUnit.heatingIndicator.color := "red";
			do action heatUp {
				in targetTemp : TemperatureValue = hydrocollatorUnit.controller.setpointLow;
				in currentTemp : TemperatureValue = hydrocollatorUnit.sensor.measuredTemperature;
			}
		}
		
		transition initialHeating_to_maintaining
			first initialHeating
			accept OperatingTemperatureReached
			then maintaining;
		
		state maintaining {
			entry assign hydrocollatorUnit.heatingIndicator.color := "green";
			
			state idle {
				entry assign hydrocollatorUnit.heater.currentPower := 0.0[W];
			}
			
			state heating {
				entry assign hydrocollatorUnit.heater.currentPower := hydrocollatorUnit.heater.ratedPower;
			}
			
			transition idle_to_heating
				first idle
				accept TemperatureBelowSetpoint
				then heating;
			
			transition heating_to_idle
				first heating
				accept TemperatureAboveSetpoint
				then idle;
		}
		
		transition maintaining_to_powerOff
			first maintaining
			accept PowerOff
			then powerOff;
	}
	
	action def MonitorAndRegulateTemperature {
		in setpointLow : TemperatureValue;
		in setpointHigh : TemperatureValue;
		
		first start;
		then merge checkCycle;
		
		then action measureTemp : MeasureCurrentTemperature {
			out temperature : TemperatureValue;
		}
		
		then decide;
			if measureTemp.temperature < setpointLow then activateHeating;
			if measureTemp.temperature >= setpointHigh then deactivateHeating;
			if measureTemp.temperature >= setpointLow and measureTemp.temperature < setpointHigh then maintain;
		
		action activateHeating : ActivateHeater {
			in command = true;
		}
		then checkCycle;
		
		action deactivateHeating : ActivateHeater {
			in command = false;
		}
		then checkCycle;
		
		action maintain : MaintainCurrentState;
		then checkCycle;
	}
	
	action def MeasureCurrentTemperature {
		out temperature : TemperatureValue;
	}
	
	action def ActivateHeater {
		in command : Boolean;
	}
	
	action def MaintainCurrentState;
	
	action def HeatMoistPacks {
		in immersionDuration : TimeValue;
		in waterTemp : TemperatureValue;
		in packs : MoistHeatPack[*];
		out heatedPacks : MoistHeatPack[*];
		
		first start;
		then action immerse {
			in duration = immersionDuration;
			in bathTemperature = waterTemp;
		}
		then action equilibrate {
			in targetTemp = waterTemp;
		}
		then assign heatedPacks := packs;
		then done;
	}
	
	part def Hydrocollator {
		doc /*
		 * A Hydrocollator is a thermostatically controlled water bath system designed
		 * to heat and maintain moist heat packs at therapeutic temperatures for
		 * physical therapy and pain relief applications. The system continuously
		 * heats water to a controlled temperature range (typically 71-79 degC) and
		 * maintains this temperature to ensure packs are ready for safe therapeutic use.
		 */
		
		attribute operatingTemperatureLow : TemperatureValue = 71.0[SI::degC];
		attribute operatingTemperatureHigh : TemperatureValue = 79.0[SI::degC];
		attribute tankCapacity : VolumeValue = 20.0[SI::L];
		attribute heatingPower : PowerValue = 1650.0[SI::W];
		attribute standardImmersionTime : TimeValue = 1800.0[SI::s];
		
		port mainPower : PowerPort;
		
		part tank : InsulatedTank {
			attribute :>> capacity = 20.0[SI::L];
			attribute :>> currentVolume = 18.0[SI::L];
			attribute :>> waterTemperature = 75.0[SI::degC];
			attribute :>> heatLossRate = 150.0[SI::W];
		}
		
		part heater : HeatingElement {
			attribute :>> ratedPower = 1650.0[SI::W];
			attribute :>> currentPower = 0.0[SI::W];
		}
		
		part sensor : TemperatureSensor {
			attribute :>> measuredTemperature = tank.waterTemperature;
			attribute :>> accuracy = 0.5[SI::degC];
		}
		
		part controller : ThermostaticController {
			attribute :>> setpointLow = 71.0[SI::degC];
			attribute :>> setpointHigh = 79.0[SI::degC];
			attribute :>> currentMode = "maintaining";
		}
		
		part packHolder : PackHolder {
			attribute :>> numberOfSlots = 8;
			attribute :>> occupiedSlots = 0;
		}
		
		part heatingIndicator : IndicatorLight {
			attribute :>> isOn = true;
			attribute :>> color = "green";
		}
		
		connection powerConnection connect mainPower to heater.powerInput;
		connection sensorToController connect sensor.sensorOutput to controller.temperatureInput;
		connection controlToHeater connect controller.heaterControl to heater.controlInput;
		
		perform action regulateTemperature : MonitorAndRegulateTemperature {
			in setpointLow = operatingTemperatureLow;
			in setpointHigh = operatingTemperatureHigh;
		}
	}
	
	part hydrocollatorUnit : Hydrocollator {
		exhibit state operatingBehavior : HydrocollatorOperatingStates;
	}
	
	requirement def TherapeuticTemperatureRequirement {
		doc /*
		 * The hydrocollator shall maintain water temperature within the therapeutic
		 * range to ensure moist heat packs reach and maintain safe, effective
		 * treatment temperatures.
		 */
		subject unit : Hydrocollator;
		
		require constraint temperatureRange {
			unit.tank.waterTemperature >= unit.operatingTemperatureLow and
			unit.tank.waterTemperature <= unit.operatingTemperatureHigh
		}
	}
	
	requirement def SafetyRequirement {
		doc /*
		 * The hydrocollator shall not exceed maximum safe temperature to prevent
		 * burns and ensure patient safety during therapeutic applications.
		 */
		subject unit : Hydrocollator;
		
		require constraint maximumTemperature {
			unit.tank.waterTemperature <= 82.0[SI::degC]
		}
	}
	
	requirement def CapacityRequirement {
		doc /*
		 * The hydrocollator shall provide sufficient capacity to accommodate
		 * multiple moist heat packs simultaneously for clinical efficiency.
		 */
		subject unit : Hydrocollator;
		
		require constraint minimumSlots {
			unit.packHolder.numberOfSlots >= 6
		}
		
		require constraint minimumVolume {
			unit.tank.capacity >= 15.0[SI::L]
		}
	}
	
	requirement def HeatingPerformanceRequirement {
		doc /*
		 * The hydrocollator shall provide adequate heating power to reach and
		 * maintain operating temperature despite continuous heat loss.
		 */
		subject unit : Hydrocollator;
		
		require constraint adequatePower {
			unit.heater.ratedPower >= 1200.0[SI::W]
		}
	}
	
	requirement <'HC-SYS-001'> primaryFunctionRequirement : TherapeuticTemperatureRequirement {
		doc /*
		 * PRIMARY FUNCTION: The hydrocollator system shall continuously heat and
		 * maintain water at controlled therapeutic temperatures (71-79 degC) to warm
		 * moist heat packs for physical therapy applications. The system provides
		 * reliable thermal conditioning of therapeutic packs through sustained
		 * immersion in thermostatically regulated heated water, ensuring packs
		 * are consistently ready for safe and effective patient treatment.
		 */
		
		assume constraint waterPresent {
			hydrocollatorUnit.tank.currentVolume >= 10.0[SI::L]
		}
		
		assume constraint powerAvailable {
			hydrocollatorUnit.mainPower.voltage >= 110.0[SI::V]
		}
		
		require temperatureRange;
	}
	
	requirement <'HC-SYS-002'> systemRequirements {
		doc /*
		 * The hydrocollator system shall meet all operational, safety, and
		 * performance requirements for clinical therapeutic use.
		 */
		
		require primaryFunctionRequirement;
		require safetyRequirement : SafetyRequirement;
		require capacityRequirement : CapacityRequirement;
		require performanceRequirement : HeatingPerformanceRequirement;
	}
}
