package 'Shirley Drain System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FluidTemperature :> ISQ::ThermodynamicTemperatureValue;
	attribute def FluidFlowRate :> ISQ::VolumeFlowRateValue;
	attribute def FluidPressure :> ISQ::PressureValue;
	attribute def TubeLength :> ISQ::LengthValue;
	attribute def TubeDiameter :> ISQ::LengthValue;
	attribute def FluidVolume :> ISQ::VolumeValue;
	
	item def BodyFluid {
		attribute temperature : FluidTemperature;
		attribute flowRate : FluidFlowRate;
		attribute volume : FluidVolume;
		attribute viscosity : Real;
	}
	
	item def SerousFluid :> BodyFluid {
		doc /* Fluid accumulated in body cavities such as pleural, peritoneal, or pericardial spaces */
		attribute proteinContent : Real;
	}
	
	port def FluidCollectionPort {
		in item fluidIn : SerousFluid;
		attribute inletPressure : FluidPressure;
	}
	
	port def FluidDischargePort {
		out item fluidOut : SerousFluid;
		attribute outletPressure : FluidPressure;
	}
	
	port def VentilationPort {
		attribute airPressure : FluidPressure;
		attribute isOpen : Boolean;
	}
	
	part def PerforatedDrainTube {
		doc /* Flexible silicone tube with multiple perforations along its length for fluid collection */
		
		attribute length : TubeLength;
		attribute outerDiameter : TubeDiameter;
		attribute innerDiameter : TubeDiameter;
		attribute perforationCount : Integer;
		attribute perforationSize : TubeDiameter;
		attribute materialType : String;
		
		port perforations : FluidCollectionPort[*] {
			doc /* Multiple drainage holes distributed along tube length */
		}
		
		port proximalEnd : FluidDischargePort {
			doc /* Exit point of drain tube */
		}
	}
	
	part def AntiRefluxValve {
		doc /* One-way valve preventing backflow into body cavity */
		
		attribute openingPressure : FluidPressure;
		attribute closingPressure : FluidPressure;
		attribute valveState : Boolean;
		
		port upstream : FluidCollectionPort;
		port downstream : FluidDischargePort;
	}
	
	part def CollectionReservoir {
		doc /* Graduated container for collecting and measuring drained fluid */
		
		attribute maxCapacity : FluidVolume;
		attribute currentLevel : FluidVolume;
		attribute internalPressure : FluidPressure;
		attribute graduationInterval : FluidVolume;
		
		port inlet : FluidCollectionPort;
		port vent : VentilationPort;
		port measurementIndicator {
			out attribute volumeMeasurement : FluidVolume;
		}
	}
	
	part def ShirleyDrainAssembly {
		doc /* 
			Complete Shirley drain system for passive drainage of body cavity fluids.
			Primary function: Continuously remove accumulated serous fluid from body cavities
			using gravity-assisted flow through a perforated catheter into a collection chamber.
		*/
		
		attribute totalVolumeCollected : FluidVolume;
		attribute averageDrainageRate : FluidFlowRate;
		attribute systemIntegrity : Boolean;
		
		part drainCatheter : PerforatedDrainTube {
			attribute length = 25.0 [SI::cm];
			attribute outerDiameter = 6.0 [SI::mm];
			attribute innerDiameter = 4.0 [SI::mm];
			attribute perforationCount = 16;
			attribute perforationSize = 1.5 [SI::mm];
			attribute materialType = "medical-grade silicone";
		}
		
		part valve : AntiRefluxValve {
			attribute openingPressure = 1.5 [SI::kPa];
			attribute closingPressure = 0.5 [SI::kPa];
		}
		
		part collectionChamber : CollectionReservoir {
			attribute maxCapacity = 400.0 [SI::mL];
			attribute currentLevel = 0.0 [SI::mL];
			attribute graduationInterval = 10.0 [SI::mL];
		}
		
		connection catheterToValve connect 
			drainCatheter.proximalEnd to valve.upstream;
		
		connection valveToReservoir connect 
			valve.downstream to collectionChamber.inlet;
		
		perform action drainBodyCavity : DrainCavityFluid;
	}
	
	action def SenseFluidPresence {
		in cavityPressure : FluidPressure;
		in fluidAvailable : Boolean;
		out drainageNeeded : Boolean;
		out pressureGradient : FluidPressure;
	}
	
	action def CollectThroughPerforations {
		in sourceFluid : SerousFluid;
		in perforationArea : Real;
		in pressureDifferential : FluidPressure;
		out collectedFluid : SerousFluid;
		out instantaneousFlowRate : FluidFlowRate;
	}
	
	action def TransportViaGravity {
		in inputFluid : SerousFluid;
		in tubeGeometry : TubeLength;
		in elevationDifference : ISQ::LengthValue;
		out outputFluid : SerousFluid;
		out transportRate : FluidFlowRate;
	}
	
	action def RegulateFlow {
		in incomingPressure : FluidPressure;
		in valveThreshold : FluidPressure;
		out permitFlow : Boolean;
		out regulatedPressure : FluidPressure;
	}
	
	action def AccumulateFluid {
		in drainedFluid : SerousFluid;
		in reservoirVolume : FluidVolume;
		in reservoirCapacity : FluidVolume;
		out updatedVolume : FluidVolume;
		out capacityExceeded : Boolean;
	}
	
	action def DrainCavityFluid {
		doc /* 
			Primary drainage function: Passively remove serous fluid from body cavity
			through continuous collection via perforated catheter, gravity-driven transport,
			valve-regulated flow, and accumulation in graduated collection chamber.
		*/
		
		in bodyCavityFluid : SerousFluid;
		out totalDrainedVolume : FluidVolume;
		
		first start;
		
		then merge continuousDrainage;
		
		then action sense : SenseFluidPresence {
			in cavityPressure : FluidPressure;
			in fluidAvailable : Boolean;
			out drainageNeeded : Boolean;
			out pressureGradient : FluidPressure;
		}
		
		then decide;
			if sense.drainageNeeded and sense.pressureGradient > 0.0 [SI::kPa] 
				then collectFluid;
			if not sense.drainageNeeded or sense.pressureGradient <= 0.0 [SI::kPa] 
				then endDrainage;
		
		action collectFluid : CollectThroughPerforations {
			in sourceFluid = bodyCavityFluid;
			in perforationArea = 28.3;
			in pressureDifferential = sense.pressureGradient;
			out collectedFluid : SerousFluid;
			out instantaneousFlowRate : FluidFlowRate;
		}
		
		then action transport : TransportViaGravity {
			in inputFluid = collectFluid.collectedFluid;
			in tubeGeometry = 25.0 [SI::cm];
			in elevationDifference = 15.0 [SI::cm];
			out outputFluid : SerousFluid;
			out transportRate : FluidFlowRate;
		}
		
		then action regulate : RegulateFlow {
			in incomingPressure = 2.5 [SI::kPa];
			in valveThreshold = 1.5 [SI::kPa];
			out permitFlow : Boolean;
			out regulatedPressure : FluidPressure;
		}
		
		then decide;
			if regulate.permitFlow then storeFluid;
			if not regulate.permitFlow then continuousDrainage;
		
		action storeFluid : AccumulateFluid {
			in drainedFluid = transport.outputFluid;
			in reservoirVolume = 0.0 [SI::mL];
			in reservoirCapacity = 400.0 [SI::mL];
			out updatedVolume : FluidVolume;
			out capacityExceeded : Boolean;
		}
		
		then decide;
			if not storeFluid.capacityExceeded then continuousDrainage;
			if storeFluid.capacityExceeded then endDrainage;
		
		action endDrainage {
			out finalVolume : FluidVolume = storeFluid.updatedVolume;
		}
		
		then done;
	}
	
	requirement def DrainageEfficiencyRequirement {
		doc /* System must maintain adequate drainage rate to prevent fluid reaccumulation */
		
		subject drainSystem : ShirleyDrainAssembly;
		
		require constraint minimumFlowRate {
			drainSystem.averageDrainageRate >= 5.0 [SI::mL / SI::h]
		}
	}
	
	requirement def SafetyRequirement {
		doc /* System must prevent backflow and maintain closed sterile environment */
		
		subject system : ShirleyDrainAssembly;
		
		require constraint backflowPrevention {
			system.valve.valveState implies 
				system.valve.upstream.inletPressure > system.valve.downstream.outletPressure
		}
		
		require constraint ventilationMaintained {
			system.collectionChamber.vent.isOpen = true
		}
		
		require constraint systemIntegrity {
			system.systemIntegrity = true
		}
	}
	
	requirement def CapacityRequirement {
		doc /* Collection chamber must provide adequate volume capacity with clear measurement */
		
		subject reservoir : CollectionReservoir;
		
		require constraint adequateCapacity {
			reservoir.maxCapacity >= 400.0 [SI::mL]
		}
		
		require constraint volumeTracking {
			reservoir.currentLevel <= reservoir.maxCapacity
		}
		
		require constraint measurementPrecision {
			reservoir.graduationInterval <= 10.0 [SI::mL]
		}
	}
	
	requirement def MaterialBiocompatibilityRequirement {
		doc /* Drain materials must be biocompatible and suitable for prolonged body contact */
		
		subject catheter : PerforatedDrainTube;
		
		require constraint biocompatibleMaterial {
			catheter.materialType == "medical-grade silicone"
		}
	}
	
	requirement <'SDR-001'> shirleyDrainSystemRequirement {
		doc /* 
			The Shirley drain system shall passively and continuously drain serous fluid
			from body cavities through a perforated catheter using gravity-assisted flow,
			valve-regulated transport, and graduated collection with volume measurement.
		*/
		
		subject drainAssembly : ShirleyDrainAssembly;
		
		assume constraint pressureGradientExists {
			drainAssembly.drainCatheter.perforations.inletPressure > 
			drainAssembly.collectionChamber.internalPressure
		}
		
		assume constraint properPositioning {
			doc /* Drain catheter positioned in dependent portion of body cavity */
			true
		}
		
		require drainAssembly satisfy efficiency : DrainageEfficiencyRequirement;
		require drainAssembly satisfy safety : SafetyRequirement;
		require drainAssembly.collectionChamber satisfy capacity : CapacityRequirement;
		require drainAssembly.drainCatheter satisfy biocompatibility : MaterialBiocompatibilityRequirement;
	}
}
