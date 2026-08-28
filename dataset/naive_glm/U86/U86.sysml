package MerciRetrieverSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::millimetre as mm;
    import SI::centimetre as cm;
    import SI::metre as m;
    import SI::second as s;
    import SI::minute as min;
    import SI::kilopascal as kPa;
    import SI::pascal as Pa;
    import SI::millilitre as mL;
    import SI::litre as L;
    import SI::hertz as Hz;
    import SI::kilovolt as kV;
    import SI::volt as V;
    import SI::newton as N;
    import SI::milligram as mg;
    import SI::gram as g;
    import SI::degree_Celsius as degC;

    // =====================================================================
    // Value Types
    // =====================================================================

    type Length :> LengthValue;
    type Diameter :> LengthValue;
    type Time :> TimeValue;
    type Duration :> TimeValue;
    type Pressure :> PressureValue;
    type Volume :> VolumeValue;
    type VolumeFlowRate :> Real;
    type Force :> ForceValue;
    type Mass :> MassValue;
    type Temperature :> ThermodynamicTemperatureValue;
    type ElectricPotential :> ElectricPotentialValue;
    type Frequency :> FrequencyValue;

    enumeration def ProcedureStatus {
        valueType NotStarted;
        valueType GuideInserted;
        valueType MicroNavigating;
        valueType RetrieverAdvancing;
        valueType RetrieverDeployed;
        valueType Dwelling;
        valueType Withdrawing;
        valueType Assessing;
        valueType Reperfused;
        valueType Failed;
    }

    // =====================================================================
    // Item Definitions
    // =====================================================================

    item def BloodClot {
        attribute length : Length = 10 [mm];
        attribute consistency : Real = 0.6;
        attribute embolizationRisk : Real = 0.3;
        attribute captured : Boolean = false;
    }

    item def Blood {
        attribute flowRate : VolumeFlowRate = 0 [mL/s];
        attribute viscosity : Real = 1.0;
        attribute oxygenated : Boolean = true;
    }

    item def XRayBeam {
        attribute energy : ElectricPotential = 80 [kV];
        attribute intensity : Real = 1.0;
        attribute pulse : Boolean = true;
    }

    item def FluoroImage {
        attribute frameRate : Frequency = 30 [Hz];
        attribute resolutionX : Integer = 1024;
        attribute resolutionY : Integer = 1024;
        attribute live : Boolean = true;
        attribute timestamp : Time = 0 [s];
    }

    item def Saline {
        attribute volume : Volume = 500 [mL];
        attribute temperature : Temperature = 20 [degC];
        attribute sterile : Boolean = true;
    }

    item def Debris {
        attribute fragmentCount : Integer = 0;
        attribute mass : Mass = 0 [mg];
        attribute sourceClot : BloodClot;
        attribute captured : Boolean = false;
    }

    item def ControlCommand {
        attribute command : String;
        attribute parameter : String;
    }

    // =====================================================================
    // Port Definitions
    // =====================================================================

    port def VesselPort {
        in item blood : Blood;
        in item clot : BloodClot;
        out item aspirated : Debris;
    }

    port def LuminalPort {
        in item saline : Saline;
        out item toolFeed : Real[*];
    }

    port def RadiationPort {
        in item beam : XRayBeam;
    }

    port def ImagePort {
        out image : FluoroImage;
    }

    port def BeamPort {
        out beam : XRayBeam;
    }

    port def AspirationPort {
        out vacuum : Pressure;
        in matter : Debris;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : String;
    }

    // =====================================================================
    // Component Parts
    // =====================================================================

    part def FluoroscopySystem {
        attribute operational : Boolean = true;
        attribute frameRate : Frequency = 30 [Hz];
        attribute exposureEnergy : ElectricPotential = 80 [kV];
        attribute currentStatus : String = "off";
        port emission : BeamPort;
        port display : ImagePort;
        port ctrl : ControlPort;

        stateMachine operationStates {
            state Off;
            state Standby;
            state Imaging;
            transition off_to_standby from Off to Standby when ctrl.command.command == "power on";
            transition standby_to_imaging from Standby to Imaging when ctrl.command.command == "image";
            transition imaging_to_standby from Imaging to Standby when ctrl.command.command == "pause";
            transition standby_to_off from Standby to Off when ctrl.command.command == "power off";
        }
    }

    part def GuideCatheter {
        attribute innerDiameter : Diameter = 2.5 [mm];
        attribute outerDiameter : Diameter = 3.0 [mm];
        attribute usableLength : Length = 90 [cm];
        attribute inserted : Boolean = false;
        attribute currentStatus : String = "detached";
        port proximal : LuminalPort;
        port distal : LuminalPort;
        port vessel : VesselPort;
        port ctrl : ControlPort;

        stateMachine insertionStates {
            state Detached;
            state Inserting;
            state Positioned;
            transition detached_to_inserting from Detached to Inserting when ctrl.command.command == "insert";
            transition inserting_to_positioned from Inserting to Positioned when ctrl.command.command == "positioned";
            transition positioned_to_detached from Positioned to Detached when ctrl.command.command == "remove";
        }
    }

    part def Microcatheter {
        attribute innerDiameter : Diameter = 0.4 [mm];
        attribute outerDiameter : Diameter = 0.5 [mm];
        attribute usableLength : Length = 150 [cm];
        attribute position : Length = 0 [cm];
        attribute atClot : Boolean = false;
        attribute currentStatus : String = "at guide";
        port proximal : LuminalPort;
        port distal : LuminalPort;
        port ctrl : ControlPort;

        stateMachine navigationStates {
            state AtGuide;
            state Navigating;
            state AtClot;
            transition atGuide_to_navigating from AtGuide to Navigating when ctrl.command.command == "advance";
            transition navigating_to_atClot from Navigating to AtClot when ctrl.command.command == "arrived";
            transition atClot_to_atGuide from AtClot to AtGuide when ctrl.command.command == "retract";
        }
    }

    part def MerciRetrieverDevice {
        attribute loopCount : Integer = 5;
        attribute filamentDiameter : Diameter = 0.1 [mm];
        attribute deployedDiameter : Diameter = 3.0 [mm];
        attribute deployed : Boolean = false;
        attribute engagesClot : Boolean = false;
        attribute maxWithdrawForce : Force = 2.0 [N];
        attribute deliveryState : String = "stowed";
        port proximal : LuminalPort;
        port distal : LuminalPort;
        port ctrl : ControlPort;

        stateMachine deploymentStates {
            state Stowed;
            state Advancing;
            state Deployed;
            state Retracting;
            transition stowed_to_advancing from Stowed to Advancing when ctrl.command.command == "advance";
            transition advancing_to_deployed from Advancing to Deployed when ctrl.command.command == "deploy";
            transition deployed_to_retracting from Deployed to Retracting when ctrl.command.command == "withdraw";
            transition retracting_to_stowed from Retracting to Stowed when ctrl.command.command == "stow";
        }
    }

    part def AspirationPump {
        attribute maxVacuum : Pressure = -80 [kPa];
        attribute nominalVacuum : Pressure = -60 [kPa];
        attribute active : Boolean = false;
        attribute flowRate : VolumeFlowRate = 0 [mL/s];
        port output : AspirationPort;
        port ctrl : ControlPort;

        stateMachine aspirationStates {
            state Idle;
            state Aspirating;
            transition idle_to_aspirating from Idle to Aspirating when ctrl.command.command == "start";
            transition aspirating_to_idle from Aspirating to Idle when ctrl.command.command == "stop";
        }
    }

    part def Surgeon {
        attribute name : String = "Interventional Neuroradiologist";
        attribute attemptCount : Integer = 0;
        attribute maxAttempts : Integer = 3;
        attribute satisfied : Boolean = false;
        port ctrl : ControlPort;
        port view : ImagePort;
        port guideCmd : ControlPort;
        port microCmd : ControlPort;
        port retrieverCmd : ControlPort;
        port pumpCmd : ControlPort;
    }

    part def Patient {
        attribute vascularAccessPoint : String = "femoral artery";
        attribute targetVessel : String = "M1 segment MCA";
        attribute clotLocation : Length = 70 [cm];
        attribute bloodFlowRestored : Boolean = false;
        port vessel : VesselPort;
        port radiation : RadiationPort;
    }

    // =====================================================================
    // Top-level System
    // =====================================================================

    part def MerciRetrieverSystem {
        attribute procedureStartTime : Time = 0 [s];
        attribute maxAttempts : Integer = 3;
        attribute attemptCount : Integer = 0;
        attribute flowRestored : Boolean = false;
        attribute minDwellTime : Duration = 120 [s];
        attribute dwellElapsed : Duration = 0 [s];
        attribute procedureStatus : ProcedureStatus = ProcedureStatus::NotStarted;

        part patient : Patient;
        part fluoroscopy : FluoroscopySystem;
        part guide : GuideCatheter;
        part microcatheter : Microcatheter;
        part retriever : MerciRetrieverDevice;
        part pump : AspirationPump;
        part surgeon : Surgeon;

        // Physical and control connections
        connection guideVessel connect guide.vessel to patient.vessel;
        connection microInGuide1 connect microcatheter.proximal to guide.distal;
        connection retrieverInMicro1 connect retriever.proximal to microcatheter.distal;
        connection pumpToGuide1 connect pump.output to guide.proximal;
        connection fluoroImageOut connect fluoroscopy.display to surgeon.view;
        connection fluoroRadiation connect fluoroscopy.emission to patient.radiation;
        connection surgeonToFluoroCtrl connect surgeon.ctrl to fluoroscopy.ctrl;
        connection surgeonToGuideCtrl connect surgeon.guideCmd to guide.ctrl;
        connection surgeonToMicroCtrl connect surgeon.microCmd to microcatheter.ctrl;
        connection surgeonToRetrieverCtrl connect surgeon.retrieverCmd to retriever.ctrl;
        connection surgeonToPumpCtrl connect surgeon.pumpCmd to pump.ctrl;

        // Item flows across connections
        flow of XRayBeam from fluoroscopy.emission to patient.radiation;
        flow of FluoroImage from fluoroscopy.display to surgeon.view;
        flow of Saline from guide.proximal to microcatheter.distal;
        flow of Debris from patient.vessel to pump.output;
        flow of Blood from patient.vessel to guide.vessel;

        constraint maxAttemptsConstraint { /* attemptCount <= maxAttempts */ }
        constraint minDwellConstraint { /* dwellElapsed >= minDwellTime before withdrawal */ }
        constraint withdrawForceConstraint { /* retriever maxWithdrawForce <= 2.0 N */ }

        stateMachine procedureStates {
            state Init;
            state GuideInsertion;
            state MicrocatheterNavigation;
            state RetrieverAdvancement;
            state RetrieverDeployment;
            state Dwell;
            state WithdrawWithAspiration;
            state AssessReperfusion;
            state ReperfusionSuccessful;
            state ReperfusionFailed;
            state RepeatAttempt;

            transition t_init from Init to GuideInsertion when surgeon.ctrl.command.command == "begin";
            transition t_g1 from GuideInsertion to MicrocatheterNavigation when guide.inserted == true;
            transition t_m1 from MicrocatheterNavigation to RetrieverAdvancement when microcatheter.atClot == true;
            transition t_r1 from RetrieverAdvancement to RetrieverDeployment when retriever.engagesClot == true;
            transition t_d1 from RetrieverDeployment to Dwell when retriever.deployed == true;
            transition t_dw1 from Dwell to WithdrawWithAspiration when dwellElapsed >= minDwellTime;
            transition t_w1 from WithdrawWithAspiration to AssessReperfusion when retriever.deliveryState == "stowed";
            transition t_a1 from AssessReperfusion to ReperfusionSuccessful when flowRestored == true;
            transition t_a2 from AssessReperfusion to RepeatAttempt when flowRestored == false and attemptCount < maxAttempts;
            transition t_a3 from AssessReperfusion to ReperfusionFailed when flowRestored == false and attemptCount >= maxAttempts;
            transition t_rep1 from RepeatAttempt to RetrieverAdvancement when surgeon.retrieverCmd.command.command == "retry";
        }
    }

    // =====================================================================
    // Requirements
    // =====================================================================

    requirement def RestoreCerebralBloodFlow {
        doc
        /* The system shall physically remove blood clots from intracranial
           arteries and restore downstream perfusion in patients presenting
           with an acute ischemic stroke. */
        subject patient : Patient;
        attribute targetRestorationTime : Time = 30 [min];
    }

    requirement def ProvideVascularAccess {
        doc
        /* A guide catheter shall provide a stable, low-friction pathway
           from the femoral access point to the cervical vasculature. */
        subject guide : GuideCatheter;
        attribute minLength : Length = 80 [cm];
        attribute minInnerDiameter : Diameter = 2.0 [mm];
    }

    requirement def NavigateIntracranial {
        doc
        /* A microcatheter shall be navigable through the intracranial
           arteries to the clot location under real-time fluoroscopy. */
        subject microcatheter : Microcatheter;
        attribute maxOuterDiameter : Diameter = 0.6 [mm];
    }

    requirement def RealtimeImaging {
        doc
        /* The fluoroscopy system shall provide real-time X-ray imaging
           of the instruments within the patient vasculature. */
        subject fluoroscopy : FluoroscopySystem;
        attribute minFrameRate : Frequency = 15 [Hz];
    }

    requirement def ClotEngagement {
        doc
        /* The MERCI retriever shall deploy helical corkscrew loops at the
           clot and entangle the thrombus to a vessel-appropriate diameter. */
        subject retriever : MerciRetrieverDevice;
        attribute minDeployedDiameter : Diameter = 2.0 [mm];
        attribute maxDeployedDiameter : Diameter = 5.0 [mm];
    }

    requirement def DwellPeriod {
        doc
        /* The deployed retriever shall dwell in contact with the clot for
           at least the minimum dwell time to ensure full engagement. */
        subject system : MerciRetrieverSystem;
        attribute minDwell : Duration = 120 [s];
    }

    requirement def FragmentCapture {
        doc
        /* The aspiration pump shall apply suction at the catheter tip to
           capture any clot fragments released during withdrawal and
           prevent downstream embolization. */
        subject pump : AspirationPump;
        attribute minVacuum : Pressure = -50 [kPa];
    }

    requirement def RepeatAttempts {
        doc
        /* The procedure may be repeated a limited number of times until
           successful reperfusion is achieved or the maximum attempt count
           is reached. */
        subject system : MerciRetrieverSystem;
        attribute maxAttempts : Integer = 3;
    }

    requirement def SafetyLimit {
        doc
        /* The maximum withdrawal force applied by the retriever shall not
           exceed a safe threshold to avoid intracranial vessel injury. */
        subject retriever : MerciRetrieverDevice;
        attribute maxWithdrawForce : Force = 2.0 [N];
    }

    // Requirement usages and allocations
    part merciSystem : MerciRetrieverSystem;

    requirement restoreFlowReq : RestoreCerebralBloodFlow;
    requirement provideAccessReq : ProvideVascularAccess;
    requirement navigateReq : NavigateIntracranial;
    requirement imagingReq : RealtimeImaging;
    requirement clotReq : ClotEngagement;
    requirement dwellReq : DwellPeriod;
    requirement fragmentReq : FragmentCapture;
    requirement repeatReq : RepeatAttempts;
    requirement safetyReq : SafetyLimit;

    satisfy restoreFlowReq by merciSystem;
    satisfy provideAccessReq by merciSystem.guide;
    satisfy navigateReq by merciSystem.microcatheter;
    satisfy imagingReq by merciSystem.fluoroscopy;
    satisfy clotReq by merciSystem.retriever;
    satisfy dwellReq by merciSystem;
    satisfy fragmentReq by merciSystem.pump;
    satisfy repeatReq by merciSystem;
    satisfy safetyReq by merciSystem.retriever;
}
