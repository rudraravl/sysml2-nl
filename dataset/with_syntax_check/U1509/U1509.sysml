package 'Steam Turbine Power Generation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def SteamQuality :> Real;
	attribute def EfficiencyFactor :> Real;

	item def HighPressureSteam {
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute pressure :> ISQ::pressure;
		attribute massFlowRate :> ISQ::massFlowRate;
		attribute quality :> SteamQuality;
	}

	item def LowPressureSteam {
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute pressure :> ISQ::pressure;
		attribute massFlowRate :> ISQ::massFlowRate;
		attribute quality :> SteamQuality;
	}

	item def MechanicalRotation {
		attribute torque :> ISQ::torque;
		attribute angularVelocity :> ISQ::angularVelocity;
		attribute mechanicalPower :> ISQ::power;
	}

	item def ElectricalPower {
		attribute activePower :> ISQ::power;
		attribute voltage :> ISQ::voltage;
		attribute frequency :> ISQ::frequency;
		attribute current :> ISQ::electricCurrent;
	}

	item def Condensate {
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute pressure :> ISQ::pressure;
		attribute massFlowRate :> ISQ::massFlowRate;
	}

	port def SteamInletPort {
		in item steamFlow : HighPressureSteam;
	}

	port def SteamExhaustPort {
		out item steamFlow : LowPressureSteam;
	}

	port def ShaftPort {
		out item rotation : MechanicalRotation;
	}

	port def ElectricalOutputPort {
		out item power : ElectricalPower;
	}

	port def CondensatePort {
		out item condensate : Condensate;
	}

	part def SteamTurbine {
		attribute ratedPower :> ISQ::power;
		attribute ratedSpeed :> ISQ::angularVelocity;
		attribute thermalEfficiency :> EfficiencyFactor;
		attribute numberOfStages : Integer;

		port steamInlet : SteamInletPort;
		port steamExhaust : SteamExhaustPort;
		port shaftOutput : ShaftPort;

		part rotorAssembly {
			attribute mass :> ISQ::mass;
			attribute momentOfInertia :> ISQ::momentOfInertia;
			attribute currentSpeed :> ISQ::angularVelocity;
		}

		part statorCasing {
			attribute maxPressure :> ISQ::pressure;
			attribute maxTemperature :> ISQ::thermodynamicTemperature;
		}

		part bladeStages {
			attribute stageCount : Integer;
			attribute bladeEfficiency :> EfficiencyFactor;
		}

		part bearingSystem {
			attribute lubricationPressure :> ISQ::pressure;
			attribute bearingTemperature :> ISQ::thermodynamicTemperature;
		}

		part governorSystem {
			attribute speedSetpoint :> ISQ::angularVelocity;
			attribute controlGain : Real;
		}
	}

	part def SteamBoiler {
		attribute steamGenerationRate :> ISQ::massFlowRate;
		attribute heatInput :> ISQ::power;
		attribute boilerEfficiency :> EfficiencyFactor;

		port steamOutput : SteamExhaustPort;

		part combustionChamber {
			attribute flameTemperature :> ISQ::thermodynamicTemperature;
		}

		part waterDrum {
			attribute waterLevel :> ISQ::length;
			attribute drumPressure :> ISQ::pressure;
		}

		part superheater {
			attribute outletTemperature :> ISQ::thermodynamicTemperature;
			attribute outletPressure :> ISQ::pressure;
		}
	}

	part def ElectricalGenerator {
		attribute ratedPower :> ISQ::power;
		attribute outputVoltage :> ISQ::voltage;
		attribute outputFrequency :> ISQ::frequency;
		attribute generatorEfficiency :> EfficiencyFactor;

		port mechanicalInput : ShaftPort;
		port electricalOutput : ElectricalOutputPort;

		part statorWinding {
			attribute windingTemperature :> ISQ::thermodynamicTemperature;
			attribute insulationClass : String;
		}

		part rotorField {
			attribute excitationCurrent :> ISQ::electricCurrent;
			attribute fieldVoltage :> ISQ::voltage;
		}

		part coolingSystem {
			attribute coolantFlowRate :> ISQ::volumeFlowRate;
			attribute coolantTemperature :> ISQ::thermodynamicTemperature;
		}
	}

	part def SteamCondenser {
		attribute condensingPressure :> ISQ::pressure;
		attribute coolingWaterFlowRate :> ISQ::volumeFlowRate;
		attribute heatRejectionRate :> ISQ::power;

		port steamInlet : SteamInletPort;
		port condensateOutput : CondensatePort;

		part tubeBundle {
			attribute tubeCount : Integer;
			attribute heatTransferArea :> ISQ::area;
		}

		part hotwell {
			attribute condensateLevel :> ISQ::length;
			attribute hotwellTemperature :> ISQ::thermodynamicTemperature;
		}

		part vacuumSystem {
			attribute vacuumPressure :> ISQ::pressure;
		}
	}

	action def ExpandSteam {
		in highPressureSteam : HighPressureSteam;
		out mechanicalRotation : MechanicalRotation;
		out exhaustSteam : LowPressureSteam;

		attribute expansionRatio : Real;
		attribute isentropicEfficiency :> EfficiencyFactor;
	}

	action def GenerateElectricity {
		in mechanicalRotation : MechanicalRotation;
		out electricalPower : ElectricalPower;

		attribute conversionEfficiency :> EfficiencyFactor;
	}

	action def CondenseSteam {
		in exhaustSteam : LowPressureSteam;
		out condensate : Condensate;

		attribute heatRemovalRate :> ISQ::power;
	}

	action def ProduceSteam {
		out highPressureSteam : HighPressureSteam;

		attribute fuelConsumptionRate :> ISQ::massFlowRate;
	}

	attribute def StartupCommand;
	attribute def ShutdownCommand;

	action def OperateSteamTurbineSystem {
		in steamSupply : HighPressureSteam;
		out electricalOutput : ElectricalPower;

		first start;
		then action initializeSystem;
		then merge operationLoop;

		action expandSteamInTurbine : ExpandSteam {
			in highPressureSteam = steamSupply;
			out mechanicalRotation;
			out exhaustSteam;
		}

		flow expandSteamInTurbine.mechanicalRotation to convertToElectricity.mechanicalRotation;

		action convertToElectricity : GenerateElectricity {
			in mechanicalRotation;
			out electricalPower;
		}

		flow expandSteamInTurbine.exhaustSteam to condenseSteamFlow.exhaustSteam;

		action condenseSteamFlow : CondenseSteam {
			in exhaustSteam;
			out condensate;
		}

		then assign electricalOutput := convertToElectricity.electricalPower;
		then decide;
			if convertToElectricity.electricalPower.activePower > 0.0 [SI::W] then operationLoop;
			if convertToElectricity.electricalPower.activePower <= 0.0 [SI::W] then shutdownSequence;

		action shutdownSequence;
		then done;
	}

	part steamTurbinePowerPlant {
		attribute totalSystemEfficiency :> EfficiencyFactor;
		attribute netElectricalOutput :> ISQ::power;
		attribute plantCapacityFactor : Real;

		part boiler : SteamBoiler {
			attribute steamGenerationRate = 200.0 [SI::kg/SI::s];
			attribute heatInput = 600.0 [SI::MW];
			attribute boilerEfficiency = 0.88;
		}

		part turbine : SteamTurbine {
			attribute ratedPower = 250.0 [SI::MW];
			attribute ratedSpeed = 3000.0 [SI::rpm];
			attribute thermalEfficiency = 0.42;
			attribute numberOfStages = 12;
		}

		part generator : ElectricalGenerator {
			attribute ratedPower = 250.0 [SI::MW];
			attribute outputVoltage = 22.0 [SI::kV];
			attribute outputFrequency = 50.0 [SI::Hz];
			attribute generatorEfficiency = 0.98;
		}

		part condenser : SteamCondenser {
			attribute condensingPressure = 4.0 [SI::kPa];
			attribute coolingWaterFlowRate = 15000.0 [SI::m^3/SI::h];
			attribute heatRejectionRate = 350.0 [SI::MW];
		}

		connect boiler.steamOutput to turbine.steamInlet;
		connect turbine.steamExhaust to condenser.steamInlet;
		connect turbine.shaftOutput to generator.mechanicalInput;

		perform action operatePlant : OperateSteamTurbineSystem;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The steam turbine power generation system shall convert thermal energy from 
		       high-pressure superheated steam into electrical energy by expanding the steam 
		       through turbine stages to drive an electrical generator, exhausting low-pressure 
		       steam to a condenser for cycle completion. */

		subject system : steamTurbinePowerPlant;

		require constraint continuousPowerGeneration {
			system.netElectricalOutput > 0.0 [SI::W]
		}
	}

	requirement def TurbinePerformanceRequirement {
		doc /* The steam turbine shall achieve minimum thermal efficiency of 40% at rated 
		       operating conditions with inlet steam at specified temperature and pressure. */

		subject turbineUnit : SteamTurbine;

		require constraint efficiencyRequirement {
			turbineUnit.thermalEfficiency >= 0.40
		}

		require constraint powerOutputRequirement {
			turbineUnit.ratedPower >= 200.0 [SI::MW]
		}
	}

	requirement def SteamConditionsRequirement {
		doc /* The inlet steam shall be superheated with temperature exceeding 540°C and 
		       pressure exceeding 16 MPa to ensure efficient energy conversion and prevent 
		       turbine blade erosion. */

		subject inletSteam : HighPressureSteam;

		require constraint temperatureRequirement {
			inletSteam.temperature >= 813.15 [SI::K]
		}

		require constraint pressureRequirement {
			inletSteam.pressure >= 16.0 [SI::MPa]
		}

		require constraint steamQualityRequirement {
			inletSteam.quality >= 0.98
		}
	}

	requirement def GeneratorSynchronizationRequirement {
		doc /* The electrical generator shall synchronize with the grid at specified frequency 
		       and voltage within acceptable tolerances before load application. */

		subject generatorUnit : ElectricalGenerator;

		require constraint frequencyTolerance {
			generatorUnit.outputFrequency >= 49.5 [SI::Hz] and 
			generatorUnit.outputFrequency <= 50.5 [SI::Hz]
		}

		require constraint voltageTolerance {
			generatorUnit.outputVoltage >= 21.0 [SI::kV] and 
			generatorUnit.outputVoltage <= 23.0 [SI::kV]
		}
	}

	requirement systemMissionRequirement {
		doc /* The steam turbine power generation system shall reliably convert thermal energy 
		       from steam into electrical power through continuous thermodynamic expansion, 
		       mechanical rotation, and electromagnetic induction processes. */

		subject plant : steamTurbinePowerPlant;

		require primaryFunction : PrimaryFunctionRequirement {
			subject system = plant;
		}

		require turbinePerformance : TurbinePerformanceRequirement {
			subject turbineUnit = plant.turbine;
		}

		require steamConditions : SteamConditionsRequirement;

		require generatorSync : GeneratorSynchronizationRequirement {
			subject generatorUnit = plant.generator;
		}

		require constraint overallEfficiency {
			plant.totalSystemEfficiency >= 0.35
		}

		require constraint availabilityRequirement {
			plant.plantCapacityFactor >= 0.85
		}
	}
}
