package 'DrillingMudCirculationSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MudDensity :> ISQ::massPerVolumeValue;
	attribute def MudViscosity :> ISQ::dynamicViscosityValue;
	attribute def MudFlowRate :> ISQ::volumeFlowRateValue;
	attribute def PressureValue :> ISQ::pressureValue;
	attribute def TemperatureValue :> ISQ::thermodynamicTemperatureValue;
	attribute def SolidsFraction :> Real;
	attribute def DepthValue :> ISQ::lengthValue;
	
	item def DrillingMud {
		attribute density : MudDensity;
		attribute viscosity : MudViscosity;
		attribute temperature : TemperatureValue;
		attribute solidsContent : SolidsFraction;
		attribute phLevel : Real;
		attribute gelStrength : Real;
	}
	
	item def RockCuttings {
		attribute particleSize : ISQ::lengthValue;
		attribute totalMass : ISQ::massValue;
		attribute composition : String;
	}
	
	item def ContaminatedMud :> DrillingMud {
		part cuttings : RockCuttings;
	}
	
	port def MudInletPort {
		in item mud : DrillingMud;
	}
	
	port def MudOutletPort {
		out item mud : DrillingMud;
	}
	
	port def CuttingsDischargePort {
		out item cuttings : RockCuttings;
	}
	
	part def MudPump {
		port inlet : MudInletPort;
		port outlet : MudOutletPort;
		attribute flowRate : MudFlowRate;
		attribute dischargePressure : PressureValue;
		attribute powerRating : ISQ::powerValue;
		
		perform action pumpMud {
			in mudInput : DrillingMud;
			out mudOutput : DrillingMud;
			out pressure : PressureValue;
		}
	}
	
	part def DrillString {
		port inlet : MudInletPort;
		port outlet : MudOutletPort;
		attribute totalLength : DepthValue;
		attribute innerDiameter : ISQ::lengthValue;
		attribute outerDiameter : ISQ::lengthValue;
		
		perform action conveyMud {
			in mudInput : DrillingMud;
			out mudOutput : DrillingMud;
		}
	}
	
	part def DrillBit {
		port inlet : MudInletPort;
		port outlet : MudOutletPort;
		port cuttingsGenerated : CuttingsDischargePort;
		attribute bitDiameter : ISQ::lengthValue;
		attribute rotationSpeed : ISQ::angularVelocityValue;
		attribute weightOnBit : ISQ::forceValue;
		
		perform action coolAndLubricateBit {
			in mudInput : DrillingMud;
			out mudOutput : DrillingMud;
			out cuttings : RockCuttings;
		}
	}
	
	part def Annulus {
		port bottomInlet : MudInletPort;
		port surfaceOutlet : MudOutletPort;
		port cuttingsInlet : CuttingsDischargePort;
		attribute outerDiameter : ISQ::lengthValue;
		attribute innerDiameter : ISQ::lengthValue;
		attribute effectiveLength : DepthValue;
		
		perform action transportCuttingsUpward {
			in mudInput : DrillingMud;
			in cuttingsInput : RockCuttings;
			out contaminatedMudOutput : ContaminatedMud;
		}
	}
	
	part def ShakerScreen {
		port inlet : MudInletPort;
		port cleanMudOutlet : MudOutletPort;
		port cuttingsDischarge : CuttingsDischargePort;
		attribute meshSize : ISQ::lengthValue;
		attribute screenArea : ISQ::areaValue;
		attribute separationEfficiency : SolidsFraction;
		
		perform action separateCuttings {
			in contaminatedMudInput : ContaminatedMud;
			out cleanMudOutput : DrillingMud;
			out separatedCuttings : RockCuttings;
		}
	}
	
	part def MudPit {
		port inlet : MudInletPort;
		port outlet : MudOutletPort;
		attribute capacity : ISQ::volumeValue;
		attribute currentLevel : ISQ::lengthValue;
		attribute mudInventory : ISQ::volumeValue;
		
		perform action storeMud {
			in mudInput : DrillingMud;
			out mudOutput : DrillingMud;
		}
	}
	
	part def MudConditioner {
		port inlet : MudInletPort;
		port outlet : MudOutletPort;
		attribute targetDensity : MudDensity;
		attribute targetViscosity : MudViscosity;
		attribute targetPH : Real;
		
		perform action conditionMud {
			in mudInput : DrillingMud;
			out conditionedMud : DrillingMud;
		}
	}
	
	part def MudSensor {
		attribute measuredDensity : MudDensity;
		attribute measuredViscosity : MudViscosity;
		attribute measuredTemperature : TemperatureValue;
		attribute measuredPH : Real;
		
		perform action monitorMudProperties {
			in mud : DrillingMud;
			out densityReading : MudDensity;
			out viscosityReading : MudViscosity;
			out temperatureReading : TemperatureValue;
			out phReading : Real;
		}
	}
	
	action def CirculateMudContinuously {
		in attribute systemOperating : Boolean;
		in attribute systemShutdown : Boolean;
		
		first start;
		then merge circulationLoop;
		then action pumpFromPit;
		then action flowDownDrillString;
		then action coolAndCleanBit;
		then action liftCuttingsInAnnulus;
		then action separateSolidsAtSurface;
		then action conditionAndStoreMud;
		then decide;
			if systemOperating then circulationLoop;
			if systemShutdown then done;
	}
	
	action def MonitorAndAdjustMudProperties {
		in currentMud : DrillingMud;
		in targetDensity : MudDensity;
		in targetViscosity : MudViscosity;
		in attribute propertiesOutOfSpec : Boolean;
		in attribute propertiesInSpec : Boolean;
		out adjustedMud : DrillingMud;
		
		first start;
		then action measureProperties;
		then decide;
			if propertiesOutOfSpec then adjustProperties;
			if propertiesInSpec then done;
		action adjustProperties;
		then done;
	}
	
	item def StartCirculationCommand;
	item def StopCirculationCommand;
	
	state def MudCirculationStates {
		in attribute mudFlowEstablished : Boolean;
		in attribute mudPropertiesOutOfSpec : Boolean;
		in attribute mudPropertiesInSpec : Boolean;
		in attribute pumpsFullyStopped : Boolean;
		
		entry; then idle;
		
		state idle {
			doc /* System is not circulating mud. */
		}
		
		transition idle_to_startup
			first idle
			accept StartCirculationCommand
			then startup;
		
		state startup {
			doc /* System is initiating mud circulation. */
			entry; then action initializePumps;
		}
		
		transition startup_to_normalCirculation
			first startup
			if mudFlowEstablished
			then normalCirculation;
		
		state normalCirculation {
			doc /* System is circulating mud at normal operating parameters. */
			entry; then action maintainCirculation;
			
			state monitoring {
				doc /* Continuously monitoring mud properties. */
			}
			
			state adjusting {
				doc /* Adjusting mud properties to maintain specifications. */
			}
			
			transition monitoring_to_adjusting
				first monitoring
				if mudPropertiesOutOfSpec
				then adjusting;
			
			transition adjusting_to_monitoring
				first adjusting
				if mudPropertiesInSpec
				then monitoring;
		}
		
		transition normalCirculation_to_shutdown
			first normalCirculation
			accept StopCirculationCommand
			then shutdown;
		
		state shutdown {
			doc /* System is terminating mud circulation. */
			entry; then action stopPumps;
		}
		
		transition shutdown_to_idle
			first shutdown
			if pumpsFullyStopped
			then idle;
	}
	
	requirement def WellboreStabilityRequirement {
		doc /* The drilling mud system shall maintain wellbore stability by providing 
		       sufficient hydrostatic pressure to prevent formation collapse and fluid influx. */
		
		attribute minHydrostaticPressure : PressureValue;
		attribute maxHydrostaticPressure : PressureValue;
		
		require constraint {
			doc /* Hydrostatic pressure must be within safe operating window. */
		}
	}
	
	requirement def CuttingsRemovalRequirement {
		doc /* The system shall remove at least 95% of drill cuttings from the circulating mud 
		       to prevent accumulation in the wellbore. */
		
		attribute minRemovalEfficiency : SolidsFraction;
		
		require constraint {
			minRemovalEfficiency >= 0.95
		}
	}
	
	requirement def BitCoolingRequirement {
		doc /* The system shall maintain drill bit temperature below maximum operating temperature 
		       to prevent bit damage and ensure optimal drilling performance. */
		
		attribute maxBitTemperature : TemperatureValue;
		
		require constraint {
			doc /* Bit temperature must remain below maximum threshold. */
		}
	}
	
	requirement def MudPropertyControlRequirement {
		doc /* The system shall maintain mud density and viscosity within specified ranges 
		       to ensure proper wellbore pressure control and cuttings transport. */
		
		attribute minDensity : MudDensity;
		attribute maxDensity : MudDensity;
		attribute minViscosity : MudViscosity;
		attribute maxViscosity : MudViscosity;
		
		require constraint {
			doc /* Mud properties must remain within operational specifications. */
		}
	}
	
	requirement def SystemFunctionalRequirement {
		doc /* The drilling mud circulation system shall continuously circulate drilling mud 
		       to perform multiple critical functions simultaneously. */
		
		require wellboreStabilityReq : WellboreStabilityRequirement;
		require cuttingsRemovalReq : CuttingsRemovalRequirement;
		require bitCoolingReq : BitCoolingRequirement;
		require mudPropertyControlReq : MudPropertyControlRequirement;
	}
	
	part drillingMudCirculationSystem {
		doc /* Primary function: Continuously circulate drilling mud in a closed loop to cool 
		       and lubricate the drill bit, transport rock cuttings from the bottom of the wellbore 
		       to the surface, maintain wellbore pressure to prevent formation fluid influx and 
		       wellbore collapse, stabilize the wellbore walls, and suspend cuttings when circulation 
		       is stopped. The system operates by pumping mud down through the drill string, out 
		       through the bit nozzles, up through the annulus carrying cuttings, then separating 
		       solids at the surface before reconditioning and recirculating the mud. */
		
		part pump : MudPump {
			attribute flowRate = 0.05 [SI::m^3/SI::s];
			attribute dischargePressure = 25000000.0 [SI::Pa];
			attribute powerRating = 750000.0 [SI::W];
		}
		
		part drillString : DrillString {
			attribute totalLength = 3000.0 [SI::m];
			attribute innerDiameter = 0.108 [SI::m];
			attribute outerDiameter = 0.127 [SI::m];
		}
		
		part bit : DrillBit {
			attribute bitDiameter = 0.216 [SI::m];
			attribute rotationSpeed = 10.47 [SI::rad/SI::s];
			attribute weightOnBit = 150000.0 [SI::N];
		}
		
		part annulus : Annulus {
			attribute outerDiameter = 0.311 [SI::m];
			attribute innerDiameter = 0.127 [SI::m];
			attribute effectiveLength = 3000.0 [SI::m];
		}
		
		part shaker : ShakerScreen {
			attribute meshSize = 0.0001 [SI::m];
			attribute screenArea = 6.0 [SI::m^2];
			attribute separationEfficiency = 0.96;
		}
		
		part pit : MudPit {
			attribute capacity = 100.0 [SI::m^3];
			attribute currentLevel = 2.5 [SI::m];
			attribute mudInventory = 75.0 [SI::m^3];
		}
		
		part conditioner : MudConditioner {
			attribute targetDensity = 1200.0 [SI::kg/SI::m^3];
			attribute targetViscosity = 0.025 [SI::Pa*SI::s];
			attribute targetPH = 9.5;
		}
		
		part sensor : MudSensor;
		
		connection pumpToDrillString connect pump.outlet to drillString.inlet;
		connection drillStringToBit connect drillString.outlet to bit.inlet;
		connection bitToAnnulus connect bit.outlet to annulus.bottomInlet;
		connection cuttingsToAnnulus connect bit.cuttingsGenerated to annulus.cuttingsInlet;
		connection annulusToShaker connect annulus.surfaceOutlet to shaker.inlet;
		connection shakerToPit connect shaker.cleanMudOutlet to pit.inlet;
		connection pitToConditioner connect pit.outlet to conditioner.inlet;
		connection conditionerToPump connect conditioner.outlet to pump.inlet;
		
		perform action circulateMud : CirculateMudContinuously {
			in attribute systemOperating = true;
			in attribute systemShutdown = false;
			
			action pumpFromPit {
				perform pump.pumpMud;
			}
			then action flowDownDrillString {
				perform drillString.conveyMud;
			}
			then action coolAndCleanBit {
				perform bit.coolAndLubricateBit;
			}
			then action liftCuttingsInAnnulus {
				perform annulus.transportCuttingsUpward;
			}
			then action separateSolidsAtSurface {
				perform shaker.separateCuttings;
			}
			then action conditionAndStoreMud {
				perform conditioner.conditionMud;
				then perform pit.storeMud;
			}
		}
		
		exhibit state circulationState : MudCirculationStates {
			in attribute mudFlowEstablished = true;
			in attribute mudPropertiesOutOfSpec = false;
			in attribute mudPropertiesInSpec = true;
			in attribute pumpsFullyStopped = false;
		}
		
		satisfy systemFunctionalRequirement : SystemFunctionalRequirement {
			subject drillingMudCirculationSystem;
		}
	}
}
