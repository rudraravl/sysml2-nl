package ExternalCombustionEngineSystem {
    attribute def StartCommand;
    attribute def SteamPressureReached;
    attribute def StopCommand;
    attribute def EmergencyCondition;
    attribute def SystemDepressurized;

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SteamPressure :> PressureValue;
	attribute def SteamTemperature :> ThermodynamicTemperatureValue;
	attribute def WaterFlowRate :> VolumeFlowRateValue;
	attribute def FuelFlowRate :> MassFlowRateValue;
	attribute def HeatTransferRate :> PowerValue;
	
	item def Steam {
		attribute pressure : SteamPressure;
		attribute temperature : SteamTemperature;
		attribute flowRate : VolumeFlowRateValue;
		attribute enthalpy : EnergyValue;
	}
	
	item def Water {
		attribute flowRate : WaterFlowRate;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def Fuel {
		attribute flowRate : FuelFlowRate;
		attribute heatingValue : EnergyValue;
	}
	
	port def SteamPort {
		out item steam : Steam;
	}
	
	port def WaterPort {
		in item water : Water;
	}
	
	port def FuelPort {
		in item fuel : Fuel;
	}
	
	port def MechanicalPowerPort {
		out attribute torque : TorqueValue;
		out attribute rotationalSpeed : AngularVelocityValue;
		out attribute power : PowerValue;
	}
	
	part def Boiler {
		doc /* Converts water to high-pressure steam using external heat source */
		
		port waterIn : WaterPort;
		port fuelIn : FuelPort;
		port steamOut : SteamPort;
		
		attribute currentPressure : SteamPressure;
		attribute currentTemperature : SteamTemperature;
		attribute waterLevel : LengthValue;
		attribute heatTransferEfficiency : Real;
		
		perform action generateSteam {
			in fuelInput : Fuel = fuelIn.fuel;
			in waterInput : Water = waterIn.water;
			out steamOutput : Steam;
			
			first start;
			then action combustFuel {
				in fuel : Fuel = fuelInput;
				out thermalEnergy : EnergyValue;
			}
			then action transferHeat {
				in energy : EnergyValue = combustFuel.thermalEnergy;
				in water : Water = waterInput;
				out heatedWater : Water;
			}
			then action vaporize {
				in heatedWater : Water = transferHeat.heatedWater;
				out steam : Steam = steamOutput;
			}
			then done;
		}
	}
	
	part def SteamExpander {
		doc /* Converts high-pressure steam energy into mechanical rotation */
		
		port steamIn : SteamPort;
		port exhaustOut : SteamPort;
		port powerOut : MechanicalPowerPort;
		
		attribute pistonPosition : LengthValue;
		attribute cylinderVolume : VolumeValue;
		attribute expansionRatio : Real;
		
		perform action expandSteam {
			in steamInput : Steam = steamIn.steam;
			out mechanicalTorque : TorqueValue;
			out exhaustSteam : Steam;
			
			first start;
			then action admitSteam {
				in steam : Steam = steamInput;
				out admittedSteam : Steam;
			}
			then action performExpansion {
				in steam : Steam = admitSteam.admittedSteam;
				out linearForce : ForceValue;
				out exhaust : Steam = exhaustSteam;
			}
			then action convertToRotation {
				in force : ForceValue = performExpansion.linearForce;
				out torque : TorqueValue = mechanicalTorque;
			}
			then done;
		}
	}
	
	part def Condenser {
		doc /* Condenses exhaust steam back to water for recirculation */
		
		port steamIn : SteamPort;
		port waterOut : WaterPort;
		port coolingWaterIn : WaterPort;
		
		attribute coolingRate : PowerValue;
		attribute condensingPressure : PressureValue;
		attribute condensingTemperature : ThermodynamicTemperatureValue;
		
		perform action condenseSteam {
			in exhaustSteam : Steam = steamIn.steam;
			in coolingWater : Water = coolingWaterIn.water;
			out condensedWater : Water;
			
			first start;
			then action coolSteam {
				in steam : Steam = exhaustSteam;
				in coolant : Water = coolingWater;
				out cooledSteam : Steam;
			}
			then action condenseToWater {
				in steam : Steam = coolSteam.cooledSteam;
				out water : Water = condensedWater;
			}
			then done;
		}
	}
	
	part def FeedwaterPump {
		doc /* Pressurizes condensed water for return to boiler */
		
		port waterIn : WaterPort;
		port waterOut : WaterPort;
		
		attribute pumpPressure : PressureValue;
		attribute pumpSpeed : AngularVelocityValue;
		attribute pumpEfficiency : Real;
		
		perform action pumpWater {
			in waterInput : Water = waterIn.water;
			out pressurizedWater : Water;
			
			first start;
			then action increasePressure {
				in water : Water = waterInput;
				out highPressureWater : Water = pressurizedWater;
			}
			then done;
		}
	}
	
	part def ExternalCombustionEngine {
		doc /* Complete external combustion engine system converting thermal energy 
		     * from external fuel combustion into mechanical power via steam cycle */
		
		attribute totalPowerOutput : PowerValue;
		attribute thermalEfficiency : Real;
		attribute operatingPressure : SteamPressure;
		attribute operatingTemperature : SteamTemperature;
		
		part boiler : Boiler {
			attribute :>> heatTransferEfficiency = 0.85;
		}
		part expander : SteamExpander {
			attribute :>> expansionRatio = 8.0;
		}
		part condenser : Condenser {
			attribute :>> condensingPressure = 10000 [Pa];
			attribute :>> condensingTemperature = 320 [K];
		}
		part feedPump : FeedwaterPump {
			attribute :>> pumpEfficiency = 0.75;
		}
		
		port fuelInput : FuelPort;
		port coolingWaterInput : WaterPort;
		port powerOutput : MechanicalPowerPort;
		
		connection steamSupply connect boiler.steamOut to expander.steamIn;
		connection exhaustSteam connect expander.exhaustOut to condenser.steamIn;
		connection condensateReturn connect condenser.waterOut to feedPump.waterIn;
		connection feedwater connect feedPump.waterOut to boiler.waterIn;
		connection fuelSupply connect fuelInput to boiler.fuelIn;
		connection coolingSupply connect coolingWaterInput to condenser.coolingWaterIn;
		connection powerDelivery connect expander.powerOut to powerOutput;
		
		perform action operateEngine {
			in fuelSupply : Fuel = fuelInput.fuel;
			in coolingWater : Water = coolingWaterInput.water;
			out mechanicalPower : PowerValue;
			
			first start;
			then merge continuousOperation;
			then action monitorConditions {
				out steamPressure : SteamPressure;
				out steamTemp : SteamTemperature;
				out waterLevel : LengthValue;
			}
			then decide;
				if monitorConditions.steamPressure >= 1500000 [Pa] and 
				   monitorConditions.waterLevel >= 0.5 [m] then runCycle;
				if monitorConditions.steamPressure < 1500000 [Pa] or 
				   monitorConditions.waterLevel < 0.5 [m] then buildPressure;
			action buildPressure {
				action heatBoiler : Boiler::generateSteam;
			}
			then continuousOperation;
			action runCycle {
				action steamGeneration : Boiler::generateSteam;
				flow steamGeneration.steamOutput to powerProduction.steamInput;
				action powerProduction : SteamExpander::expandSteam;
				flow powerProduction.mechanicalTorque to mechanicalPower;
				flow powerProduction.exhaustSteam to steamCondensation.exhaustSteam;
				action steamCondensation : Condenser::condenseSteam;
				flow steamCondensation.condensedWater to waterPumping.waterInput;
				action waterPumping : FeedwaterPump::pumpWater;
			}
			then continuousOperation;
		}
	}
	
	event def StartCommand;
	event def StopCommand;
	event def SteamPressureReached;
	event def SystemDepressurized;
	event def EmergencyCondition;
	
	state def EngineStateMachine {
		doc /* State machine controlling engine operational modes */
		
		entry; then idle;
		
		state idle {
			doc /* Engine is not operating */
		}
		
		state startup {
			doc /* Building steam pressure for operation */
		}
		
		state operating {
			doc /* Engine running at steady state */
		}
		
		state shutdown {
			doc /* Controlled engine shutdown */
		}
		
		transition idle_to_startup
			first idle
			accept StartCommand
			then startup;
		
		transition startup_to_operating
			first startup
			accept SteamPressureReached
			then operating;
		
		transition operating_to_shutdown_normal
			first operating
			accept StopCommand
			then shutdown;
		
		transition operating_to_shutdown_emergency
			first operating
			accept EmergencyCondition
			then shutdown;
		
		transition shutdown_to_idle
			first shutdown
			accept SystemDepressurized
			then idle;
	}
	
	requirement def PowerGenerationRequirement {
		doc /* The external combustion engine shall convert thermal energy from 
		     * external fuel combustion into mechanical power through a closed 
		     * steam cycle with minimum specified efficiency */
		
		subject engine : ExternalCombustionEngine;
		
		require constraint {
			engine.totalPowerOutput >= 50000 [W]
		}
		
		require constraint {
			engine.thermalEfficiency >= 0.15 and engine.thermalEfficiency <= 0.40
		}
	}
	
	requirement def OperationalSafetyRequirement {
		doc /* The boiler operating pressure shall remain within safe limits 
		     * to prevent catastrophic failure */
		
		subject boiler : Boiler;
		
		require constraint {
			boiler.currentPressure <= 2500000 [Pa]
		}
		
		require constraint {
			boiler.waterLevel >= 0.3 [m]
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The engine shall maintain thermal efficiency within acceptable range */
		
		subject engine : ExternalCombustionEngine;
		
		require constraint {
			engine.boiler.heatTransferEfficiency >= 0.80
		}
		
		require constraint {
			engine.feedPump.pumpEfficiency >= 0.70
		}
	}
	
	part externalCombustionEngineSystem : ExternalCombustionEngine {
		attribute :>> totalPowerOutput : PowerValue;
		attribute :>> thermalEfficiency : Real;
		attribute :>> operatingPressure = 2000000 [Pa];
		attribute :>> operatingTemperature = 550 [K];
		
		satisfy powerReq : PowerGenerationRequirement {
			subject engine = externalCombustionEngineSystem;
		}
		
		satisfy safetyReq : OperationalSafetyRequirement {
			subject boiler = externalCombustionEngineSystem.boiler;
		}
		
		satisfy efficiencyReq : EfficiencyRequirement {
			subject engine = externalCombustionEngineSystem;
		}
		
		exhibit state engineStateMachine : EngineStateMachine;
	}
	
	action def OperateExternalCombustionEngine {
		doc /* High-level action representing complete engine operation cycle */
		
		in fuelInput : Fuel;
		in coolingWater : Water;
		out powerOutput : PowerValue;
	}
	
	action operateSystem : OperateExternalCombustionEngine {
		in fuelInput : Fuel;
		in coolingWater : Water;
		out powerOutput : PowerValue;
		
		first start;
		then action initializeSystem {
			out initialPressure : SteamPressure;
			out initialTemperature : SteamTemperature;
		}
		then action runEngine : ExternalCombustionEngine::operateEngine {
			in fuelSupply = operateSystem.fuelInput;
			in coolingWater = operateSystem.coolingWater;
			out mechanicalPower = operateSystem.powerOutput;
		}
		then done;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ExternalCombustionEngineSystem::*;

    part externalCombustionEngineSystem : Boiler {
        exhibit state sm : EngineStateMachine;
    }

    action orchestrator {
        item testFuelInput : Fuel {
            attribute flowRate : FuelFlowRate;
            attribute heatingValue : EnergyValue;
        }
        item testCoolingWater : Water {
            attribute flowRate : WaterFlowRate;
            attribute temperature : ThermodynamicTemperatureValue;
            attribute pressure : PressureValue;
        }
        action operateSystemProbe : OperateExternalCombustionEngine {
            in fuelInput = testFuelInput;
            in coolingWater = testCoolingWater;
        }
        attribute testStartCommand : StartCommand;
        attribute testSteamPressureReached : SteamPressureReached;
        attribute testStopCommand : StopCommand;
        attribute testSystemDepressurized : SystemDepressurized;
        action triggerStartCommand send testStartCommand to externalCombustionEngineSystem;
        action triggerSteamPressureReached send testSteamPressureReached to externalCombustionEngineSystem;
        action triggerStopCommand send testStopCommand to externalCombustionEngineSystem;
        action triggerSystemDepressurized send testSystemDepressurized to externalCombustionEngineSystem;
        first operateSystemProbe;
        then triggerStartCommand;
        then triggerSteamPressureReached;
        then triggerStopCommand;
        then triggerSystemDepressurized;
    }
}
