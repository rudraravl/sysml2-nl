package 'Plague Doctor Costume System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PathogenConcentration :> Real;
	attribute def ProtectionEfficiency :> Real;
	attribute def AromaticPotency :> Real;
	
	item def ContaminatedAir {
		attribute pathogenLevel : PathogenConcentration;
		attribute miasmaIntensity : Real;
	}
	
	item def PurifiedAir {
		attribute pathogenLevel : PathogenConcentration;
		attribute aromaticContent : AromaticPotency;
	}
	
	item def BodyFluid;
	item def ContactSurface;
	
	port def AirIntakePort {
		in contaminatedAir : ContaminatedAir;
	}
	
	port def AirExhaustPort {
		out purifiedAir : PurifiedAir;
	}
	
	port def BarrierSurfacePort {
		in externalContaminant : BodyFluid;
		out protectionBarrier : ProtectionEfficiency;
	}
	
	port def DistancingPort {
		out separationDistance : LengthValue;
	}
	
	part def BeakedMask {
		attribute beakLength : LengthValue;
		attribute eyeGlassThickness : LengthValue;
		port airIntake : AirIntakePort;
		port airExhaust : AirExhaustPort;
		part aromaticChamber {
			attribute herbMixture : String;
			attribute chamberVolume : VolumeValue;
			attribute currentPotency : AromaticPotency;
		}
		part glassEyepieces[2] {
			attribute thickness : LengthValue;
		}
		part leatherHarness;
	}
	
	part def WaxedLeatherCoat {
		attribute coatLength : LengthValue;
		attribute waxLayerThickness : LengthValue;
		attribute coverageArea : AreaValue;
		port outerBarrier : BarrierSurfacePort;
	}
	
	part def ThickLeatherGloves {
		attribute gloveThickness : LengthValue;
		attribute fingerLength : LengthValue;
		port handBarrier : BarrierSurfacePort;
	}
	
	part def HighLeatherBoots {
		attribute bootHeight : LengthValue;
		attribute soleThickness : LengthValue;
		port footBarrier : BarrierSurfacePort;
	}
	
	part def WideBrimmedHat {
		attribute brimDiameter : LengthValue;
		attribute hatMaterial : String;
	}
	
	part def WoodenCane {
		attribute caneLength : LengthValue;
		attribute woodDensity : MassDensityValue;
		port distancing : DistancingPort;
	}
	
	action def FilterMiasma {
		in ambientAir : ContaminatedAir;
		in aromaticPotency : AromaticPotency;
		out filteredAir : PurifiedAir;
	}
	
	action def CreatePhysicalBarrier {
		in contaminant : BodyFluid;
		in barrierThickness : LengthValue;
		out protectionLevel : ProtectionEfficiency;
	}
	
	action def MaintainSafeDistance {
		in implementLength : LengthValue;
		out achievedDistance : LengthValue;
	}
	
	action def ReplenishAromatics {
		inout chamberPotency : AromaticPotency;
		in freshHerbs : String;
	}
	
	signal def EndOfDuty;
	signal def DeploymentSignal;
	signal def RemovalSignal;
	
	action def ProtectPhysician {
		first start;
		then merge activeProtection;
		
		action assembleCostume {
			action donMask;
			then action donCoat;
			then action donGloves;
			then action donBoots;
			then action donHat;
			then action graspCane;
		}
		
		then activeProtection;
		
		action filterInhaledAir : FilterMiasma {
			in ambientAir;
			in aromaticPotency;
			out filteredAir;
		}
		
		flow filterInhaledAir.filteredAir to physicianRespiration;
		
		action preventContact : CreatePhysicalBarrier {
			in contaminant;
			in barrierThickness;
			out protectionLevel;
		}
		
		action enforceDistance : MaintainSafeDistance {
			in implementLength;
			out achievedDistance;
		}
		
		then decide;
			if filterInhaledAir.aromaticPotency > minimumPotency and preventContact.protectionLevel > minimumProtection 
				then activeProtection;
			if filterInhaledAir.aromaticPotency <= minimumPotency 
				then refreshAromatics;
		
		action refreshAromatics : ReplenishAromatics {
			inout chamberPotency;
			in freshHerbs;
		}
		then activeProtection;
		
		accept endDuty : EndOfDuty;
		then done;
		
		private attribute minimumPotency : AromaticPotency;
		private attribute minimumProtection : ProtectionEfficiency;
		private attribute physicianRespiration : PurifiedAir;
	}
	
	state def CostumeOperationalStates {
		entry; then stored;
		
		state stored {
			doc /* Costume components stored and not in use */
		}
		
		transition stored_to_donning
			first stored
			accept deploy : DeploymentSignal
			then donning;
		
		state donning {
			entry; then assembling;
			state assembling {
				do action assembleComponents;
			}
			state sealChecking {
				do action verifySealIntegrity;
			}
			transition assembling_to_sealChecking
				first assembling
				if allComponentsDonned
				then sealChecking;
		}
		
		transition donning_to_operational
			first donning
			if sealsVerified
			then operational;
		
		state operational {
			entry; then filtering;
			
			state filtering {
				entry assign airQuality := high;
				do action continuousAirFiltration : FilterMiasma;
			}
			
			state barriering {
				do action continuousBarrierProtection : CreatePhysicalBarrier;
			}
			
			state distancing {
				do action continuousDistanceMaintenance : MaintainSafeDistance;
			}
			
			transition filtering_to_barriering
				first filtering
				if exposureDetected
				then barriering;
			
			transition barriering_to_distancing
				first barriering
				if patientProximity
				then distancing;
			
			transition distancing_to_filtering
				first distancing
				if patientExamComplete
				then filtering;
		}
		
		transition operational_to_maintenance
			first operational
			if aromaticsDepleted or waxDegraded
			then maintenance;
		
		state maintenance {
			state replenishing {
				do action replenishAromaticHerbs;
			}
			state rewaxing {
				do action reapplyWaxCoating;
			}
			transition replenishing_to_rewaxing
				first replenishing
				if aromaticsRestored
				then rewaxing;
		}
		
		transition maintenance_to_operational
			first maintenance
			if maintenanceComplete
			then operational;
		
		transition operational_to_stored
			first operational
			accept remove : RemovalSignal
			then stored;
		
		private attribute airQuality : Real;
		private attribute high : Real;
		private attribute allComponentsDonned : Boolean;
		private attribute sealsVerified : Boolean;
		private attribute exposureDetected : Boolean;
		private attribute patientProximity : Boolean;
		private attribute patientExamComplete : Boolean;
		private attribute aromaticsDepleted : Boolean;
		private attribute waxDegraded : Boolean;
		private attribute aromaticsRestored : Boolean;
		private attribute maintenanceComplete : Boolean;
	}
	
	part plagueDoctorCostume {
		doc /* Complete protective ensemble worn by plague physicians during the Black Death 
		       to prevent contagion through miasmatic theory-based air filtration, 
		       physical barrier protection, and enforced patient distancing. */
		
		attribute overallProtectionEfficiency : ProtectionEfficiency;
		
		part mask : BeakedMask {
			attribute beakLength = 15.0 [cm];
			attribute eyeGlassThickness = 2.5 [mm];
			part aromaticChamber {
				attribute herbMixture = "rose petals, camphor, mint, cloves, myrrh, laudanum";
				attribute chamberVolume = 0.00025 [m^3];
				attribute currentPotency = 0.85;
			}
			part glassEyepieces[2] {
				attribute thickness = 2.5 [mm];
			}
		}
		
		part coat : WaxedLeatherCoat {
			attribute coatLength = 125.0 [cm];
			attribute waxLayerThickness = 0.8 [mm];
			attribute coverageArea = 2.5 [m^2];
		}
		
		part gloves : ThickLeatherGloves {
			attribute gloveThickness = 4.0 [mm];
			attribute fingerLength = 12.0 [cm];
		}
		
		part boots : HighLeatherBoots {
			attribute bootHeight = 55.0 [cm];
			attribute soleThickness = 12.0 [mm];
		}
		
		part hat : WideBrimmedHat {
			attribute brimDiameter = 45.0 [cm];
			attribute hatMaterial = "waxed leather";
		}
		
		part cane : WoodenCane {
			attribute caneLength = 160.0 [cm];
			attribute woodDensity = 1200.0 [kg/m^3];
		}
		
		perform action protectionMission : ProtectPhysician;
		
		part operationalControl {
			perform action stateManagement : CostumeOperationalStates;
		}
		
		connection airFiltrationPath connect 
			mask.airIntake to mask.airExhaust;
		
		connection barrierIntegrity connect
			coat.outerBarrier to gloves.handBarrier;
		
		connection barrierContinuity connect
			gloves.handBarrier to boots.footBarrier;
		
		connection distancingImplement connect
			cane.distancing to mask.airIntake;
	}
	
	requirement def MiasmaFiltrationRequirement {
		doc /* The beaked mask shall filter miasmatic vapors through aromatic substances 
		       to reduce pathogen concentration in inhaled air by at least 90%. */
		
		subject maskSystem : BeakedMask;
		
		require constraint filtrationPerformance {
			outputPathogenLevel <= inputPathogenLevel * 0.10
		}
		
		attribute inputPathogenLevel : PathogenConcentration;
		attribute outputPathogenLevel : PathogenConcentration;
	}
	
	requirement def PhysicalBarrierRequirement {
		doc /* The waxed leather coat and accessories shall prevent penetration of 
		       bodily fluids and contaminated materials through physical barrier. */
		
		subject barrierSystem : WaxedLeatherCoat;
		
		require constraint barrierIntegrity {
			waxThickness >= minimumWaxThickness and
			coatCoverage >= minimumCoverage
		}
		
		attribute waxThickness : LengthValue;
		attribute coatCoverage : AreaValue;
		attribute minimumWaxThickness : LengthValue;
		attribute minimumCoverage : AreaValue;
	}
	
	requirement def PatientDistancingRequirement {
		doc /* The wooden cane shall enable physician to maintain minimum safe distance 
		       from infected patients during examination and treatment. */
		
		subject distancingTool : WoodenCane;
		
		require constraint minimumSeparation {
			caneLength >= requiredDistance
		}
		
		attribute caneLength : LengthValue;
		attribute requiredDistance : LengthValue;
	}
	
	requirement def AromaticPotencyRequirement {
		doc /* The aromatic chamber shall maintain sufficient herbal potency to 
		       neutralize miasmatic vapors throughout duty period. */
		
		subject aromaticSystem : BeakedMask;
		
		require constraint potencyMaintenance {
			chamberPotency >= minimumEffectivePotency
		}
		
		attribute chamberPotency : AromaticPotency;
		attribute minimumEffectivePotency : AromaticPotency;
	}
	
	requirement <'PDC-MAIN-001'> primaryProtectionMission {
		doc /* The plague doctor costume system shall protect the physician from plague 
		       contagion through integrated multi-layer defense: aromatic air filtration 
		       based on miasmatic theory, impermeable physical barriers against bodily fluids, 
		       and enforced physical separation during patient examination and treatment. */
		
		subject costumeSystem : plagueDoctorCostume;
		
		require miasmaFiltrationReq : MiasmaFiltrationRequirement {
			maskSystem = costumeSystem.mask;
			inputPathogenLevel = 1.0;
			outputPathogenLevel = 0.1;
		}
		
		require physicalBarrierReq : PhysicalBarrierRequirement {
			barrierSystem = costumeSystem.coat;
			waxThickness = costumeSystem.coat.waxLayerThickness;
			coatCoverage = costumeSystem.coat.coverageArea;
			minimumWaxThickness = 0.5 [mm];
			minimumCoverage = 2.0 [m^2];
		}
		
		require patientDistancingReq : PatientDistancingRequirement {
			distancingTool = costumeSystem.cane;
			caneLength = costumeSystem.cane.caneLength;
			requiredDistance = 100.0 [cm];
		}
		
		require aromaticPotencyReq : AromaticPotencyRequirement {
			aromaticSystem = costumeSystem.mask;
			chamberPotency = costumeSystem.mask.aromaticChamber.currentPotency;
			minimumEffectivePotency = 0.70;
		}
	}
}
