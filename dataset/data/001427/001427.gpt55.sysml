package FemtotechnologySystemModel {

	import ScalarValues::*;

	attribute def FemtometerLength :> Real {
		attribute unitSymbol : String = "fm";
		attribute reference : String = "1 fm = 1.0e-15 m";
	}

	attribute def NanometerLength :> Real {
		attribute unitSymbol : String = "nm";
		attribute reference : String = "1 nm = 1.0e-9 m";
	}

	attribute def ZeptosecondTime :> Real {
		attribute unitSymbol : String = "zs";
		attribute reference : String = "1 zs = 1.0e-21 s";
	}

	attribute def AttosecondTime :> Real {
		attribute unitSymbol : String = "as";
		attribute reference : String = "1 as = 1.0e-18 s";
	}

	attribute def MegaElectronVoltEnergy :> Real {
		attribute unitSymbol : String = "MeV";
		attribute reference : String = "1 MeV = 1.602176634e-13 J";
	}

	attribute def TeslaFluxDensity :> Real {
		attribute unitSymbol : String = "T";
	}

	attribute def KelvinTemperature :> Real {
		attribute unitSymbol : String = "K";
	}

	attribute def SievertPerHourDoseRate :> Real {
		attribute unitSymbol : String = "Sv/h";
	}

	attribute def WattPower :> Real {
		attribute unitSymbol : String = "W";
	}

	attribute def VoltPotential :> Real {
		attribute unitSymbol : String = "V";
	}

	attribute def AmpereCurrent :> Real {
		attribute unitSymbol : String = "A";
	}

	attribute def PurityFraction :> Real {
		attribute unitSymbol : String = "1";
		attribute lowerBound : Real = 0.0;
		attribute upperBound : Real = 1.0;
	}

	attribute def ReliabilityFraction :> Real {
		attribute unitSymbol : String = "1";
		attribute lowerBound : Real = 0.0;
		attribute upperBound : Real = 1.0;
	}

	attribute def CountRate :> Real {
		attribute unitSymbol : String = "events/s";
	}

	attribute def PressurePascal :> Real {
		attribute unitSymbol : String = "Pa";
	}

	enum def SystemModeKind {
		enum offline;
		enum standby;
		enum calibrating;
		enum armed;
		enum synthesizing;
		enum recoveringProduct;
		enum safeShutdown;
		enum faultContainment;
	}

	enum def CommandKind {
		enum powerOn;
		enum calibrate;
		enum arm;
		enum startSynthesis;
		enum pause;
		enum recoverProduct;
		enum shutdown;
		enum emergencyStop;
	}

	enum def SafetyStateKind {
		enum nominal;
		enum caution;
		enum interlockOpen;
		enum radiationHigh;
		enum thermalLimit;
		enum vacuumLost;
		enum magneticQuench;
		enum containedFault;
	}

	enum def ParticleKind {
		enum proton;
		enum neutron;
		enum alpha;
		enum electron;
		enum positron;
		enum ion;
		enum gammaPhoton;
		enum neutrino;
	}

	enum def TargetIsotopeKind {
		enum boron11;
		enum carbon12;
		enum nitrogen14;
		enum oxygen16;
		enum silicon28;
		enum iron56;
		enum molybdenum99;
		enum technetium99m;
		enum xenon129;
	}

	enum def ProductDispositionKind {
		enum certifiedProduct;
		enum recycleFeedstock;
		enum containedWaste;
		enum diagnosticSample;
	}

	item def IsotopeIdentity {
		attribute isotope : TargetIsotopeKind;
		attribute protonNumber : Integer;
		attribute neutronNumber : Integer;
		attribute massNumber : Integer;
	}

	item def Nucleus {
		attribute identity : IsotopeIdentity;
		attribute bindingEnergy : MegaElectronVoltEnergy;
		attribute spinState : String;
		attribute chargeState : Integer;
	}

	item def IonBeam {
		attribute particle : ParticleKind = ParticleKind::ion;
		attribute meanKineticEnergy : MegaElectronVoltEnergy;
		attribute energySpread : MegaElectronVoltEnergy;
		attribute beamDiameter : NanometerLength;
		attribute pulseWidth : AttosecondTime;
		attribute particleRate : CountRate;
		attribute chargeCurrent : AmpereCurrent;
	}

	item def FemtoFieldPulse {
		attribute peakMagneticFluxDensity : TeslaFluxDensity;
		attribute equivalentInteractionEnergy : MegaElectronVoltEnergy;
		attribute interactionRadius : FemtometerLength;
		attribute pulseDuration : ZeptosecondTime;
		attribute phaseCode : String;
		attribute repetitionRate : CountRate;
	}

	item def TargetNucleiPacket {
		attribute sourceIsotope : IsotopeIdentity;
		attribute packetRadius : NanometerLength;
		attribute arealDensity : Real;
		attribute temperature : KelvinTemperature;
		attribute confinementRadius : FemtometerLength;
	}

	item def ReactionTelemetry {
		attribute detectedGammaRate : CountRate;
		attribute detectedNeutronRate : CountRate;
		attribute inferredInteractionRadius : FemtometerLength;
		attribute productPurityEstimate : PurityFraction;
		attribute chamberDoseRate : SievertPerHourDoseRate;
		attribute chamberTemperature : KelvinTemperature;
		attribute vacuumPressure : PressurePascal;
	}

	item def IsotopeBatch {
		attribute productIsotope : IsotopeIdentity;
		attribute purity : PurityFraction;
		attribute disposition : ProductDispositionKind;
		attribute residualDoseRate : SievertPerHourDoseRate;
		attribute batchIdentifier : String;
	}

	item def ShieldedRadiation {
		attribute gammaDoseRate : SievertPerHourDoseRate;
		attribute neutronDoseRate : SievertPerHourDoseRate;
		attribute leakageDoseRate : SievertPerHourDoseRate;
	}

	item def ThermalFluid {
		attribute inletTemperature : KelvinTemperature;
		attribute outletTemperature : KelvinTemperature;
		attribute heatRemoved : WattPower;
	}

	item def ElectricalPower {
		attribute voltage : VoltPotential;
		attribute current : AmpereCurrent;
		attribute power : WattPower;
	}

	item def ControlCommand {
		attribute kind : CommandKind;
		attribute authorizationCode : String;
		attribute requestedProduct : TargetIsotopeKind;
		attribute requestedPurity : PurityFraction;
	}

	item def SynthesisRecipe {
		attribute targetProduct : TargetIsotopeKind;
		attribute feedstock : TargetIsotopeKind;
		attribute nominalInteractionRadius : FemtometerLength;
		attribute nominalPulseEnergy : MegaElectronVoltEnergy;
		attribute nominalPulseDuration : ZeptosecondTime;
		attribute pulseCount : Integer;
		attribute requiredPurity : PurityFraction;
	}

	item def HealthStatus {
		attribute mode : SystemModeKind;
		attribute safetyState : SafetyStateKind;
		attribute readyForSynthesis : Boolean;
		attribute interlocksClosed : Boolean;
		attribute reliabilityEstimate : ReliabilityFraction;
	}

	port def ElectricalPowerPort {
		in item power : ElectricalPower;
	}

	port def CommandPort {
		in item command : ControlCommand;
	}

	port def StatusPort {
		out item status : HealthStatus;
	}

	port def RecipePort {
		in item recipe : SynthesisRecipe;
	}

	port def IonBeamOutPort {
		out item beam : IonBeam;
	}

	port def IonBeamInPort {
		in item beam : IonBeam;
	}

	port def FemtoPulseOutPort {
		out item pulse : FemtoFieldPulse;
	}

	port def FemtoPulseInPort {
		in item pulse : FemtoFieldPulse;
	}

	port def TargetPacketOutPort {
		out item packet : TargetNucleiPacket;
	}

	port def TargetPacketInPort {
		in item packet : TargetNucleiPacket;
	}

	port def TelemetryOutPort {
		out item telemetry : ReactionTelemetry;
	}

	port def TelemetryInPort {
		in item telemetry : ReactionTelemetry;
	}

	port def ProductOutPort {
		out item product : IsotopeBatch;
	}

	port def ProductInPort {
		in item product : IsotopeBatch;
	}

	port def RadiationOutPort {
		out item radiation : ShieldedRadiation;
	}

	port def RadiationInPort {
		in item radiation : ShieldedRadiation;
	}

	port def CoolantInPort {
		in item coolant : ThermalFluid;
	}

	port def CoolantOutPort {
		out item coolant : ThermalFluid;
	}

	part def SupervisoryController {
		attribute processorRedundancy : Integer = 3;
		attribute commandLatency : AttosecondTime = 500000.0;
		attribute mode : SystemModeKind = SystemModeKind::standby;
		attribute safetyState : SafetyStateKind = SafetyStateKind::nominal;

		port operatorCommand : CommandPort;
		port recipeIn : RecipePort;
		port telemetryIn : TelemetryInPort;
		port chamberStatusIn : TelemetryInPort;
		port actuatorCommand : CommandPort;
		port ionCommand : CommandPort;
		port trapCommand : CommandPort;
		port separatorCommand : CommandPort;
		port statusOut : StatusPort;
	}

	part def HighStabilityPowerUnit {
		attribute maxOutputPower : WattPower = 250000.0;
		attribute busVoltage : VoltPotential = 48000.0;
		attribute currentLimit : AmpereCurrent = 5.2;
		attribute rippleFraction : Real = 0.00001;

		port facilityPower : ElectricalPowerPort;
		port ionSourcePower : ElectricalPowerPort;
		port actuatorPower : ElectricalPowerPort;
		port trapPower : ElectricalPowerPort;
		port detectorPower : ElectricalPowerPort;
		port controllerPower : ElectricalPowerPort;
	}

	part def IsotopicFeedstockVault {
		attribute inventoryTemperature : KelvinTemperature = 90.0;
		attribute feedstockPurity : PurityFraction = 0.999;
		attribute maximumPacketRadius : NanometerLength = 25.0;

		port targetPacketOut : TargetPacketOutPort;
		port vaultCommand : CommandPort;
		port vaultStatus : StatusPort;
	}

	part def CoherentIonSource {
		attribute nominalBeamEnergy : MegaElectronVoltEnergy = 120.0;
		attribute nominalEnergySpread : MegaElectronVoltEnergy = 0.015;
		attribute nominalBeamDiameter : NanometerLength = 1.8;
		attribute pulseWidth : AttosecondTime = 25.0;
		attribute particleRate : CountRate = 1.0e9;

		port powerIn : ElectricalPowerPort;
		port commandIn : CommandPort;
		port statusOut : StatusPort;
		port beamOut : IonBeamOutPort;
	}

	part def BeamPhaseConditioner {
		attribute phaseStability : Real = 0.99999;
		attribute focusingAperture : NanometerLength = 0.7;
		attribute maximumEnergySpreadOut : MegaElectronVoltEnergy = 0.005;

		port beamIn : IonBeamInPort;
		port commandIn : CommandPort;
		port beamOut : IonBeamOutPort;
		port statusOut : StatusPort;
	}

	part def FemtometerTargetTrap {
		attribute confinementRadius : FemtometerLength = 8.0;
		attribute trapTemperature : KelvinTemperature = 0.020;
		attribute magneticFieldBias : TeslaFluxDensity = 35.0;
		attribute vacuumPressure : PressurePascal = 1.0e-11;

		port powerIn : ElectricalPowerPort;
		port commandIn : CommandPort;
		port targetPacketIn : TargetPacketInPort;
		port confinedPacketOut : TargetPacketOutPort;
		port statusOut : StatusPort;
	}

	part def FemtoFieldActuator {
		attribute designInteractionRadius : FemtometerLength = 5.0;
		attribute peakMagneticFluxDensity : TeslaFluxDensity = 1200.0;
		attribute pulseEnergy : MegaElectronVoltEnergy = 180.0;
		attribute pulseDuration : ZeptosecondTime = 80.0;
		attribute phaseResolution : Real = 0.000001;

		port powerIn : ElectricalPowerPort;
		port commandIn : CommandPort;
		port pulseOut : FemtoPulseOutPort;
		port statusOut : StatusPort;
	}

	part def NuclearInteractionChamber {
		attribute chamberVacuumPressure : PressurePascal = 5.0e-12;
		attribute interactionZoneRadius : FemtometerLength = 8.0;
		attribute wallTemperature : KelvinTemperature = 18.0;
		attribute internalDoseRate : SievertPerHourDoseRate = 0.0;

		port beamIn : IonBeamInPort;
		port femtoPulseIn : FemtoPulseInPort;
		port targetPacketIn : TargetPacketInPort;
		port telemetryOut : TelemetryOutPort;
		port productOut : ProductOutPort;
		port radiationOut : RadiationOutPort;
		port coolantIn : CoolantInPort;
		port coolantOut : CoolantOutPort;
	}

	part def ReactionProductSeparator {
		attribute separationSelectivity : PurityFraction = 0.995;
		attribute productHoldTemperature : KelvinTemperature = 120.0;
		attribute maximumResidualDoseRate : SievertPerHourDoseRate = 0.000001;

		port productIn : ProductInPort;
		port commandIn : CommandPort;
		port certifiedProductOut : ProductOutPort;
		port recyclePacketOut : TargetPacketOutPort;
		port statusOut : StatusPort;
	}

	part def MultiChannelParticleDetector {
		attribute gammaDetectionEfficiency : PurityFraction = 0.985;
		attribute neutronDetectionEfficiency : PurityFraction = 0.960;
		attribute timingResolution : ZeptosecondTime = 100000.0;
		attribute saturationCountRate : CountRate = 1.0e12;

		port powerIn : ElectricalPowerPort;
		port radiationIn : RadiationInPort;
		port telemetryOut : TelemetryOutPort;
		port statusOut : StatusPort;
	}

	part def GradedRadiationShield {
		attribute equivalentLeadThickness : NanometerLength = 800000000.0;
		attribute hydrogenousLayerThickness : NanometerLength = 400000000.0;
		attribute maximumExternalDoseRate : SievertPerHourDoseRate = 0.0000005;

		port radiationIn : RadiationInPort;
		port radiationOut : RadiationOutPort;
		port statusOut : StatusPort;
	}

	part def CryogenicThermalController {
		attribute nominalSupplyTemperature : KelvinTemperature = 4.0;
		attribute maximumHeatRemoval : WattPower = 75000.0;
		attribute controlStability : KelvinTemperature = 0.002;

		port chamberCoolantOut : CoolantOutPort;
		port chamberCoolantIn : CoolantInPort;
		port trapCoolantOut : CoolantOutPort;
		port trapCoolantIn : CoolantInPort;
		port statusOut : StatusPort;
	}

	part def DataRecorder {
		attribute retainedMissionRecords : Integer = 1000000;
		attribute sampleRate : CountRate = 1.0e8;
		attribute tamperEvident : Boolean = true;

		port telemetryIn : TelemetryInPort;
		port statusIn : StatusPort;
	}

	action def ValidateSynthesisRecipe {
		in item recipe : SynthesisRecipe;
		out valid : Boolean;

		constraint validRadius {
			recipe.nominalInteractionRadius <= 20.0
		}

		constraint validEnergy {
			recipe.nominalPulseEnergy >= 1.0 and recipe.nominalPulseEnergy <= 500.0
		}

		constraint validPurity {
			recipe.requiredPurity >= 0.900 and recipe.requiredPurity <= 0.9999
		}
	}

	action def CalibrateFemtoInteractionZone {
		in item telemetry : ReactionTelemetry;
		out calibratedRadius : FemtometerLength;

		action measureBackground;
		action alignTrap;
		action phaseLockActuator;
		action verifyRadius;

		first start then measureBackground;
		then alignTrap;
		then phaseLockActuator;
		then verifyRadius;
		then done;
	}

	action def ExecuteFemtoNuclearSynthesis {
		in item recipe : SynthesisRecipe;
		in item target : TargetNucleiPacket;
		in item conditionedBeam : IonBeam;
		in item femtoPulse : FemtoFieldPulse;
		out item product : IsotopeBatch;
		out item telemetry : ReactionTelemetry;

		action confineTarget;
		action injectBeam;
		action applyFemtoFieldPulse;
		action observeReactionProducts;
		action estimateProductPurity;
		action releaseProductBatch;

		first start then confineTarget;
		then injectBeam;
		then applyFemtoFieldPulse;
		then observeReactionProducts;
		then estimateProductPurity;
		then releaseProductBatch;
		then done;
	}

	action def RecoverAndCertifyProduct {
		in item rawProduct : IsotopeBatch;
		out item certifiedProduct : IsotopeBatch;
		out item recycleFeedstock : TargetNucleiPacket;

		action routeByChargeMass;
		action measureResidualRadiation;
		action certifyPurity;
		action sealProductContainer;

		first start then routeByChargeMass;
		then measureResidualRadiation;
		then certifyPurity;
		then sealProductContainer;
		then done;
	}

	action def PerformSafeShutdown {
		in item status : HealthStatus;
		out shutdownComplete : Boolean;

		action inhibitIonSource;
		action dischargeFemtoActuator;
		action parkTargetTrap;
		action floodShieldMonitor;
		action preserveTelemetry;

		first start then inhibitIonSource;
		then dischargeFemtoActuator;
		then parkTargetTrap;
		then floodShieldMonitor;
		then preserveTelemetry;
		then done;
	}

	state def FemtoAssemblerOperationalStates {
		entry; then offline;

		state offline;
		state standby;
		state calibrating;
		state armed;
		state synthesizing;
		state recoveringProduct;
		state safeShutdown;
		state faultContainment;

		transition powerOn
			first offline
			accept ControlCommand
			if command.kind == CommandKind::powerOn
			then standby;

		transition beginCalibration
			first standby
			accept ControlCommand
			if command.kind == CommandKind::calibrate
			then calibrating;

		transition calibrationComplete
			first calibrating
			if safetyState == SafetyStateKind::nominal
			then armed;

		transition beginSynthesis
			first armed
			accept ControlCommand
			if command.kind == CommandKind::startSynthesis
			then synthesizing;

		transition completeSynthesis
			first synthesizing
			if safetyState == SafetyStateKind::nominal
			then recoveringProduct;

		transition productRecovered
			first recoveringProduct
			then standby;

		transition requestedShutdown
			first standby
			accept ControlCommand
			if command.kind == CommandKind::shutdown
			then safeShutdown;

		transition emergencyStopFromArmed
			first armed
			accept ControlCommand
			if command.kind == CommandKind::emergencyStop
			then faultContainment;

		transition emergencyStopFromSynthesis
			first synthesizing
			accept ControlCommand
			if command.kind == CommandKind::emergencyStop
			then faultContainment;

		transition radiationFault
			first synthesizing
			if safetyState == SafetyStateKind::radiationHigh
			then faultContainment;

		transition thermalFault
			first synthesizing
			if safetyState == SafetyStateKind::thermalLimit
			then faultContainment;

		transition containedFaultShutdown
			first faultContainment
			then safeShutdown;
	}

	part def FemtoNuclearAssembler {
		attribute systemName : String = "FemtoForge Controlled Nuclear Reconfiguration System";
		attribute technologyBasis : String = "Femtotechnology: controlled engineering of nuclear-scale interactions at femtometer characteristic dimensions.";
		attribute primaryFunction : String = "Confine selected nuclei, apply coherent femtometer-scale field pulses, and steer nuclear rearrangement to produce specified isotope batches while containing radiation and preserving traceable telemetry.";
		attribute designInteractionRadius : FemtometerLength = 8.0;
		attribute maximumAllowedInteractionRadius : FemtometerLength = 20.0;
		attribute nominalPulseEnergy : MegaElectronVoltEnergy = 180.0;
		attribute nominalPulseDuration : ZeptosecondTime = 80.0;
		attribute minimumProductPurity : PurityFraction = 0.950;
		attribute maximumExternalDoseRate : SievertPerHourDoseRate = 0.0000005;
		attribute mode : SystemModeKind = SystemModeKind::standby;

		port operatorCommand : CommandPort;
		port externalRecipe : RecipePort;
		port facilityPower : ElectricalPowerPort;
		port certifiedProductOut : ProductOutPort;
		port externalRadiationMonitor : RadiationOutPort;
		port statusOut : StatusPort;

		part controller : SupervisoryController;
		part powerUnit : HighStabilityPowerUnit;
		part feedstockVault : IsotopicFeedstockVault;
		part ionSource : CoherentIonSource;
		part beamConditioner : BeamPhaseConditioner;
		part targetTrap : FemtometerTargetTrap;
		part femtoActuator : FemtoFieldActuator;
		part interactionChamber : NuclearInteractionChamber;
		part productSeparator : ReactionProductSeparator;
		part particleDetector : MultiChannelParticleDetector;
		part radiationShield : GradedRadiationShield;
		part thermalController : CryogenicThermalController;
		part dataRecorder : DataRecorder;

		perform action validateRecipe : ValidateSynthesisRecipe;
		perform action calibrateZone : CalibrateFemtoInteractionZone;
		perform action synthesizeIsotope : ExecuteFemtoNuclearSynthesis;
		perform action recoverProduct : RecoverAndCertifyProduct;
		perform action shutdownSafely : PerformSafeShutdown;

		state operationalStates : FemtoAssemblerOperationalStates;

		connect operatorCommand to controller.operatorCommand;
		connect externalRecipe to controller.recipeIn;
		connect facilityPower to powerUnit.facilityPower;
		connect controller.statusOut to statusOut;

		connect powerUnit.controllerPower to controller.operatorCommand;
		connect powerUnit.ionSourcePower to ionSource.powerIn;
		connect powerUnit.actuatorPower to femtoActuator.powerIn;
		connect powerUnit.trapPower to targetTrap.powerIn;
		connect powerUnit.detectorPower to particleDetector.powerIn;

		connect controller.ionCommand to ionSource.commandIn;
		connect controller.ionCommand to beamConditioner.commandIn;
		connect controller.trapCommand to feedstockVault.vaultCommand;
		connect controller.trapCommand to targetTrap.commandIn;
		connect controller.actuatorCommand to femtoActuator.commandIn;
		connect controller.separatorCommand to productSeparator.commandIn;

		connect feedstockVault.targetPacketOut to targetTrap.targetPacketIn;
		connect ionSource.beamOut to beamConditioner.beamIn;
		connect beamConditioner.beamOut to interactionChamber.beamIn;
		connect targetTrap.confinedPacketOut to interactionChamber.targetPacketIn;
		connect femtoActuator.pulseOut to interactionChamber.femtoPulseIn;

		connect interactionChamber.productOut to productSeparator.productIn;
		connect productSeparator.certifiedProductOut to certifiedProductOut;
		connect productSeparator.recyclePacketOut to targetTrap.targetPacketIn;

		connect interactionChamber.radiationOut to particleDetector.radiationIn;
		connect interactionChamber.radiationOut to radiationShield.radiationIn;
		connect radiationShield.radiationOut to externalRadiationMonitor;

		connect interactionChamber.telemetryOut to controller.telemetryIn;
		connect particleDetector.telemetryOut to controller.chamberStatusIn;
		connect interactionChamber.telemetryOut to dataRecorder.telemetryIn;
		connect controller.statusOut to dataRecorder.statusIn;

		connect thermalController.chamberCoolantOut to interactionChamber.coolantIn;
		connect interactionChamber.coolantOut to thermalController.chamberCoolantIn;
	}

	constraint def InteractionRadiusConstraint {
		in radius : FemtometerLength;
		in limit : FemtometerLength;

		require radius <= limit;
	}

	constraint def PulseEnergyConstraint {
		in energy : MegaElectronVoltEnergy;

		require energy >= 1.0 and energy <= 500.0;
	}

	constraint def ProductPurityConstraint {
		in purity : PurityFraction;
		in minimumPurity : PurityFraction;

		require purity >= minimumPurity;
	}

	constraint def ExternalDoseConstraint {
		in leakageDoseRate : SievertPerHourDoseRate;
		in maximumDoseRate : SievertPerHourDoseRate;

		require leakageDoseRate <= maximumDoseRate;
	}

	requirement def PrimaryFunctionRequirement {
		subject system : FemtoNuclearAssembler;

		doc /* The femtotechnology system shall perform controlled nuclear-scale reconfiguration by confining nuclei within a femtometer-class interaction zone and applying coherent femtofield pulses to produce specified isotope batches. */

		require constraint {
			system.designInteractionRadius <= system.maximumAllowedInteractionRadius
		}
	}

	requirement def FemtometerScaleOperationRequirement {
		subject system : FemtoNuclearAssembler;

		doc /* The active interaction zone shall remain at or below 20 femtometers during synthesis to demonstrate femtotechnology-scale operation. */

		require constraint {
			system.designInteractionRadius <= 20.0
		}
	}

	requirement def ControlledPulseRequirement {
		subject system : FemtoNuclearAssembler;

		doc /* The field actuator shall deliver nuclear interaction pulses with energy between 1 MeV and 500 MeV and duration no greater than 100 zeptoseconds for nominal synthesis. */

		require constraint {
			system.nominalPulseEnergy >= 1.0 and system.nominalPulseEnergy <= 500.0 and system.nominalPulseDuration <= 100.0
		}
	}

	requirement def ProductQualityRequirement {
		subject system : FemtoNuclearAssembler;

		doc /* Certified product batches shall meet or exceed the minimum isotope purity required by the synthesis recipe and system safety case. */

		require constraint {
			system.minimumProductPurity >= 0.950
		}
	}

	requirement def RadiationContainmentRequirement {
		subject system : FemtoNuclearAssembler;

		doc /* Radiation leaving the shield boundary shall not exceed the specified external dose-rate limit during normal synthesis and product recovery. */

		require constraint {
			system.maximumExternalDoseRate <= 0.0000005
		}
	}

	requirement def TraceableAutonomousControlRequirement {
		subject system : FemtoNuclearAssembler;

		doc /* The system shall autonomously validate recipes, calibrate the femtometer interaction zone, execute synthesis, recover products, and record telemetry for each mission. */

		require constraint {
			system.controller.processorRedundancy >= 3 and system.dataRecorder.tamperEvident == true
		}
	}

	part femtoForge : FemtoNuclearAssembler {
		attribute systemName = "FemtoForge-1";
		attribute designInteractionRadius = 8.0;
		attribute nominalPulseEnergy = 180.0;
		attribute nominalPulseDuration = 80.0;
		attribute minimumProductPurity = 0.950;
		attribute maximumExternalDoseRate = 0.0000005;
	}

	requirement primaryFunction : PrimaryFunctionRequirement {
		subject system = femtoForge;
	}

	requirement femtometerScaleOperation : FemtometerScaleOperationRequirement {
		subject system = femtoForge;
	}

	requirement controlledPulse : ControlledPulseRequirement {
		subject system = femtoForge;
	}

	requirement productQuality : ProductQualityRequirement {
		subject system = femtoForge;
	}

	requirement radiationContainment : RadiationContainmentRequirement {
		subject system = femtoForge;
	}

	requirement traceableControl : TraceableAutonomousControlRequirement {
		subject system = femtoForge;
	}

	satisfy primaryFunction by femtoForge;
	satisfy femtometerScaleOperation by femtoForge;
	satisfy controlledPulse by femtoForge;
	satisfy productQuality by femtoForge;
	satisfy radiationContainment by femtoForge;
	satisfy traceableControl by femtoForge;
}
