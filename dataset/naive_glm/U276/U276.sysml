package LaryngealTubeAirwaySystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types with Units ----------
	value def PressureCmH2O :> Real;
	value def PressureMmHg :> Real;
	value def VolumeML :> Real;
	value def FlowLPM :> Real;
	value def LengthMM :> Real;
	value def DiameterMM :> Real;
	value def MassG :> Real;

	item def AirFlow {
		attribute pressure : PressureCmH2O;
		attribute flowRate : FlowLPM;
		attribute oxygenFraction : Real; // 0.0 to 1.0
	}

	item def GastricContents {
		attribute volume : VolumeML;
		attribute pH : Real;
	}

	item def OxygenMixture :> AirFlow;

	// ---------- Enumerations ----------
	enum def PatientSize { adult; pediatric; infant; }
	enum def TubeSize { size0; size1; size2; size3; size4; size5; }
	enum def VentilationMode { manual; mechanical; }
	enum def SealStatus { unsealed; partial; sealed; leaking; }
	enum def PlacementStatus { notInserted; inserting; inserted; misplaced; confirmed; }

	// ---------- Requirements ----------
	requirement def AirwayManagementRequirement {
		doc << "The system shall provide rapid emergency airway management for patients who cannot breathe on their own.">>
	}

	requirement def SupraglotticSealRequirement :> AirwayManagementRequirement {
		doc << "The device shall seal the throat above the vocal cords to create a clear ventilation path without tracheal intubation.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def DualCuffSealRequirement :> AirwayManagementRequirement {
		doc << "A proximal cuff shall seal the oropharynx and a distal cuff shall seal the esophagus.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def AspirationPreventionRequirement :> AirwayManagementRequirement {
		doc << "The distal cuff shall prevent stomach contents from being aspirated into the lungs.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def GastricInsufflationPreventionRequirement :> AirwayManagementRequirement {
		doc << "The dual-seal design shall prevent ventilation air from entering the stomach.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def SinglePortInflationRequirement :> AirwayManagementRequirement {
		doc << "A single inflation port shall inflate both cuffs simultaneously via a shared internal inflation line.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def PilotBalloonIndicatorRequirement :> AirwayManagementRequirement {
		doc << "A pilot balloon shall provide visual and tactile indication of cuff inflation status.">>
		subject pilotBalloon : PilotBalloon;
	}

	requirement def VentilationDeliveryRequirement :> AirwayManagementRequirement {
		doc << "The central ventilation lumen shall deliver air from the ventilation source to the patient's lungs.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def MonitoringRequirement :> AirwayManagementRequirement {
		doc << "The monitoring system shall track airway pressure, confirm air delivery, and detect seal leaks.">>
		subject monitor : MonitoringSystem;
	}

	requirement def SizeVariationRequirement :> AirwayManagementRequirement {
		doc << "The device shall be available in multiple sizes to fit adult, pediatric, and infant patients.">>
		subject device : LaryngealTubeDevice;
	}

	requirement def CuffPressureMaintenanceRequirement :> AirwayManagementRequirement {
		doc << "Cuff pressure shall be maintained within a safe range (40-60 cmH2O) during continuous ventilation.">>
		subject device : LaryngealTubeDevice;
		attribute minSafePressure : PressureCmH2O = 40;
		attribute maxSafePressure : PressureCmH2O = 60;
	}

	requirement LaryngealTubeSystemRequirements :> AirwayManagementRequirement {
		satisfy supraglotticSeal : SupraglotticSealRequirement;
		satisfy dualCuffSeal : DualCuffSealRequirement;
		satisfy aspirationPrevention : AspirationPreventionRequirement;
		satisfy gastricInsufflationPrevention : GastricInsufflationPreventionRequirement;
		satisfy singlePortInflation : SinglePortInflationRequirement;
		satisfy pilotBalloonIndicator : PilotBalloonIndicatorRequirement;
		satisfy ventilationDelivery : VentilationDeliveryRequirement;
		satisfy monitoring : MonitoringRequirement;
		satisfy sizeVariation : SizeVariationRequirement;
		satisfy cuffPressureMaintenance : CuffPressureMaintenanceRequirement;
	}

	// ---------- Port Definitions ----------
	port def AirFlowPort {
		attribute pressure : PressureCmH2O;
		in item airIn : AirFlow;
		out item airOut : AirFlow;
	}

	port def InflationPort {
		attribute pressure : PressureCmH2O;
		in item inflationFluid;
		out item deflationFluid;
	}

	port def PressureSensorPort {
		out item pressureReading : PressureCmH2O;
	}

	port def CO2SamplePort {
		out item gasSample : AirFlow;
	}

	port def GastricPort {
		out item gastricContents : GastricContents;
	}

	// ---------- Part Definitions ----------
	part def MedicalGradeSilicone {
		attribute shoreHardness : Real;
		attribute biocompatible : Boolean = true;
	}

	part def LaryngealTubeDevice {
		attribute tubeSize : TubeSize;
		attribute patientSize : PatientSize;
		attribute tubeLength : LengthMM;
		attribute outerDiameter : DiameterMM;
		attribute material : MedicalGradeSilicone;

		part ventilationLumen : VentilationLumen {
			attribute innerDiameter : DiameterMM;
		}

		part proximalCuff : Cuff {
			attribute designation : String = "proximal";
			attribute maxVolume : VolumeML;
			attribute currentVolume : VolumeML;
			attribute currentPressure : PressureCmH2O;
			attribute inflated : Boolean;
		}

		part distalCuff : Cuff {
			attribute designation : String = "distal";
			attribute maxVolume : VolumeML;
			attribute currentVolume : VolumeML;
			attribute currentPressure : PressureCmH2O;
			attribute inflated : Boolean;
		}

		part inflationLine : InflationLine {
			attribute internalDiameter : DiameterMM;
		}

		part mainConnector :> Connector15mm {
			port ventilationPort : AirFlowPort;
		}

		part inflationPort : InflationPortInterface {
			port inflationConnection : InflationPort;
		}

		part pilotBalloonInterface : PilotBalloon;

		port proximalAirwayPort : AirFlowPort;
		port esophagealSealPort : GastricPort;
		port monitoringPort : PressureSensorPort;

		attribute sealStatus : SealStatus = SealStatus::unsealed;
		attribute placementStatus : PlacementStatus = PlacementStatus::notInserted;

		requirement ref supraglotticSealReq : SupraglotticSealRequirement { subject = this; }
		requirement ref dualCuffReq : DualCuffSealRequirement { subject = this; }
		requirement ref aspirationReq : AspirationPreventionRequirement { subject = this; }
		requirement ref gastricReq : GastricInsufflationPreventionRequirement { subject = this; }
		requirement ref singlePortReq : SinglePortInflationRequirement { subject = this; }
		requirement ref ventilationReq : VentilationDeliveryRequirement { subject = this; }
		requirement ref cuffPressureReq : CuffPressureMaintenanceRequirement { subject = this; }

		exhibit laryngealTubeOperation : LaryngealTubeOperationStateMachine {
			subject = this;
		}
	}

	part def Cuff {
		attribute designation : String;
		attribute maxVolume : VolumeML;
		attribute currentVolume : VolumeML;
		attribute currentPressure : PressureCmH2O;
		attribute inflated : Boolean = false;

		action inflate {
			in item inflationVolume : VolumeML;
			// Increase currentVolume and currentPressure
		}

		action deflate {
			out item deflationVolume : VolumeML;
			// Decrease currentVolume and currentPressure
		}
	}

	part def VentilationLumen {
		attribute innerDiameter : DiameterMM;
		attribute length : LengthMM;
		port proximalEnd : AirFlowPort;
		port distalEnd : AirFlowPort;
	}

	part def InflationLine {
		attribute internalDiameter : DiameterMM;
		attribute length : LengthMM;
		port syringeEnd : InflationPort;
		port proximalCuffEnd : InflationPort;
		port distalCuffEnd : InflationPort;
		port pilotBalloonEnd : InflationPort;
	}

	part def Connector15mm {
		attribute standard : String = "ISO 5356-1 15mm";
		port airFlowPort : AirFlowPort;
	}

	part def InflationPortInterface {
		port inflationConnection : InflationPort;
		attribute connectorType : String = "Luer";
	}

	part def InflationSyringe {
		attribute capacity : VolumeML;
		attribute currentVolume : VolumeML;
		attribute plungerPosition : Real; // 0.0 to 1.0
		port syringePort : InflationPort;

		action deliverAir {
			out item deliveredVolume : VolumeML;
		}

		action withdrawAir {
			in item withdrawnVolume : VolumeML;
		}
	}

	part def PilotBalloon {
		attribute inflated : Boolean = false;
		attribute pressure : PressureCmH2O;
		attribute tactileFirmness : Real; // 0.0 soft to 1.0 firm
		port balloonPort : InflationPort;

		requirement ref pilotBalloonReq : PilotBalloonIndicatorRequirement { subject = this; }

		action indicateInflation {
			in item cuffPressure : PressureCmH2O;
			// Update visual and tactile state
		}
	}

	part def VentilationSource {
		attribute mode : VentilationMode;
		attribute maxPressure : PressureCmH2O;
		attribute deliveredVolume : VolumeML;
		attribute respiratoryRate : Real; // breaths per minute
		port outputPort : AirFlowPort;

		action deliverBreath {
			out item deliveredAir : OxygenMixture;
			attribute deliveredPressure : PressureCmH2O;
		}

		action pauseExpiration {
			// Hold between breaths
		}
	}

	part def ManualResuscitationBag :> VentilationSource {
		attribute mode : VentilationMode = VentilationMode::manual;
		attribute bagVolume : VolumeML;
		attribute oxygenReservoirAttached : Boolean;
	}

	part def MechanicalVentilator :> VentilationSource {
		attribute mode : VentilationMode = VentilationMode::mechanical;
		attribute tidalVolume : VolumeML;
		attribute peep : PressureCmH2O;
		attribute iERatio : String; // inspiratory-to-expiratory ratio
	}

	part def MonitoringSystem {
		attribute airwayPressure : PressureCmH2O;
		attribute etCO2 : Real; // end-tidal CO2 in mmHg
		attribute leakDetected : Boolean = false;
		attribute oxygenationConfirmed : Boolean = false;
		port pressureInput : PressureSensorPort;
		port gasSampleInput : CO2SamplePort;
		port airwayFlowInput : AirFlowPort;

		requirement ref monitoringReq : MonitoringRequirement { subject = this; }

		action monitorAirwayPressure {
			in item pressureReading : PressureCmH2O;
			// Update airwayPressure, evaluate leak
		}

		action confirmVentilation {
			in item gasSample : AirFlow;
			// Evaluate etCO2 to confirm air delivery
		}

		action detectLeak {
			in item measuredPressure : PressureCmH2O;
			in item expectedPressure : PressureCmH2O;
			// Set leakDetected based on pressure drop
		}
	}

	// ---------- State Machine ----------
	state machine def LaryngealTubeOperationStateMachine {
		subject device : LaryngealTubeDevice;

		state notInserted {
			entry : device.placementStatus = PlacementStatus::notInserted;
			entry : device.sealStatus = SealStatus::unsealed;
			entry : device.proximalCuff.inflated = false;
			entry : device.distalCuff.inflated = false;
		}

		state inserting {
			entry : device.placementStatus = PlacementStatus::inserting;
			// Medical personnel advance tube into oropharynx
			do : advanceTube;
		}

		state inserted {
			entry : device.placementStatus = PlacementStatus::inserted;
			// Tube is in position; cuffs not yet inflated
		}

		state inflatingCuffs {
			entry : device.sealStatus = SealStatus::partial;
			do : inflateCuffs;
			// Syringe delivers air through single port to both cuffs
		}

		state verifyingPlacement {
			entry : device.placementStatus = PlacementStatus::confirmed;
			do : verifyPlacement;
			// Check pilot balloon, auscultate, confirm via monitoring
		}

		state ventilating {
			entry : device.sealStatus = SealStatus::sealed;
			do : maintainVentilation;
			// Continuous ventilation with ongoing monitoring
		}

		state monitoringSeal {
			do : monitorCuffPressure;
			// Verify cuff pressure adequate, detect leaks
		}

		state leakDetected {
			entry : device.sealStatus = SealStatus::leaking;
			do : adjustInflation;
			// Re-inflate or reposition as needed
		}

		state deflatingCuffs {
			entry : device.sealStatus = SealStatus::partial;
			do : deflateCuffs;
			// Withdraw air via syringe
		}

		state removed {
			entry : device.placementStatus = PlacementStatus::notInserted;
			entry : device.sealStatus = SealStatus::unsealed;
			entry : device.proximalCuff.inflated = false;
			entry : device.distalCuff.inflated = false;
		}

		transition notInserted_to_inserting
			source notInserted
			target inserting
			when (operatorInitiatesInsertion);

		transition inserting_to_inserted
			source inserting
			target inserted
			when (tubeFullyAdvanced);

		transition inserted_to_inflatingCuffs
			source inserted
			target inflatingCuffs
			when (syringeConnected);

		transition inflatingCuffs_to_verifyingPlacement
			source inflatingCuffs
			target verifyingPlacement
			when (cuffsInflated and pilotBalloonFirm);

		transition verifyingPlacement_to_ventilating
			source verifyingPlacement
			target ventilating
			when (placementConfirmed and ventilationSourceConnected);

		transition ventilating_to_monitoringSeal
			source ventilating
			target monitoringSeal
			when (monitoringIntervalElapsed);

		transition monitoringSeal_to_ventilating
			source monitoringSeal
			target ventilating
			when (sealAdequate and pressureInRange);

		transition monitoringSeal_to_leakDetected
			source monitoringSeal
			target leakDetected
			when (pressureDropExceedsThreshold);

		transition leakDetected_to_inflatingCuffs
			source leakDetected
			target inflatingCuffs
			when (adjustmentInitiated);

		transition ventilating_to_deflatingCuffs
			source ventilating
			target deflatingCuffs
			when (airwayNoLongerNeeded);

		transition deflatingCuffs_to_removed
			source deflatingCuffs
			target removed
			when (cuffsFullyDeflated);

		// Actions referenced by states
		action advanceTube {
			// Advance laryngeal tube into patient oropharynx until resistance felt
		}

		action inflateCuffs {
			// Syringe delivers air through single inflation port
			// Air flows through inflation line to both proximal and distal cuffs
			// Pilot balloon inflates simultaneously
		}

		action verifyPlacement {
			// Auscultate lungs, check chest rise, confirm via etCO2 monitoring
		}

		action maintainVentilation {
			// Ventilation source delivers breaths through main connector
			// Air flows through ventilation lumen to lungs
			// Proximal cuff seals oropharynx, distal cuff seals esophagus
		}

		action monitorCuffPressure {
			// Check pilot balloon firmness
			// Monitor airway pressure via monitoring system
		}

		action adjustInflation {
			// Add or remove air to restore adequate seal
		}

		action deflateCuffs {
			// Withdraw air from single inflation port using syringe
			// Both cuffs deflate simultaneously
		}
	}

	// ---------- System Assembly ----------
	part def LaryngealTubeAirwaySystemAssembly {
		part laryngealTube : LaryngealTubeDevice {
			attribute tubeSize = TubeSize::size4;
			attribute patientSize = PatientSize::adult;
			attribute tubeLength : LengthMM = 230;
			attribute outerDiameter : DiameterMM = 18;
		}

		part inflationSyringe : InflationSyringe {
			attribute capacity : VolumeML = 100;
			attribute currentVolume : VolumeML = 0;
		}

		part pilotBalloon : PilotBalloon {
			attribute inflated = false;
			attribute pressure : PressureCmH2O = 0;
		}

		part ventilationSource : ManualResuscitationBag {
			attribute maxPressure : PressureCmH2O = 60;
			attribute bagVolume : VolumeML = 1600;
			attribute oxygenReservoirAttached = true;
		}

		part monitoringSystem : MonitoringSystem {
			attribute airwayPressure : PressureCmH2O = 0;
			attribute leakDetected = false;
		}

		// Connections
		connection inflationSyringe.syringePort to laryngealTube.inflationPort.inflationConnection {
			item type :> AirFlow;
		}

		connection laryngealTube.inflationLine.pilotBalloonEnd to pilotBalloon.balloonPort {
			item type :> AirFlow;
		}

		connection laryngealTube.inflationLine.proximalCuffEnd to laryngealTube.proximalCuff {
			item type :> AirFlow;
		}

		connection laryngealTube.inflationLine.distalCuffEnd to laryngealTube.distalCuff {
			item type :> AirFlow;
		}

		connection ventilationSource.outputPort to laryngealTube.mainConnector.ventilationPort {
			item type :> OxygenMixture;
		}

		connection laryngealTube.monitoringPort to monitoringSystem.pressureInput {
			item type :> PressureCmH2O;
		}

		connection laryngealTube.proximalAirwayPort to monitoringSystem.airwayFlowInput {
			item type :> AirFlow;
		}

		// Flow path: ventilation source -> main connector -> ventilation lumen -> patient lungs
		connection laryngealTube.mainConnector.ventilationPort to laryngealTube.ventilationLumen.proximalEnd {
			item type :> AirFlow;
		}

		connection laryngealTube.ventilationLumen.distalEnd to laryngealTube.proximalAirwayPort {
			item type :> AirFlow;
		}

		requirement ref systemRequirements : LaryngealTubeSystemRequirements;
	}

	// ---------- Size Configurations ----------
	part def AdultLaryngealTube :> LaryngealTubeDevice {
		attribute tubeSize = TubeSize::size4;
		attribute patientSize = PatientSize::adult;
		attribute tubeLength : LengthMM = 230;
		attribute outerDiameter : DiameterMM = 18;
		attribute proximalCuff.maxVolume : VolumeML = 45;
		attribute distalCuff.maxVolume : VolumeML = 15;
	}

	part def PediatricLaryngealTube :> LaryngealTubeDevice {
		attribute tubeSize = TubeSize::size2;
		attribute patientSize = PatientSize::pediatric;
		attribute tubeLength : LengthMM = 170;
		attribute outerDiameter : DiameterMM = 12;
		attribute proximalCuff.maxVolume : VolumeML = 20;
		attribute distalCuff.maxVolume : VolumeML = 7;
	}

	part def InfantLaryngealTube :> LaryngealTubeDevice {
		attribute tubeSize = TubeSize::size0;
		attribute patientSize = PatientSize::infant;
		attribute tubeLength : LengthMM = 110;
		attribute outerDiameter : DiameterMM = 8;
		attribute proximalCuff.maxVolume : VolumeML = 8;
		attribute distalCuff.maxVolume : VolumeML = 3;
	}

}
