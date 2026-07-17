package EspressoMachineSystem {
    attribute def PowerOnSignal;
    attribute def BrewStartSignal;
    attribute def GrindCompleteSignal;
    attribute def TargetVolumeReached;
    attribute def ResetSignal;
    attribute def PowerOffSignal;

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BrewTemperature :> TemperatureValue;
	attribute def BrewPressure :> PressureValue;
	attribute def WaterVolume :> VolumeValue;
	attribute def BrewDuration :> TimeValue;
	attribute def GrindFineness :> Real;
	attribute def PowerConsumption :> PowerValue;
	
	item def Water;
	item def CoffeeBeans;
	item def GroundCoffee;
	item def Espresso;
	item def Steam;
	
	item def HeatedWater {
		attribute temperature : BrewTemperature;
		attribute pressure : BrewPressure;
	}
	
	signal def PowerOnSignal;
	signal def PowerOffSignal;
	signal def BrewStartSignal;
	signal def GrindCompleteSignal;
	signal def TargetVolumeReached;
	signal def ResetSignal;
	
	port def WaterInletPort {
		in item waterSupply : Water;
	}
	
	port def WaterOutletPort {
		out item waterFlow : Water;
	}
	
	port def HeatedWaterPort {
		out item hotWater : HeatedWater;
		attribute temperature : BrewTemperature;
		attribute pressure : BrewPressure;
	}
	
	port def CoffeeInputPort {
		in item beans : CoffeeBeans;
	}
	
	port def GroundsPort {
		out item grounds : GroundCoffee;
	}
	
	port def BrewPort {
		in item hotWater : HeatedWater;
		in item grounds : GroundCoffee;
		out item espresso : Espresso;
	}
	
	port def EspressoOutputPort {
		out item espressoShot : Espresso;
		attribute volume : WaterVolume;
	}
	
	port def SteamPort {
		out item steamFlow : Steam;
		attribute temperature : BrewTemperature;
	}
	
	part def WaterReservoir {
		attribute capacity : WaterVolume;
		attribute currentLevel : WaterVolume;
		port waterOut : WaterOutletPort;
	}
	
	part def Pump {
		attribute maxPressure : BrewPressure;
		attribute flowRate : WaterVolume;
		port waterIn : WaterInletPort;
		port waterOut : WaterOutletPort;
	}
	
	part def Boiler {
		attribute targetTemperature : BrewTemperature;
		attribute operatingPressure : BrewPressure;
		attribute heatingPower : PowerConsumption;
		attribute currentTemperature : BrewTemperature;
		port waterIn : WaterInletPort;
		port heatedWaterOut : HeatedWaterPort;
		port steamOut : SteamPort;
	}
	
	part def Grinder {
		attribute grindSetting : GrindFineness;
		attribute motorPower : PowerConsumption;
		port beansIn : CoffeeInputPort;
		port groundsOut : GroundsPort;
	}
	
	part def GroupHead {
		attribute brewTemperature : BrewTemperature;
		attribute brewPressure : BrewPressure;
		port waterIn : WaterInletPort;
		port groundsIn : CoffeeInputPort;
		port espressoOut : EspressoOutputPort;
	}
	
	part def Portafilter {
		attribute basketCapacity : WaterVolume;
		port groundsIn : CoffeeInputPort;
		port brewInterface : BrewPort;
	}
	
	part def SteamWand {
		port steamIn : WaterInletPort;
		port steamOut : SteamPort;
	}
	
	part def ControlPanel {
		attribute selectedVolume : WaterVolume;
		attribute selectedStrength : Real;
		attribute powerOn : Boolean;
	}
	
	state def MachineOperationStates {
		in attribute targetTemp : BrewTemperature;
		in attribute brewTime : BrewDuration;
		attribute currentTemp : BrewTemperature;
		attribute brewStartTime : TimeValue;
		attribute currentTime : TimeValue;
		
		entry; then off;
		
		state off;
		transition off_to_warmup
			first off
			accept PowerOnSignal
			then warmup;
		
		state warmup {
			entry assign currentTemp := 293.15[K];
		}
		transition warmup_to_ready
			first warmup
			if currentTemp >= targetTemp
			then ready;
		
		state ready;
		transition ready_to_grinding
			first ready
			accept BrewStartSignal
			then grinding;
		
		state grinding;
		transition grinding_to_brewing
			first grinding
			accept GrindCompleteSignal
			then brewing;
		
		state brewing {
			entry assign brewStartTime := currentTime;
		}
		transition brewing_to_dispensing
			first brewing
			if (currentTime - brewStartTime) >= brewTime
			then dispensing;
		
		state dispensing;
		transition dispensing_to_complete
			first dispensing
			accept TargetVolumeReached
			then complete;
		
		state complete;
		transition complete_to_ready
			first complete
			accept ResetSignal
			then ready;
		
		transition ready_to_off
			first ready
			accept PowerOffSignal
			then off;
	}
	
	action def HeatWater {
		in waterInput : Water;
		in targetTemp : BrewTemperature;
		in heatingPower : PowerConsumption;
		out heatedWater : HeatedWater;
		out actualTemp : BrewTemperature;
	}
	
	action def PressurizeWater {
		in waterInput : Water;
		in targetPressure : BrewPressure;
		out pressurizedWater : HeatedWater;
		out actualPressure : BrewPressure;
	}
	
	action def GrindBeans {
		in beans : CoffeeBeans;
		in grindSize : GrindFineness;
		in doseMass : MassValue;
		out grounds : GroundCoffee;
	}
	
	action def TampGrounds {
		in grounds : GroundCoffee;
		in tampPressure : PressureValue;
		out compactedGrounds : GroundCoffee;
	}
	
	action def ExtractEspresso {
		in hotWater : HeatedWater;
		in grounds : GroundCoffee;
		in extractionTime : BrewDuration;
		in pressure : BrewPressure;
		out espressoShot : Espresso;
		out extractedVolume : WaterVolume;
	}
	
	action def BrewEspressoShot {
		in targetVolume : WaterVolume;
		in grindLevel : GrindFineness;
		in brewTemp : BrewTemperature;
		in brewPressure : BrewPressure;
		out finalEspresso : Espresso;
		
		first start;
		then action initialize {
			out temp : BrewTemperature = brewTemp;
			out pressure : BrewPressure = brewPressure;
			out grind : GrindFineness = grindLevel;
			out dose : MassValue = 0.018[kg];
		}
		then merge prepareWater;
		action heatWater : HeatWater {
			in targetTemp = initialize.temp;
			in heatingPower = 1450.0[W];
			out heatedWater;
			out actualTemp;
		}
		then action pressurize : PressurizeWater {
			in waterInput = heatWater.heatedWater;
			in targetPressure = initialize.pressure;
			out pressurizedWater;
			out actualPressure;
		}
		then prepareWater;
		action grindBeans : GrindBeans {
			in grindSize = initialize.grind;
			in doseMass = initialize.dose;
			out grounds;
		}
		then action tamp : TampGrounds {
			in grounds = grindBeans.grounds;
			in tampPressure = 147150.0[Pa];
			out compactedGrounds;
		}
		then action extract : ExtractEspresso {
			in hotWater = pressurize.pressurizedWater;
			in grounds = tamp.compactedGrounds;
			in pressure = pressurize.actualPressure;
			in extractionTime = 25.0[s];
			out espressoShot;
			out extractedVolume;
		}
		then decide;
			if extract.extractedVolume < targetVolume then extract;
			if extract.extractedVolume >= targetVolume then finish;
		action finish {
			in espresso = extract.espressoShot;
			out finalShot : Espresso = espresso;
		}
		then done;
	}
	
	requirement def BrewQualityRequirement {
		doc /* The espresso machine shall produce espresso at optimal temperature and pressure for quality extraction. */
		
		require constraint optimalTemperature {
			doc /* Brew temperature at group head shall be between 363K and 369K (90C and 96C). */
		}
		
		require constraint optimalPressure {
			doc /* Brew pressure shall be between 800000 Pa and 1000000 Pa (8 bar and 10 bar) during extraction. */
		}
		
		require constraint extractionTime {
			doc /* Extraction time for a double shot shall be between 20 and 30 seconds. */
		}
		
		require constraint shotVolume {
			doc /* Double shot volume shall be between 0.00005 m3 and 0.00006 m3 (50ml and 60ml). */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The espresso machine shall operate safely under all conditions. */
		
		require constraint pressureRelief {
			doc /* Boiler pressure shall not exceed 1500000 Pa (15 bar) with automatic relief valve. */
		}
		
		require constraint temperatureLimit {
			doc /* External touchable surfaces shall not exceed 338K (65C) during operation. */
		}
		
		require constraint electricalSafety {
			doc /* Machine shall have proper grounding and thermal cutoff protection. */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The espresso machine shall meet performance specifications. */
		
		require constraint heatupTime {
			doc /* Machine shall reach operating temperature within 300 seconds (5 minutes) from cold start. */
		}
		
		require constraint shotConsistency {
			doc /* Temperature variation between consecutive shots shall not exceed 2K. */
		}
		
		require constraint waterCapacity {
			doc /* Water reservoir shall hold minimum 0.002 m3 (2 liters) for multiple shots. */
		}
	}
	
	requirement <'ESM-REQ-001'> espressoMachineSystemRequirements {
		doc /* The espresso machine shall brew high-quality espresso shots safely, reliably, and consistently. */
		
		require brewQualityReq : BrewQualityRequirement;
		require safetyReq : SafetyRequirement;
		require performanceReq : PerformanceRequirement;
	}
	
	part def EspressoMachine {
		doc /* 
		An espresso machine system that produces high-quality espresso shots.
		
		Primary Function:
		The espresso machine heats water to optimal brewing temperature (363-369K), 
		pressurizes it to 900000 Pa (9 bar), grinds coffee beans to precise fineness, and extracts 
		espresso by forcing hot pressurized water through compacted coffee grounds. 
		This process produces a concentrated coffee beverage with characteristic crema, 
		rich flavor, and aromatic oils. The system automates the complex brewing process 
		while maintaining precise control over temperature, pressure, and extraction time 
		to ensure consistent, high-quality espresso shots.
		*/
		
		attribute operatingVoltage : Real = 230.0;
		attribute powerRating : PowerConsumption = 1450.0[W];
		attribute targetBrewTemp : BrewTemperature = 366.15[K];
		attribute targetBrewPressure : BrewPressure = 900000.0[Pa];
		
		part reservoir : WaterReservoir {
			attribute :>> capacity = 0.0025[m^3];
			attribute :>> currentLevel = 0.002[m^3];
		}
		
		part pump : Pump {
			attribute :>> maxPressure = 1500000.0[Pa];
			attribute :>> flowRate = 0.0000016667[m^3/s];
		}
		
		part boiler : Boiler {
			attribute :>> targetTemperature = 366.15[K];
			attribute :>> operatingPressure = 900000.0[Pa];
			attribute :>> heatingPower = 1450.0[W];
			attribute :>> currentTemperature = 293.15[K];
		}
		
		part grinder : Grinder {
			attribute :>> grindSetting = 5.0;
			attribute :>> motorPower = 150.0[W];
		}
		
		part groupHead : GroupHead {
			attribute :>> brewTemperature = 366.15[K];
			attribute :>> brewPressure = 900000.0[Pa];
		}
		
		part portafilter : Portafilter {
			attribute :>> basketCapacity = 0.00002[m^3];
		}
		
		part steamWand : SteamWand;
		
		part controlPanel : ControlPanel {
			attribute :>> selectedVolume = 0.00006[m^3];
			attribute :>> selectedStrength = 1.0;
			attribute :>> powerOn = false;
		}
		
		connect reservoir.waterOut to pump.waterIn;
		connect pump.waterOut to boiler.waterIn;
		connect boiler.heatedWaterOut to groupHead.waterIn;
		connect grinder.groundsOut to portafilter.groundsIn;
		connect portafilter.brewInterface to groupHead.espressoOut;
		connect boiler.steamOut to steamWand.steamIn;
		
		perform action brewCycle : BrewEspressoShot {
			in targetVolume = controlPanel.selectedVolume;
			in grindLevel = grinder.grindSetting;
			in brewTemp = targetBrewTemp;
			in brewPressure = targetBrewPressure;
		}
	}
	
	part espressoMachineInstance : EspressoMachine;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import EspressoMachineSystem::*;

    part testSubject : WaterReservoir {
        exhibit state sm : MachineOperationStates;
    }

    action orchestrator {
        attribute testTargetTemp : BrewTemperature;
        attribute testHeatingPower : PowerConsumption;
        action heatWaterProbe : HeatWater {
            in targetTemp = testTargetTemp;
            in heatingPower = testHeatingPower;
        }
        attribute testPowerOnSignal : PowerOnSignal;
        attribute testBrewStartSignal : BrewStartSignal;
        attribute testGrindCompleteSignal : GrindCompleteSignal;
        attribute testTargetVolumeReached : TargetVolumeReached;
        attribute testResetSignal : ResetSignal;
        action triggerPowerOnSignal send testPowerOnSignal to testSubject;
        action triggerBrewStartSignal send testBrewStartSignal to testSubject;
        action triggerGrindCompleteSignal send testGrindCompleteSignal to testSubject;
        action triggerTargetVolumeReached send testTargetVolumeReached to testSubject;
        action triggerResetSignal send testResetSignal to testSubject;
        first heatWaterProbe;
        then triggerPowerOnSignal;
        then triggerBrewStartSignal;
        then triggerGrindCompleteSignal;
        then triggerTargetVolumeReached;
        then triggerResetSignal;
    }
}
