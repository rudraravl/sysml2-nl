package BronchitisKettleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def VolumeValue :> ISQ::VolumeValue;
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def TimeValue :> ISQ::TimeValue;
	
	item def Water {
		attribute volume : VolumeValue;
		attribute temperature : TemperatureValue;
	}
	
	item def TherapeuticVapor {
		attribute temperature : TemperatureValue;
		attribute flowRate : FlowRateValue;
		attribute medicationConcentration : Real;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def MedicinalAdditive {
		attribute mass : ISQ::MassValue;
		attribute concentration : Real;
	}
	
	port def PowerInputPort {
		in item electricalPower : ElectricalPower;
	}
	
	port def WaterInputPort {
		in item water : Water;
	}
	
	port def VaporOutputPort {
		out item vapor : TherapeuticVapor;
	}
	
	port def AdditiveInputPort {
		in item additive : MedicinalAdditive;
	}
	
	port def ControlInterfacePort {
		in attribute targetTemperature : TemperatureValue;
		in attribute operationDuration : TimeValue;
		out attribute currentTemperature : TemperatureValue;
		out attribute systemStatus : String;
	}
	
	part def WaterReservoir {
		attribute maxCapacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		attribute waterTemperature : TemperatureValue;
		port waterInlet : WaterInputPort;
		port waterToBoiler;
	}
	
	part def HeatingElement {
		attribute ratedPower : PowerValue;
		attribute currentPower : PowerValue;
		attribute efficiency : Real;
		port powerConnection : PowerInputPort;
		port heatTransfer;
	}
	
	part def BoilingChamber {
		attribute chamberVolume : VolumeValue;
		attribute operatingTemperature : TemperatureValue;
		attribute pressureRating : ISQ::PressureValue;
		port waterInput;
		port heatInput;
		port additiveInput : AdditiveInputPort;
		port vaporGeneration;
	}
	
	part def TemperatureSensor {
		attribute measuredTemperature : TemperatureValue;
		attribute accuracy : TemperatureValue;
		port sensingPoint;
		port temperatureOutput;
	}
	
	part def VaporizationNozzle {
		attribute nozzleDiameter : ISQ::LengthValue;
		attribute vaporFlowRate : FlowRateValue;
		port vaporInput;
		port vaporOutput : VaporOutputPort;
	}
	
	part def ControllerUnit {
		attribute targetTemp : TemperatureValue;
		attribute maxSafeTemp : TemperatureValue;
		attribute sessionDuration : TimeValue;
		attribute currentState : String;
		port controlInterface : ControlInterfacePort;
		port sensorInput;
		port heaterControl;
		port safetyShutoff;
	}
	
	part def SafetyValve {
		attribute releaseThreshold : ISQ::PressureValue;
		attribute isOpen : Boolean;
		port pressureMonitor;
		port emergencyRelease;
	}
	
	part def BronchitisKettle {
		doc /* A therapeutic device that heats water with medicinal additives to generate 
		       controlled medicated vapor for respiratory treatment of bronchitis and similar conditions. */
		
		attribute operatingVoltage : ISQ::ElectricPotentialValue = 230.0 [SI::V];
		attribute maxWaterCapacity : VolumeValue = 2.0 [SI::L];
		attribute therapeuticTemperature : TemperatureValue = 368.15 [SI::K];
		attribute maxSafeTemperature : TemperatureValue = 378.15 [SI::K];
		attribute typicalSessionDuration : TimeValue = 1200.0 [SI::s];
		
		port mainPowerInput : PowerInputPort;
		port waterFillPort : WaterInputPort;
		port medicationPort : AdditiveInputPort;
		port vaporDeliveryPort : VaporOutputPort;
		port userInterface : ControlInterfacePort;
		
		part reservoir : WaterReservoir {
			attribute :>> maxCapacity = maxWaterCapacity;
		}
		
		part heater : HeatingElement {
			attribute :>> ratedPower = 1800.0 [SI::W];
			attribute :>> efficiency = 0.92;
		}
		
		part boiler : BoilingChamber {
			attribute :>> chamberVolume = 0.5 [SI::L];
			attribute :>> pressureRating = 120000.0 [SI::Pa];
		}
		
		part tempSensor : TemperatureSensor {
			attribute :>> accuracy = 0.5 [SI::K];
		}
		
		part nozzle : VaporizationNozzle {
			attribute :>> nozzleDiameter = 0.008 [SI::m];
		}
		
		part controller : ControllerUnit {
			attribute :>> targetTemp = therapeuticTemperature;
			attribute :>> maxSafeTemp = maxSafeTemperature;
			attribute :>> sessionDuration = typicalSessionDuration;
		}
		
		part safetyValve : SafetyValve {
			attribute :>> releaseThreshold = 110000.0 [SI::Pa];
		}
		
		connect mainPowerInput to heater.powerConnection;
		connect waterFillPort to reservoir.waterInlet;
		connect medicationPort to boiler.additiveInput;
		connect reservoir.waterToBoiler to boiler.waterInput;
		connect heater.heatTransfer to boiler.heatInput;
		connect boiler.vaporGeneration to nozzle.vaporInput;
		connect nozzle.vaporOutput to vaporDeliveryPort;
		connect tempSensor.sensingPoint to boiler;
		connect tempSensor.temperatureOutput to controller.sensorInput;
		connect controller.heaterControl to heater;
		connect controller.controlInterface to userInterface;
		connect safetyValve.pressureMonitor to boiler;
		
		perform action therapeuticVaporGeneration;
	}
	
	action def MeasureTemperature {
		in sensorReading : TemperatureValue;
		out currentTemp : TemperatureValue;
	}
	
	action def CalculateHeatingPower {
		in currentTemp : TemperatureValue;
		in targetTemp : TemperatureValue;
		in maxPower : PowerValue;
		out requiredPower : PowerValue;
	}
	
	action def ActivateHeater {
		in powerLevel : PowerValue;
		out heatingActive : Boolean;
	}
	
	action def GenerateVapor {
		in waterSupply : Water;
		in medication : MedicinalAdditive;
		in temperature : TemperatureValue;
		out therapeuticVapor : TherapeuticVapor;
	}
	
	action def MonitorSafety {
		in currentTemp : TemperatureValue;
		in maxSafeTemp : TemperatureValue;
		in waterLevel : VolumeValue;
		out safeToOperate : Boolean;
	}
	
	action def ShutdownSystem {
		in reason : String;
		out systemOff : Boolean;
	}
	
	action therapeuticVaporGeneration {
		doc /* Primary operational behavior: heat water with medicinal additives to therapeutic 
		       temperature and generate controlled medicated vapor for respiratory treatment. */
		
		in attribute powerSupply : ElectricalPower;
		in attribute waterInput : Water;
		in attribute medicinalInput : MedicinalAdditive;
		in attribute desiredTemperature : TemperatureValue;
		in attribute treatmentDuration : TimeValue;
		out attribute medicatedVapor : TherapeuticVapor;
		
		first start;
		then action initCheck : MonitorSafety {
			in currentTemp = tempSensor.measuredTemperature;
			in maxSafeTemp = controller.maxSafeTemp;
			in waterLevel = reservoir.currentLevel;
			out safeToOperate;
		}
		then decide;
			if initCheck.safeToOperate == false then emergencyStop;
			if initCheck.safeToOperate == true then heatingLoop;
		
		merge heatingLoop;
		then action measure : MeasureTemperature {
			in sensorReading = tempSensor.measuredTemperature;
			out currentTemp;
		}
		then action calculate : CalculateHeatingPower {
			in currentTemp = measure.currentTemp;
			in targetTemp = controller.targetTemp;
			in maxPower = heater.ratedPower;
			out requiredPower;
		}
		then decide;
			if measure.currentTemp < controller.targetTemp then applyHeat;
			if measure.currentTemp >= controller.targetTemp then generateVapor;
		
		action applyHeat : ActivateHeater {
			in powerLevel = calculate.requiredPower;
			out heatingActive;
		}
		then heatingLoop;
		
		action generateVapor : GenerateVapor {
			in waterSupply = waterInput;
			in medication = medicinalInput;
			in temperature = measure.currentTemp;
			out therapeuticVapor;
		}
		then assign medicatedVapor := generateVapor.therapeuticVapor;
		then action safetyCheck : MonitorSafety {
			in currentTemp = tempSensor.measuredTemperature;
			in maxSafeTemp = controller.maxSafeTemp;
			in waterLevel = reservoir.currentLevel;
			out safeToOperate;
		}
		then decide;
			if safetyCheck.safeToOperate == false then emergencyStop;
			if safetyCheck.safeToOperate == true then heatingLoop;
		
		action emergencyStop : ShutdownSystem {
			in reason = "Safety fault detected";
			out systemOff;
		}
		then done;
	}
	
	requirement def VaporGenerationRequirement {
		doc /* The kettle shall generate therapeutic vapor at controlled temperature for effective respiratory treatment. */
		
		subject kettle : BronchitisKettle;
		
		require constraint temperatureRange {
			kettle.tempSensor.measuredTemperature >= 363.15 [SI::K] and
			kettle.tempSensor.measuredTemperature <= 373.15 [SI::K]
		}
		
		require constraint vaporFlowRate {
			kettle.nozzle.vaporFlowRate >= 0.05 [SI::'L/min'] and
			kettle.nozzle.vaporFlowRate <= 0.2 [SI::'L/min']
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The kettle shall operate safely with automatic shutdown on fault conditions. */
		
		subject kettle : BronchitisKettle;
		
		require constraint overheatProtection {
			kettle.tempSensor.measuredTemperature <= kettle.maxSafeTemperature
		}
		
		require constraint dryRunProtection {
			kettle.reservoir.currentLevel > 0.1 [SI::L] or
			kettle.heater.currentPower == 0.0 [SI::W]
		}
		
		require constraint pressureRelief {
			kettle.safetyValve.isOpen == true implies
			kettle.boiler.pressureRating >= kettle.safetyValve.releaseThreshold
		}
	}
	
	requirement def CapacityRequirement {
		doc /* The kettle shall provide sufficient capacity for extended therapeutic sessions. */
		
		subject kettle : BronchitisKettle;
		
		require constraint waterCapacity {
			kettle.reservoir.maxCapacity >= 1.5 [SI::L]
		}
		
		require constraint sessionDuration {
			kettle.typicalSessionDuration >= 900.0 [SI::s]
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The kettle shall efficiently convert electrical power to thermal energy. */
		
		subject kettle : BronchitisKettle;
		
		require constraint heatingEfficiency {
			kettle.heater.efficiency >= 0.85
		}
		
		require constraint powerConsumption {
			kettle.heater.ratedPower <= 2000.0 [SI::W]
		}
	}
	
	requirement <'BK-SYS-001'> bronchitisKettleSystemRequirement {
		doc /* The Bronchitis Kettle System shall provide controlled therapeutic vapor generation 
		       by heating water with medicinal additives to produce medicated steam at safe, 
		       effective temperatures for respiratory treatment of bronchitis and related conditions. */
		
		subject system : BronchitisKettle;
		
		assume constraint powerAvailable {
			system.operatingVoltage == 230.0 [SI::V]
		}
		
		assume constraint waterSupplied {
			system.reservoir.currentLevel >= 0.5 [SI::L]
		}
		
		require vaporGeneration : VaporGenerationRequirement;
		require safety : SafetyRequirement;
		require capacity : CapacityRequirement;
		require efficiency : EfficiencyRequirement;
	}
}
