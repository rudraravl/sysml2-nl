package RootsSuperchargerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotationalSpeed :> Real;
	attribute def VolumetricFlowRate :> Real;
	attribute def Pressure :> Real;
	attribute def Temperature :> Real;
	attribute def Torque :> Real;
	attribute def Efficiency :> Real;
	
	item def AirCharge {
		attribute pressure : Pressure;
		attribute temperature : Temperature;
		attribute massFlowRate : Real;
	}
	
	item def MechanicalDrive {
		attribute torque : Torque;
		attribute speed : RotationalSpeed;
	}
	
	port def AirInletPort {
		in item ambientAir : AirCharge;
	}
	
	port def AirOutletPort {
		out item boostedAir : AirCharge;
	}
	
	port def MechanicalDrivePort {
		in item drivePower : MechanicalDrive;
	}
	
	part def RotorLobe {
		attribute lobeCount : Integer;
		attribute helixAngle : Real;
		attribute length : LengthValue;
		attribute diameter : LengthValue;
	}
	
	part def RotorPair {
		part maleRotor : RotorLobe {
			attribute :>> lobeCount = 3;
		}
		part femaleRotor : RotorLobe {
			attribute :>> lobeCount = 2;
		}
		attribute timingGearRatio : Real = 1.5;
		attribute rotorClearance : LengthValue;
	}
	
	part def SuperchargerCasing {
		attribute inletDiameter : LengthValue;
		attribute outletDiameter : LengthValue;
		attribute housingClearance : LengthValue;
		attribute materialType : String;
	}
	
	part def BeltDriveSystem {
		attribute pulleyRatio : Real;
		attribute beltWidth : LengthValue;
		attribute tensionForce : ForceValue;
	}
	
	part def IntercoolerUnit {
		attribute coolingEfficiency : Efficiency;
		attribute heatRejectionCapacity : PowerValue;
		attribute pressureDrop : Pressure;
	}
	
	part def BypassValve {
		attribute openingPressure : Pressure;
		attribute flowCapacity : VolumetricFlowRate;
	}
	
	part def RootsSupercharger {
		attribute displacementPerRevolution : VolumeValue;
		attribute maxRotorSpeed : RotationalSpeed;
		attribute targetBoostPressure : Pressure;
		attribute volumetricEfficiency : Efficiency;
		attribute currentRotorSpeed : RotationalSpeed;
		attribute currentBoostPressure : Pressure;
		
		port airInlet : AirInletPort;
		port airOutlet : AirOutletPort;
		port driveshaft : MechanicalDrivePort;
		
		part rotors : RotorPair {
			attribute :>> timingGearRatio = 1.5;
			attribute :>> rotorClearance = 0.0001;
		}
		
		part casing : SuperchargerCasing {
			attribute :>> materialType = "Aluminum";
		}
		
		part beltDrive : BeltDriveSystem {
			attribute :>> pulleyRatio = 2.8;
		}
		
		part intercooler : IntercoolerUnit {
			attribute :>> coolingEfficiency = 0.70;
		}
		
		part bypassValve : BypassValve {
			attribute :>> openingPressure = 180.0;
		}
	}
	
	part def InternalCombustionEngine {
		attribute displacement : VolumeValue;
		attribute maxRPM : RotationalSpeed;
		attribute compressionRatio : Real;
		attribute currentEngineSpeed : RotationalSpeed;
		
		port crankshaftOutput : MechanicalDrivePort;
		port intakeManifold : AirInletPort;
	}
	
	part def AmbientAtmosphere {
		attribute atmosphericPressure : Pressure;
		attribute ambientTemperature : Temperature;
		attribute humidity : Real;
		
		port airSource : AirOutletPort;
	}
	
	action def IngestAmbientAir {
		in atmosphericConditions : AirCharge;
		out ingestedAir : AirCharge;
		
		first start;
		then action filterAir {
			doc /* Remove particulates from ambient air. */
		}
		then action measureInletConditions {
			doc /* Measure pressure and temperature at inlet. */
		}
		then done;
	}
	
	action def TrapAirPockets {
		in incomingAir : AirCharge;
		in rotorPosition : Real;
		out trappedAir : AirCharge;
		
		first start;
		then action formPocket {
			doc /* Air pocket forms between rotor lobes and casing wall. */
		}
		then action sealPocket {
			doc /* Rotor rotation seals the air pocket from inlet. */
		}
		then done;
	}
	
	action def DisplaceAirVolume {
		in trappedAir : AirCharge;
		in rotorSpeed : RotationalSpeed;
		in displacement : VolumeValue;
		out displacedAir : AirCharge;
		
		first start;
		then action rotateRotors {
			doc /* Counter-rotating rotors move trapped air pockets. */
		}
		then action maintainSeal {
			doc /* Minimal clearance prevents air from escaping back to inlet. */
		}
		then action transportToOutlet {
			doc /* Air pockets travel along rotor length to outlet. */
		}
		then done;
	}
	
	action def CompressAirCharge {
		in displacedAir : AirCharge;
		in outletRestriction : Pressure;
		out compressedAir : AirCharge;
		
		first start;
		then action encounterBackPressure {
			doc /* Air encounters higher pressure at outlet from engine intake. */
		}
		then action externalCompression {
			doc /* Compression occurs externally as air is forced into manifold. */
		}
		then action elevateTemperature {
			doc /* Compression increases air temperature. */
		}
		then done;
	}
	
	action def CoolBoostedAir {
		in hotCompressedAir : AirCharge;
		in coolingEfficiency : Efficiency;
		out cooledAir : AirCharge;
		
		first start;
		then action transferHeat {
			doc /* Heat exchanger removes thermal energy from compressed air. */
		}
		then action increaseDensity {
			doc /* Cooler air has higher density for improved combustion. */
		}
		then done;
	}
	
	action def DeliverToEngine {
		in boostedAir : AirCharge;
		out deliveredAir : AirCharge;
		
		first start;
		then action regulatePressure {
			doc /* Bypass valve opens if boost exceeds target pressure. */
		}
		then action supplyIntake {
			doc /* Boosted air flows into engine intake manifold. */
		}
		then done;
	}
	
	action def PositiveDisplacementSupercharging {
		first start;
		then action ingestAir : IngestAmbientAir;
		then action trapAir : TrapAirPockets {
			in incomingAir = ingestAir.ingestedAir;
		}
		then action displaceAir : DisplaceAirVolume {
			in trappedAir = trapAir.trappedAir;
		}
		then action compressAir : CompressAirCharge {
			in displacedAir = displaceAir.displacedAir;
		}
		then action coolAir : CoolBoostedAir {
			in hotCompressedAir = compressAir.compressedAir;
		}
		then action deliverAir : DeliverToEngine {
			in boostedAir = coolAir.cooledAir;
		}
		then done;
	}
	
	state def SuperchargerOperatingModes {
		entry; then idle;
		
		state idle;
		
		transition idle_to_spooling
			first idle
			accept when engineSpeed > 0.0
			then spooling;
		
		state spooling;
		
		transition spooling_to_boosting
			first spooling
			accept when rotorSpeed >= operatingSpeed
			then boosting;
		
		state boosting;
		
		transition boosting_to_bypass
			first boosting
			accept when boostPressure > maxBoostPressure
			then bypass;
		
		state bypass;
		
		transition bypass_to_boosting
			first bypass
			accept when boostPressure <= targetBoostPressure
			then boosting;
		
		transition boosting_to_spooling
			first boosting
			accept when rotorSpeed < operatingSpeed
			then spooling;
		
		transition spooling_to_idle
			first spooling
			accept when engineSpeed == 0.0
			then idle;
	}
	
	part superchargedEngineSystem {
		part atmosphere : AmbientAtmosphere {
			attribute :>> atmosphericPressure = 101.325;
			attribute :>> ambientTemperature = 298.15;
			attribute :>> humidity = 0.50;
		}
		
		part supercharger : RootsSupercharger {
			attribute :>> displacementPerRevolution = 2.3;
			attribute :>> maxRotorSpeed = 14000.0;
			attribute :>> targetBoostPressure = 150.0;
			attribute :>> volumetricEfficiency = 0.85;
			
			perform action supercharge[*] ordered references PositiveDisplacementSupercharging;
			
			exhibit state operatingMode references SuperchargerOperatingModes;
		}
		
		part engine : InternalCombustionEngine {
			attribute :>> displacement = 5.0;
			attribute :>> maxRPM = 6500.0;
			attribute :>> compressionRatio = 9.0;
		}
		
		connect atmosphere.airSource to supercharger.airInlet;
		connect supercharger.airOutlet to engine.intakeManifold;
		connect engine.crankshaftOutput to supercharger.driveshaft;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The Roots-type supercharger shall provide continuous positive 
		       displacement compression of intake air to increase engine power output. */
		
		subject superchargerSubject : RootsSupercharger;
		
		require constraint boostPressureRange {
			superchargerSubject.targetBoostPressure >= 100.0 and 
			superchargerSubject.targetBoostPressure <= 200.0
		}
		
		require constraint rotorSpeedLimit {
			superchargerSubject.maxRotorSpeed <= 15000.0
		}
		
		require constraint volumetricEfficiencyMinimum {
			superchargerSubject.volumetricEfficiency >= 0.75
		}
	}
	
	requirement def MechanicalDriveRequirement {
		doc /* The supercharger shall be mechanically driven by the engine crankshaft 
		       via belt drive, providing immediate boost response proportional to engine speed. */
		
		assume constraint beltDriveConnection {
			doc /* Belt drive system maintains positive connection between crankshaft and supercharger. */
		}
		
		require constraint continuousOperation {
			doc /* Supercharger operates whenever engine is running. */
		}
	}
	
	requirement def PositiveDisplacementRequirement {
		doc /* The supercharger shall use counter-rotating meshing lobes to trap and 
		       displace discrete air pockets from inlet to outlet, achieving compression 
		       through external restriction rather than internal compression. */
		
		require constraint meshingRotorOperation {
			doc /* Male and female rotors must maintain precise timing and clearance. */
		}
		
		require constraint airPocketSealing {
			doc /* Minimal clearance between rotors and casing prevents backflow. */
		}
	}
	
	requirement def ThermalManagementRequirement {
		doc /* The system shall include intercooling to reduce charge air temperature 
		       and increase air density for improved combustion efficiency. */
		
		subject intercoolerSubject : IntercoolerUnit;
		
		require constraint coolingEfficiency {
			intercoolerSubject.coolingEfficiency >= 0.60
		}
	}
	
	requirement def PressureRegulationRequirement {
		doc /* The system shall include bypass valve to prevent excessive boost pressure 
		       that could damage the engine. */
		
		subject bypassSubject : BypassValve;
		
		require constraint bypassActivation {
			doc /* Bypass valve opens when boost exceeds safe threshold. */
		}
	}
	
	requirement <'SCS-001'> rootsSuperchargerPrimaryFunction : PrimaryFunctionRequirement {
		doc /* The Roots-type supercharger system shall continuously compress ambient air 
		       through positive displacement using counter-rotating meshing lobes, delivering 
		       pressurized air charge to the engine intake manifold to increase volumetric 
		       efficiency and power output. The system operates mechanically driven by the 
		       engine crankshaft, providing immediate boost response proportional to engine 
		       speed without lag. */
		
		subject primarySupercharger = superchargedEngineSystem.supercharger;
		
		assume mechanicalDriveAssumption : MechanicalDriveRequirement;
		
		require positiveDisplacementOperation : PositiveDisplacementRequirement;
		require thermalManagement : ThermalManagementRequirement;
		require pressureRegulation : PressureRegulationRequirement;
	}
	
	requirement systemIntegrationRequirement {
		doc /* The complete supercharger system shall integrate all subsystems to provide 
		       reliable forced induction for the internal combustion engine. */
		
		require rootsSuperchargerPrimaryFunction;
	}
}
