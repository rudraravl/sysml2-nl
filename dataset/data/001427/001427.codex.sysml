package FemtotechnologySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Femtometer : LengthValue {
        :>> unit = SI::femto metre;
    }

    attribute def Zeptosecond : TimeValue {
        :>> unit = SI::zepto second;
    }

    attribute def MegaElectronVolt : EnergyValue {
        :>> unit = SI::mega electronvolt;
    }

    attribute def TeslaField : MagneticFluxDensityValue {
        :>> unit = SI::tesla;
    }

    item def NuclearIsomerFeedstock {
        attribute isotopeName : String;
        attribute massNumber : Integer;
        attribute excitedStateEnergy : MegaElectronVolt;
        attribute halfLife : TimeValue;
        attribute confinementRadius : Femtometer;
    }

    item def GammaPhotonPulse {
        attribute photonEnergy : MegaElectronVolt;
        attribute pulseDuration : Zeptosecond;
        attribute photonCount : Integer;
        attribute coherenceRatio : Real;
    }

    item def NeutronCatalystPacket {
        attribute neutronCount : Integer;
        attribute kineticEnergy : MegaElectronVolt;
        attribute spinPolarization : Real;
    }

    item def StabilizedNuclearCluster {
        attribute nucleonCount : Integer;
        attribute bindingEnergy : MegaElectronVolt;
        attribute radius : Femtometer;
        attribute stabilityMargin : Real;
    }

    item def WasteRadiation {
        attribute doseRate : Real;
        attribute spectrumPeakEnergy : MegaElectronVolt;
    }

    item def ControlCommand {
        attribute targetEnergy : MegaElectronVolt;
        attribute targetFieldStrength : TeslaField;
        attribute requestedMode : String;
    }

    item def DiagnosticReport {
        attribute measuredRadius : Femtometer;
        attribute measuredBindingEnergy : MegaElectronVolt;
        attribute containmentIntegrity : Real;
        attribute radiationLeakage : Real;
    }

    port def FeedstockInputPort {
        in item feedstock : NuclearIsomerFeedstock;
    }

    port def PhotonPulsePort {
        out item pulse : GammaPhotonPulse;
    }

    port def NeutronPacketPort {
        out item packet : NeutronCatalystPacket;
    }

    port def ClusterTransferPort {
        out item cluster : StabilizedNuclearCluster;
    }

    port def RadiationExhaustPort {
        out item waste : WasteRadiation;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }

    action def AcceptFeedstock {
        in item feedstock : NuclearIsomerFeedstock;
        out item preparedFeedstock : NuclearIsomerFeedstock;
    }

    action def CompressNuclearWavefunction {
        in item preparedFeedstock : NuclearIsomerFeedstock;
        in attribute targetRadius : Femtometer;
        out item confinedFeedstock : NuclearIsomerFeedstock;
    }

    action def GenerateCoherentGammaPulse {
        in attribute photonEnergy : MegaElectronVolt;
        in attribute duration : Zeptosecond;
        out item pulse : GammaPhotonPulse;
    }

    action def InjectSpinAlignedNeutrons {
        in attribute neutronCount : Integer;
        in attribute kineticEnergy : MegaElectronVolt;
        out item packet : NeutronCatalystPacket;
    }

    action def CatalyzeNuclearAssembly {
        in item confinedFeedstock : NuclearIsomerFeedstock;
        in item pulse : GammaPhotonPulse;
        in item packet : NeutronCatalystPacket;
        out item cluster : StabilizedNuclearCluster;
        out item waste : WasteRadiation;
    }

    action def VerifyClusterStability {
        in item cluster : StabilizedNuclearCluster;
        out attribute stable : Boolean;
        out item report : DiagnosticReport;
    }

    action def QuenchReaction {
        in item waste : WasteRadiation;
        out item reducedWaste : WasteRadiation;
    }

    state def ReactorOperatingState {
        entry action initializeTelemetry;
        state Off;
        state Standby;
        state FeedstockLoaded;
        state FemtoConfinement;
        state PhotonCatalysis;
        state ClusterExtraction;
        state RadiationQuench;
        state FaultIsolation;

        initial then Off;

        transition Off_to_Standby
            first Off
            accept ControlCommand
            if command.requestedMode == "standby"
            then Standby;

        transition Standby_to_FeedstockLoaded
            first Standby
            accept NuclearIsomerFeedstock
            then FeedstockLoaded;

        transition FeedstockLoaded_to_FemtoConfinement
            first FeedstockLoaded
            accept ControlCommand
            if command.requestedMode == "synthesize"
            then FemtoConfinement;

        transition FemtoConfinement_to_PhotonCatalysis
            first FemtoConfinement
            if confinementIntegrity >= 0.999
            then PhotonCatalysis;

        transition PhotonCatalysis_to_ClusterExtraction
            first PhotonCatalysis
            if stabilityMargin >= 0.95
            then ClusterExtraction;

        transition ClusterExtraction_to_RadiationQuench
            first ClusterExtraction
            then RadiationQuench;

        transition RadiationQuench_to_Standby
            first RadiationQuench
            if radiationLeakage <= 0.000001
            then Standby;

        transition Any_to_FaultIsolation
            first Off, Standby, FeedstockLoaded, FemtoConfinement, PhotonCatalysis, ClusterExtraction, RadiationQuench
            if radiationLeakage > 0.000001 or containmentIntegrity < 0.995
            then FaultIsolation;

        transition FaultIsolation_to_Standby
            first FaultIsolation
            accept ControlCommand
            if command.requestedMode == "reset"
            then Standby;
    }

    part def FemtoScaleContainmentLattice {
        attribute innerRadius : Femtometer = 12 [SI::femto metre];
        attribute fieldStrength : TeslaField = 900000000 [SI::tesla];
        attribute containmentIntegrity : Real;
        port feedstockIn : FeedstockInputPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def GammaCoherenceDriver {
        attribute nominalPhotonEnergy : MegaElectronVolt = 7.8 [SI::mega electronvolt];
        attribute nominalPulseDuration : Zeptosecond = 200 [SI::zepto second];
        attribute coherenceRatio : Real = 0.9995;
        port pulseOut : PhotonPulsePort;

        perform action generatePulse : GenerateCoherentGammaPulse {
            in photonEnergy = nominalPhotonEnergy;
            in duration = nominalPulseDuration;
        }
    }

    part def NeutronSpinInjector {
        attribute nominalNeutronCount : Integer = 4;
        attribute nominalKineticEnergy : MegaElectronVolt = 0.45 [SI::mega electronvolt];
        attribute spinPolarization : Real = 0.998;
        port neutronOut : NeutronPacketPort;

        perform action injectNeutrons : InjectSpinAlignedNeutrons {
            in neutronCount = nominalNeutronCount;
            in kineticEnergy = nominalKineticEnergy;
        }
    }

    part def FemtometerAssemblyCore {
        attribute targetAssemblyRadius : Femtometer = 6 [SI::femto metre];
        attribute reactionWindow : Zeptosecond = 500 [SI::zepto second];
        attribute bindingEnergyGain : MegaElectronVolt;
        port feedstockIn : FeedstockInputPort;
        port photonIn : PhotonPulsePort;
        port neutronIn : NeutronPacketPort;
        port clusterOut : ClusterTransferPort;
        port wasteOut : RadiationExhaustPort;

        perform action acceptFeedstock : AcceptFeedstock;
        perform action compress : CompressNuclearWavefunction {
            in targetRadius = targetAssemblyRadius;
        }
        perform action assemble : CatalyzeNuclearAssembly;
    }

    part def ClusterStabilizer {
        attribute minimumStabilityMargin : Real = 0.95;
        attribute extractionFieldStrength : TeslaField = 250000000 [SI::tesla];
        port clusterIn : ClusterTransferPort;
        port productOut : ClusterTransferPort;
        port diagnosticOut : DiagnosticPort;

        perform action verify : VerifyClusterStability;
    }

    part def RadiationQuenchShield {
        attribute maximumLeakageFraction : Real = 0.000001;
        attribute absorberArealDensity : Real = 1200;
        port wasteIn : RadiationExhaustPort;
        port exhaustOut : RadiationExhaustPort;

        perform action quench : QuenchReaction;
    }

    part def SupervisoryController {
        attribute commandedMode : String = "standby";
        attribute minimumContainmentIntegrity : Real = 0.995;
        attribute maximumRadiationLeakage : Real = 0.000001;
        port commandIn : CommandPort;
        port diagnosticIn : DiagnosticPort;
        port commandOut : CommandPort;

        exhibit state operatingState : ReactorOperatingState;
    }

    part def FemtoNuclearAssembler {
        doc /* A femtotechnology-based system that manipulates nuclear-scale matter at femtometer dimensions to assemble stabilized nuclear clusters. Its primary function is high-level controlled synthesis: it accepts excited nuclear-isomer feedstock, confines it with femtometer-scale fields, applies coherent gamma photons and spin-aligned neutron packets, and extracts a stabilized nuclear cluster while quenching waste radiation. */

        attribute nominalSpatialPrecision : Femtometer = 1 [SI::femto metre];
        attribute nominalTemporalPrecision : Zeptosecond = 100 [SI::zepto second];
        attribute maximumProductBindingEnergy : MegaElectronVolt = 1200 [SI::mega electronvolt];

        port feedstockInput : FeedstockInputPort;
        port productOutput : ClusterTransferPort;
        port wasteOutput : RadiationExhaustPort;
        port commandInput : CommandPort;
        port diagnosticOutput : DiagnosticPort;

        part containment : FemtoScaleContainmentLattice;
        part gammaDriver : GammaCoherenceDriver;
        part neutronInjector : NeutronSpinInjector;
        part assemblyCore : FemtometerAssemblyCore;
        part stabilizer : ClusterStabilizer;
        part quenchShield : RadiationQuenchShield;
        part controller : SupervisoryController;

        connect feedstockInput to containment.feedstockIn;
        connect containment.feedstockIn to assemblyCore.feedstockIn;
        connect gammaDriver.pulseOut to assemblyCore.photonIn;
        connect neutronInjector.neutronOut to assemblyCore.neutronIn;
        connect assemblyCore.clusterOut to stabilizer.clusterIn;
        connect stabilizer.productOut to productOutput;
        connect assemblyCore.wasteOut to quenchShield.wasteIn;
        connect quenchShield.exhaustOut to wasteOutput;
        connect commandInput to controller.commandIn;
        connect controller.commandOut to containment.diagnosticOut;
        connect containment.diagnosticOut to controller.diagnosticIn;
        connect stabilizer.diagnosticOut to controller.diagnosticIn;
        connect controller.diagnosticIn to diagnosticOutput;

        perform action primarySynthesis {
            first start;
            then accept : AcceptFeedstock;
            then confine : CompressNuclearWavefunction {
                in targetRadius = assemblyCore.targetAssemblyRadius;
            }
            then pulse : GenerateCoherentGammaPulse {
                in photonEnergy = gammaDriver.nominalPhotonEnergy;
                in duration = gammaDriver.nominalPulseDuration;
            }
            then inject : InjectSpinAlignedNeutrons {
                in neutronCount = neutronInjector.nominalNeutronCount;
                in kineticEnergy = neutronInjector.nominalKineticEnergy;
            }
            then catalyze : CatalyzeNuclearAssembly;
            then verify : VerifyClusterStability;
            then quench : QuenchReaction;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The femtotechnology system shall synthesize stabilized nuclear clusters from nuclear-isomer feedstock by controlling femtometer-scale confinement, coherent gamma excitation, neutron spin injection, stabilization, and radiation quenching. */
        subject assembler : FemtoNuclearAssembler;
        require constraint {
            assembler.nominalSpatialPrecision <= 1 [SI::femto metre] and
            assembler.nominalTemporalPrecision <= 100 [SI::zepto second]
        }
    }

    requirement def ContainmentRequirement {
        doc /* The system shall maintain nuclear confinement integrity during synthesis. */
        subject containment : FemtoScaleContainmentLattice;
        require constraint {
            containment.containmentIntegrity >= 0.995
        }
    }

    requirement def CoherentExcitationRequirement {
        doc /* The gamma driver shall deliver coherent photon pulses suitable for controlled nuclear-state transitions. */
        subject driver : GammaCoherenceDriver;
        require constraint {
            driver.coherenceRatio >= 0.999 and
            driver.nominalPulseDuration <= 250 [SI::zepto second]
        }
    }

    requirement def ProductStabilityRequirement {
        doc /* The extracted nuclear cluster shall meet the minimum stability threshold before release. */
        subject stabilizer : ClusterStabilizer;
        require constraint {
            stabilizer.minimumStabilityMargin >= 0.95
        }
    }

    requirement def RadiationSafetyRequirement {
        doc /* Waste radiation leaving the system shall remain below the configured leakage fraction. */
        subject shield : RadiationQuenchShield;
        require constraint {
            shield.maximumLeakageFraction <= 0.000001
        }
    }

    satisfy PrimaryFunctionRequirement by FemtoNuclearAssembler;
    satisfy ContainmentRequirement by FemtoNuclearAssembler::containment;
    satisfy CoherentExcitationRequirement by FemtoNuclearAssembler::gammaDriver;
    satisfy ProductStabilityRequirement by FemtoNuclearAssembler::stabilizer;
    satisfy RadiationSafetyRequirement by FemtoNuclearAssembler::quenchShield;
}