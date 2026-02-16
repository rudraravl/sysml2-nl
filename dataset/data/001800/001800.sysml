package JetEngineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def AirMassFlowRate :> MassFlowRateValue;
	attribute def FuelMassFlowRate :> MassFlowRateValue;
	attribute def ThrustForce :> ForceValue;
	attribute def RotationalSpeed :> AngularVelocityValue;
	attribute def EngineTemperature :> ThermodynamicTemperatureValue;
	attribute def EnginePressure :> PressureValue;
	attribute def CompressionRatio :> Real;
	attribute def EfficiencyRatio :> Real;
	
	item def AirFlow {
		attribute massFlowRate : AirMassFlowRate;
		attribute temperature : EngineTemperature;
		attribute pressure : EnginePressure;
	}
	
	item def FuelFlow {
		attribute massFlowRate : FuelMassFlowRate;
		attribute temperature : EngineTemperature;
	}
	
	item def ExhaustGas {
		attribute massFlowRate : MassFlowRateValue;
		attribute temperature : EngineTemperature;
		attribute pressure : EnginePressure;
		attribute velocity : SpeedValue;
	}
	
	item def MechanicalPower {
		attribute torque : TorqueValue;
		attribute rotationalSpeed : RotationalSpeed;
	}
	
	attribute def StartCommand;
	attribute def ShutdownCommand;
	attribute def ThrottleCommand {
		attribute position : Real;
	}
	
	port def AirIntakePort {
		in item airIn : AirFlow;
	}
	
	port def FuelSupplyPort {
		in item fuelIn : FuelFlow;
	}
	
	port def ExhaustPort {
		out item exhaustOut : ExhaustGas;
	}
	
	port def PowerPort {
		out item powerOut : MechanicalPower;
	}
	
	part def AirIntake {
		port ambientAirIn : AirIntakePort;
		port filteredAirOut {
			out item airOut : AirFlow;
		}
		attribute intakeEfficiency : EfficiencyRatio = 0.98;
	}
	
	part def Compressor {
		port airIn {
			in item airInFlow : AirFlow;
		}
		port compressedAirOut {
			out item compressedAir : AirFlow;
		}
		port powerIn : PowerPort {
			in item redefines powerOut;
		}
		attribute compressionRatio : CompressionRatio = 15.0;
		attribute efficiency : EfficiencyRatio = 0.87;
		attribute stages : Integer = 8;
	}
	
	part def CombustionChamber {
		port compressedAirIn {
			in item airIn : AirFlow;
		}
		port fuelIn : FuelSupplyPort;
		port hotGasOut {
			out item hotGas : ExhaustGas;
		}
		attribute combustionEfficiency : EfficiencyRatio = 0.995;
		attribute maxTemperature : EngineTemperature = 1800 [K];
		attribute fuelAirRatio : Real = 0.028;
	}
	
	part def Turbine {
		port hotGasIn {
			in item gasIn : ExhaustGas;
		}
		port exhaustGasOut {
			out item gasOut : ExhaustGas;
		}
		port powerOut : PowerPort;
		attribute expansionRatio : Real = 4.5;
		attribute efficiency : EfficiencyRatio = 0.89;
		attribute stages : Integer = 3;
	}
	
	part def ExhaustNozzle {
		port exhaustIn {
			in item gasIn : ExhaustGas;
		}
		port exhaustOut : ExhaustPort;
		attribute nozzleArea : AreaValue = 0.45 [m^2];
		attribute expansionRatio : Real = 1.8;
		attribute efficiency : EfficiencyRatio = 0.96;
	}
	
	part def Shaft {
		port turbineConnection : PowerPort {
			in item redefines powerOut;
		}
		port compressorConnection : PowerPort;
		attribute rotationalSpeed : RotationalSpeed;
		attribute torque : TorqueValue;
		attribute inertia : Real = 12.5;
	}
	
	part def FuelSystem {
		port fuelOut : FuelSupplyPort;
		attribute fuelFlowRate : FuelMassFlowRate;
		attribute fuelPressure : EnginePressure = 4500000 [Pa];
		attribute tankCapacity : VolumeValue = 8000 [L];
		attribute currentFuelLevel : VolumeValue;
	}
	
	part def ControlSystem {
		port throttleIn {
			in item throttleCmd : ThrottleCommand;
		}
		port startIn {
			in item startCmd : StartCommand;
		}
		port shutdownIn {
			in item shutdownCmd : ShutdownCommand;
		}
		port fuelControl {
			out item fuelCmd : FuelMassFlowRate;
		}
		attribute targetRPM : RotationalSpeed;
		attribute currentRPM : RotationalSpeed;
	}
	
	part def JetEngine {
		port airIntakePort : AirIntakePort;
		port fuelInputPort : FuelSupplyPort;
		port exhaustOutputPort : ExhaustPort;
		
		attribute thrustOutput : ThrustForce;
		attribute specificFuelConsumption : Real;
		attribute overallEfficiency : EfficiencyRatio = 0.42;
		attribute dryMass : MassValue = 1850 [kg];
		
		part airIntake : AirIntake;
		part compressor : Compressor;
		part combustionChamber : CombustionChamber;
		part turbine : Turbine;
		part exhaustNozzle : ExhaustNozzle;
		part shaft : Shaft;
		part fuelSystem : FuelSystem;
		part controlSystem : ControlSystem;
		
		connect airIntakePort to airIntake.ambientAirIn;
		connect airIntake.filteredAirOut to compressor.airIn;
		connect compressor.compressedAirOut to combustionChamber.compressedAirIn;
		connect fuelInputPort to fuelSystem.fuelOut;
		connect fuelSystem.fuelOut to combustionChamber.fuelIn;
		connect combustionChamber.hotGasOut to turbine.hotGasIn;
		connect turbine.exhaustGasOut to exhaustNozzle.exhaustIn;
		connect exhaustNozzle.exhaustOut to exhaustOutputPort;
		connect turbine.powerOut to shaft.turbineConnection;
		connect shaft.compressorConnection to compressor.powerIn;
	}
	
	action def IngestAir {
		in ambientAir : AirFlow;
		out ingestedAir : AirFlow;
	}
	
	action def CompressAir {
		in airIn : AirFlow;
		in mechanicalPower : MechanicalPower;
		out compressedAir : AirFlow;
	}
	
	action def InjectFuel {
		in throttlePosition : Real;
		out fuelFlow : FuelFlow;
	}
	
	action def CombustMixture {
		in compressedAir : AirFlow;
		in fuel : FuelFlow;
		out hotGas : ExhaustGas;
	}
	
	action def ExtractPower {
		in hotGas : ExhaustGas;
		out exhaustGas : ExhaustGas;
		out mechanicalPower : MechanicalPower;
	}
	
	action def AccelerateExhaust {
		in exhaustGas : ExhaustGas;
		out highVelocityExhaust : ExhaustGas;
		out thrust : ThrustForce;
	}
	
	action def TransferPower {
		in turbinePower : MechanicalPower;
		out compressorPower : MechanicalPower;
	}
	
	action def GenerateThrust {
		in throttleCmd : ThrottleCommand;
		in ambientAir : AirFlow;
		in fuelSupply : FuelFlow;
		out thrust : ThrustForce;
		
		first start;
		then merge continuousOperation;
		
		then action ingestAir : IngestAir {
			in ambientAir = ambientAir;
			out ingestedAir : AirFlow;
		}
		
		flow ingestAir.ingestedAir to compressAir.airIn;
		
		then action compressAir : CompressAir {
			in airIn : AirFlow;
			in mechanicalPower : MechanicalPower;
			out compressedAir : AirFlow;
		}
		
		flow compressAir.compressedAir to combustMixture.compressedAir;
		
		then action injectFuel : InjectFuel {
			in throttlePosition = throttleCmd.position;
			out fuelFlow : FuelFlow;
		}
		
		flow injectFuel.fuelFlow to combustMixture.fuel;
		
		then action combustMixture : CombustMixture {
			in compressedAir : AirFlow;
			in fuel : FuelFlow;
			out hotGas : ExhaustGas;
		}
		
		flow combustMixture.hotGas to extractPower.hotGas;
		
		then action extractPower : ExtractPower {
			in hotGas : ExhaustGas;
			out exhaustGas : ExhaustGas;
			out mechanicalPower : MechanicalPower;
		}
		
		flow extractPower.mechanicalPower to transferPower.turbinePower;
		
		then action transferPower : TransferPower {
			in turbinePower : MechanicalPower;
			out compressorPower : MechanicalPower;
		}
		
		flow transferPower.compressorPower to compressAir.mechanicalPower;
		flow extractPower.exhaustGas to accelerateExhaust.exhaustGas;
		
		then action accelerateExhaust : AccelerateExhaust {
			in exhaustGas : ExhaustGas;
			out highVelocityExhaust : ExhaustGas;
			out thrust : ThrustForce;
		}
		
		flow accelerateExhaust.thrust to thrust;
		
		then continuousOperation;
	}
	
	state def EngineOperationalStates {
		entry; then off;
		
		state off;
		transition off_to_starting
			first off
			accept startCmd : StartCommand
			then starting;
		
		state starting {
			entry; then ignition;
			state ignition;
			transition ignition_to_spooling
				first ignition
				then spooling;
			state spooling;
			transition spooling_to_idle
				first spooling
				then idle;
			state idle;
		}
		transition starting_to_running
			first starting
			then running;
		
		state running {
			entry; then operatingLoop;
			state operatingLoop;
			do action generateThrust : GenerateThrust;
		}
		
		transition running_to_shutdown
			first running
			accept shutdownCmd : ShutdownCommand
			then shutdown;
		
		state shutdown;
		transition shutdown_to_off
			first shutdown
			then off;
	}
	
	part turbofanEngine : JetEngine {
		exhibit state engineStates : EngineOperationalStates;
		
		attribute :>> thrustOutput = 125000 [N];
		attribute :>> specificFuelConsumption = 0.48;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The jet engine system shall convert chemical energy from fuel into kinetic energy 
		       to produce thrust for aircraft propulsion by ingesting ambient air, compressing it, 
		       mixing it with fuel, combusting the mixture, expanding the hot gases through a turbine 
		       to drive the compressor, and accelerating the exhaust gases through a nozzle to generate 
		       forward thrust. */
	}
	
	requirement def ThrustRequirement {
		doc /* The jet engine shall generate minimum thrust to propel the aircraft. */
		
		attribute minThrust : ThrustForce = 100000 [N];
		
		require constraint {
			turbofanEngine.thrustOutput >= minThrust
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The jet engine shall maintain specific fuel consumption within acceptable limits. */
		
		attribute maxSFC : Real = 0.55;
		
		require constraint {
			turbofanEngine.specificFuelConsumption <= maxSFC
		}
	}
	
	requirement def OperationalRequirement {
		doc /* The jet engine shall operate continuously and reliably under varying throttle conditions. */
		
		assume constraint ambientConditions {
			turbofanEngine.airIntakePort.airIn.temperature >= 220 [K] and
			turbofanEngine.airIntakePort.airIn.temperature <= 320 [K] and
			turbofanEngine.airIntakePort.airIn.pressure >= 20000 [Pa] and
			turbofanEngine.airIntakePort.airIn.pressure <= 105000 [Pa]
		}
		
		require thrustReq : ThrustRequirement;
		require efficiencyReq : EfficiencyRequirement;
	}
	
	requirement <'JE-001'> jetEnginePrimaryFunction : PrimaryFunctionRequirement {
		require operationalReq : OperationalRequirement;
	}
}
