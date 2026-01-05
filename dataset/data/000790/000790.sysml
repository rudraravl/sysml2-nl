package SyringeFilterSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FluidType;
	attribute def ContaminantType;
	attribute def SterilityStatus;
	
	attribute def FluidVolume :> VolumeValue;
	attribute def PoreSize :> LengthValue;
	attribute def FluidPressure :> PressureValue;
	attribute def FlowRate :> VolumeFlowRateValue;
	attribute def ParticleSize :> LengthValue;
	
	port def FluidInletPort {
		in attribute inputFluid : FluidType;
		in attribute inputVolume : FluidVolume;
		in attribute contaminants : ContaminantType[*];
		in attribute particleSize : ParticleSize;
	}
	
	port def FluidOutletPort {
		out attribute outputFluid : FluidType;
		out attribute outputVolume : FluidVolume;
		out attribute sterility : SterilityStatus;
		out attribute clarity : Real;
	}
	
	port def PressureApplicationPort {
		in attribute appliedForce : ForceValue;
		out attribute generatedPressure : FluidPressure;
	}
	
	item def UnfilteredSample {
		attribute fluid : FluidType;
		attribute volume : FluidVolume;
		attribute contaminantLevel : Real;
		attribute particulates[*] : ParticleSize;
	}
	
	item def FilteredSample {
		attribute fluid : FluidType;
		attribute volume : FluidVolume;
		attribute purityLevel : Real;
		attribute sterile : Boolean;
	}
	
	part def SyringeBarrel {
		attribute capacity : FluidVolume;
		attribute currentVolume : FluidVolume;
		attribute barrelDiameter : LengthValue;
		port fluidOutlet : FluidOutletPort;
		port pressureInput : PressureApplicationPort;
	}
	
	part def Plunger {
		attribute position : LengthValue;
		attribute maxTravel : LengthValue;
		attribute appliedForce : ForceValue;
		port forceOutput : PressureApplicationPort;
	}
	
	part def FilterMembrane {
		attribute poreSize : PoreSize;
		attribute effectiveArea : AreaValue;
		attribute material : String;
		attribute maxPressure : FluidPressure;
		attribute filtrationEfficiency : Real;
		port upstream : FluidInletPort;
		port downstream : FluidOutletPort;
	}
	
	part def FilterHousing {
		attribute housingMaterial : String;
		attribute sterilePackaging : Boolean;
		attribute inletType : String;
		attribute outletType : String;
		port membraneMount;
		port syringeConnection;
		port filtrateOutlet;
	}
	
	part def CollectionVessel {
		attribute capacity : FluidVolume;
		attribute collectedVolume : FluidVolume;
		attribute vesselType : String;
		port fluidInlet : FluidInletPort;
	}
	
	action def CalculatePressure {
		in plungerForce : ForceValue;
		in barrelArea : AreaValue;
		out fluidPressure : FluidPressure;
	}
	
	action def FilterLiquid {
		in unfilteredFluid : UnfilteredSample;
		in appliedPressure : FluidPressure;
		in membranePoreSize : PoreSize;
		in membraneArea : AreaValue;
		out filteredFluid : FilteredSample;
		out flowRate : FlowRate;
		out retainedParticles : Real;
	}
	
	action def CollectFiltrate {
		in filteredFluid : FilteredSample;
		in targetVolume : FluidVolume;
		out collectedSample : FilteredSample;
		out collectionComplete : Boolean;
	}
	
	action def PerformSyringeFiltration {
		in sampleVolume : FluidVolume;
		in filterPoreSize : PoreSize;
		in maxPressure : FluidPressure;
		out purifiedSample : FilteredSample;
		
		first start;
		
		then action loadSample {
			doc /* Load unfiltered sample into syringe barrel */
			out loadedSample : UnfilteredSample;
		}
		
		then action attachFilter {
			doc /* Attach filter unit to syringe barrel outlet */
			out filterAttached : Boolean;
		}
		
		then action positionCollection {
			doc /* Position collection vessel under filter outlet */
			out vesselReady : Boolean;
		}
		
		then merge continueFiltration;
		
		then action calculatePressure : CalculatePressure {
			in plungerForce;
			in barrelArea;
			out fluidPressure;
		}
		
		then decide;
			if calculatePressure.fluidPressure > maxPressure then abortFiltration;
			if calculatePressure.fluidPressure <= maxPressure then proceedFiltration;
		
		action proceedFiltration {
			then action filterLiquid : FilterLiquid {
				in unfilteredFluid = loadSample.loadedSample;
				in appliedPressure = calculatePressure.fluidPressure;
				in membranePoreSize = filterPoreSize;
				in membraneArea;
				out filteredFluid;
				out flowRate;
				out retainedParticles;
			}
			
			then action collectFiltrateAction : CollectFiltrate {
				in filteredFluid = filterLiquid.filteredFluid;
				in targetVolume = sampleVolume;
				out collectedSample;
				out collectionComplete;
			}
			
			then decide;
				if collectFiltrateAction.collectionComplete then completeFiltration;
				else continueFiltration;
		}
		
		action abortFiltration {
			doc /* Abort filtration due to excessive pressure */
			out errorStatus : String;
		}
		then done;
		
		action completeFiltration {
			doc /* Filtration complete, remove and dispose filter */
			assign purifiedSample := collectFiltrateAction.collectedSample;
		}
		then done;
	}
	
	part def SyringeFilterSystem {
		doc /* 
			A syringe filter system is a single-use filtration device designed to remove 
			particulate matter, microorganisms, and contaminants from liquid samples. 
			The system operates by applying manual pressure through a plunger mechanism 
			to force fluid through a microporous membrane filter with precisely controlled 
			pore size. The filtered liquid (filtrate) is collected in a receiving vessel 
			while particles larger than the pore size are retained on the membrane surface. 
			Primary applications include sterilization of heat-sensitive solutions, 
			clarification of samples for analytical instruments (HPLC, GC), removal of 
			particles from biological fluids, and preparation of sterile media in 
			laboratory and pharmaceutical settings.
		*/
		
		part syringe : SyringeBarrel {
			attribute capacity = 10.0 [SI::mL];
			attribute barrelDiameter = 14.5 [SI::mm];
		}
		
		part plunger : Plunger {
			attribute maxTravel = 60.0 [SI::mm];
		}
		
		part filterMembrane : FilterMembrane {
			attribute poreSize = 0.22 [SI::um];
			attribute effectiveArea = 4.5 [SI::cm2];
			attribute material = "PVDF";
			attribute maxPressure = 520.0 [SI::kPa];
			attribute filtrationEfficiency = 0.997;
		}
		
		part filterHousing : FilterHousing {
			attribute housingMaterial = "Polypropylene";
			attribute sterilePackaging = true;
			attribute inletType = "Luer Lock";
			attribute outletType = "Nozzle";
		}
		
		part collectionVessel : CollectionVessel {
			attribute capacity = 15.0 [SI::mL];
			attribute vesselType = "Sterile Tube";
		}
		
		connection plungerToSyringe connect plunger.forceOutput to syringe.pressureInput;
		connection syringeToFilter connect syringe.fluidOutlet to filterMembrane.upstream;
		connection filterToHousing connect filterMembrane to filterHousing.membraneMount;
		connection housingToSyringe connect filterHousing.syringeConnection to syringe;
		connection housingToCollection connect filterHousing.filtrateOutlet to collectionVessel.fluidInlet;
		
		perform action filtrationProcess : PerformSyringeFiltration {
			in sampleVolume = 5.0 [SI::mL];
			in filterPoreSize = filterMembrane.poreSize;
			in maxPressure = filterMembrane.maxPressure;
			out purifiedSample;
		}
		
		state filtrationLifecycle {
			entry; then idle;
			
			state idle {
				doc /* System is packaged and sterile, ready for use */
			}
			
			state prepared {
				doc /* Filter attached to syringe, collection vessel positioned */
			}
			
			state filtering {
				doc /* Active filtration in progress, pressure applied */
			}
			
			state clogged {
				doc /* Filter membrane blocked by excessive particulates */
			}
			
			state complete {
				doc /* Filtration complete, sample collected */
			}
			
			state disposed {
				doc /* Single-use filter discarded after use */
			}
			
			transition first idle
				accept loadSample
				then prepared;
			
			transition first prepared
				accept applyPressure
				then filtering;
			
			transition first filtering
				if filtrationProcess.purifiedSample.purityLevel >= 0.99
				then complete;
			
			transition first filtering
				if filtrationProcess.calculatePressure.fluidPressure > filterMembrane.maxPressure
				then clogged;
			
			transition first complete
				accept removeFilter
				then disposed;
			
			transition first clogged
				accept removeFilter
				then disposed;
		}
	}
	
	requirement def FiltrationEfficiencyRequirement {
		doc /* The syringe filter shall remove particles larger than the specified pore size 
		       with minimum 99.7% efficiency */
		
		subject filterSystem : SyringeFilterSystem;
		
		require constraint {
			filterSystem.filterMembrane.poreSize >= 0.1 [SI::um] and
			filterSystem.filterMembrane.poreSize <= 5.0 [SI::um] and
			filterSystem.filterMembrane.filtrationEfficiency >= 0.997
		}
	}
	
	requirement def SterilityRequirement {
		doc /* The syringe filter shall maintain sterility of filtered sample for 
		       sterile filtration applications */
		
		subject filterSystem : SyringeFilterSystem;
		
		require constraint {
			filterSystem.filterHousing.sterilePackaging == true and
			filterSystem.filterMembrane.poreSize <= 0.22 [SI::um]
		}
	}
	
	requirement def PressureLimitRequirement {
		doc /* The system shall not exceed the membrane maximum operating pressure 
		       during filtration to prevent membrane rupture */
		
		subject filterSystem : SyringeFilterSystem;
		
		require constraint {
			filterSystem.filtrationProcess.calculatePressure.fluidPressure <= 
			filterSystem.filterMembrane.maxPressure
		}
	}
	
	requirement def FlowRateRequirement {
		doc /* The syringe filter shall maintain adequate flow rate under manual 
		       pressure application for practical laboratory use */
		
		subject filterSystem : SyringeFilterSystem;
	}
	
	requirement <'SYS-REQ-001'> syringeFilterSystemRequirement {
		doc /* The syringe filter system shall effectively remove particulate contaminants 
		       and microorganisms from liquid samples while maintaining sample integrity 
		       and sterility */
		
		require FiltrationEfficiencyRequirement;
		require SterilityRequirement;
		require PressureLimitRequirement;
		require FlowRateRequirement;
	}
	
	part syringeFilterSystem : SyringeFilterSystem {
		satisfy syringeFilterSystemRequirement;
	}
}
