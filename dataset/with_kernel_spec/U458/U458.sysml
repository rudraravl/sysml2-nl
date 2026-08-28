package YankauerSuctionSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    item def Fluid;
    item def Debris;
    item def StartSuction;
    item def StopSuction;
    item def BlockageDetected;
    item def BlockageCleared;
    item def CanisterFullDetected;
    item def CanisterChanged;

    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def LengthValue :> Real;

    port def VacuumPort {
        out pressure : PressureValue;
    }
    port def FluidFlowPort {
        in fluid : Fluid;
        in debris : Debris;
    }
    port def ControlPort;

    part def VacuumRegulator {
        attribute pressureSetting : PressureValue = -50 [kPa];
        port vacuumOut : VacuumPort;
        port controlIn : ControlPort;

        action def generateVacuum {
            out pressure : PressureValue;
        }
        perform generateVacuum;
    }

    part def BacterialFilter {
        port vacuumIn : ~VacuumPort;
        port vacuumOut : VacuumPort;
        attribute filterEfficiency : Real = 0.99;
    }

    part def CollectionCanister {
        attribute capacity : VolumeValue = 3000 [mL];
        attribute currentVolume : VolumeValue = 0 [mL];
        port fluidIn : FluidFlowPort;
        port vacuumIn : ~VacuumPort;
        port vacuumOut : VacuumPort;
        port overflowSignal : ControlPort;

        action def shutoffValve;
        perform shutoffValve;
    }

    part def SuctionTubing {
        attribute length : LengthValue = 2 [m];
        port fluidIn : FluidFlowPort;
        port fluidOut : ~FluidFlowPort;
        port vacuumIn : ~VacuumPort;
        port vacuumOut : VacuumPort;
    }

    part def YankauerTip {
        attribute hasBulbousEnd : Boolean = true;
        attribute hasSideHoles : Boolean = true;
        attribute hasVentControl : Boolean = true;
        port patientEnd : FluidFlowPort;
        port tubingFluid : ~FluidFlowPort;
        port tubingVacuum : ~VacuumPort;
        port ventControl : ControlPort;

        action def modulatePressure {
            in ventOpen : Boolean;
            out pressure : PressureValue;
        }
        perform modulatePressure;
    }

    state def SuctionSystemStates {
        entry; then idle;

        state idle;
        accept StartSuction
            then active;

        state active;
        accept StopSuction
            then idle;
        accept BlockageDetected
            then obstructed;
        accept CanisterFullDetected
            then canisterFull;

        state obstructed;
        accept BlockageCleared
            then active;
        accept StopSuction
            then idle;

        state canisterFull;
        accept CanisterChanged
            then idle;
        accept StopSuction
            then idle;
    }

    requirement def RemoveFluidsAndDebris {
        subject system : YankauerSuctionSystem;
        doc /* The system shall remove fluids and debris from the surgical site via continuous vacuum-assisted aspiration. */;
    }

    requirement def PreventContamination {
        subject filter : BacterialFilter;
        doc /* The bacterial filter shall prevent aspirated materials and airborne pathogens from reaching the vacuum regulator. */;
    }

    requirement def PreventSpills {
        subject canister : CollectionCanister;
        doc /* The collection canister shall prevent spills when full via an overflow shutoff mechanism. */;
    }

    requirement def PreventTrauma {
        subject tip : YankauerTip;
        doc /* The Yankauer tip shall allow effective fluid removal without causing trauma to patient tissues. */;
    }

    requirement def ModulatePressure {
        subject tip : YankauerTip;
        doc /* The operator shall be able to modulate suction pressure at the point of use via a finger-controlled vent. */;
    }

    part def YankauerSuctionSystem {
        part vacuumRegulator : VacuumRegulator;
        part bacterialFilter : BacterialFilter;
        part collectionCanister : CollectionCanister;
        part suctionTubing : SuctionTubing;
        part yankauerTip : YankauerTip;

        connect vacuumRegulator.vacuumOut to bacterialFilter.vacuumIn;
        connect bacterialFilter.vacuumOut to collectionCanister.vacuumIn;
        connect collectionCanister.vacuumOut to suctionTubing.vacuumIn;
        connect suctionTubing.vacuumOut to yankauerTip.tubingVacuum;

        connect yankauerTip.tubingFluid to suctionTubing.fluidIn;
        connect suctionTubing.fluidOut to collectionCanister.fluidIn;

        connect collectionCanister.overflowSignal to vacuumRegulator.controlIn;

        exhibit state systemStates : SuctionSystemStates;

        requirement removeFluidsReq : RemoveFluidsAndDebris;
        requirement preventContamReq : PreventContamination;
        requirement preventSpillsReq : PreventSpills;
        requirement preventTraumaReq : PreventTrauma;
        requirement modulatePressureReq : ModulatePressure;
    }

    part yankauerSuctionSystemUsage : YankauerSuctionSystem {
        satisfy removeFluidsReq by yankauerSuctionSystemUsage;
        satisfy preventContamReq by yankauerSuctionSystemUsage.bacterialFilter;
        satisfy preventSpillsReq by yankauerSuctionSystemUsage.collectionCanister;
        satisfy preventTraumaReq by yankauerSuctionSystemUsage.yankauerTip;
        satisfy modulatePressureReq by yankauerSuctionSystemUsage.yankauerTip;
    }
}
