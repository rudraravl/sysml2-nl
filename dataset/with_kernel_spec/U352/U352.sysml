package PessaryMechanicalSupportSystem {
    private import ScalarValues::*;
    
    unit N;
    unit kPa;
    unit mm;
    unit N_per_mm;
    
    value def ForceValue :> Real;
    value def PressureValue :> Real;
    value def LengthValue :> Real;
    value def StiffnessValue :> Real;
    
    item def Material {
        attribute stiffness : StiffnessValue;
        attribute flexibility : Real;
    }
    
    part def PelvicOrgan {
        attribute weight : ForceValue;
        attribute descent : LengthValue;
    }
    
    part def Bladder :> PelvicOrgan;
    part def Uterus :> PelvicOrgan;
    
    part def VaginalTissue {
        attribute thickness : LengthValue;
        attribute sensitivity : Real;
        attribute pressureTolerance : PressureValue;
    }
    
    part def PelvicFloorMuscle {
        attribute tone : Real;
    }
    
    port def SupportPort {
        out appliedForce : ForceValue;
        out organElevation : LengthValue;
    }
    
    port def ContactPort {
        out contactPressure : PressureValue;
    }
    
    port def OrganSupportPort {
        in appliedForce : ForceValue;
        in organElevation : LengthValue;
    }
    
    port def TissueContactPort {
        in contactPressure : PressureValue;
    }
    
    part def PessaryDevice {
        attribute shape : String = "ring";
        attribute diameter : LengthValue;
        item material : Material;
        attribute currentElevation : LengthValue;
        attribute currentPressure : PressureValue;
        attribute currentDisplacement : LengthValue;
        attribute isStable : Boolean = false;
        port supportPort : SupportPort;
        port contactPort : ContactPort;
    }
    
    part def Patient {
        part bladder : Bladder;
        part uterus : Uterus;
        part vaginalWall : VaginalTissue;
        part pelvicFloor : PelvicFloorMuscle;
        port organSupportPort : OrganSupportPort;
        port tissueContactPort : TissueContactPort;
    }
    
    connection def OrganSupportConnection {
        end deviceEnd : SupportPort;
        end patientEnd : OrganSupportPort;
    }
    
    connection def TissueContactConnection {
        end deviceEnd : ContactPort;
        end patientEnd : TissueContactPort;
    }
    
    action def AssessCondition {
        out organDescent : LengthValue;
        out tissueSensitivity : Real;
    }
    
    action def InsertDevice;
    
    action def ProvideSupport {
        in organWeight : ForceValue;
        in materialStiffness : StiffnessValue;
        out appliedForce : ForceValue;
        out appliedPressure : PressureValue;
        out elevationAchieved : LengthValue;
    }
    
    action def MonitorPressure {
        out pressure : PressureValue;
    }
    
    action def RemoveDevice;
    
    stateMachine def PessaryOperationSM {
        event occurrence assessmentComplete;
        event occurrence deviceSeated;
        event occurrence treatmentComplete;
        state InitialAssessment;
        state Insertion;
        state ContinuousSupport;
        state Removal;
        transition from InitialAssessment to Insertion on event assessmentComplete;
        transition from Insertion to ContinuousSupport on event deviceSeated;
        transition from ContinuousSupport to Removal on event treatmentComplete;
    }
    
    requirement def ElevationRequirement {
        doc /* The pessary must provide adequate upward force to elevate prolapsed organs to anatomical position. */
        subject device : PessaryDevice;
        attribute minElevation : LengthValue = 10 [mm];
        require device.currentElevation >= minElevation;
    }
    
    requirement def ComfortRequirement {
        doc /* Contact pressure against vaginal tissue must remain below injury threshold while maintaining comfort. */
        subject device : PessaryDevice;
        attribute maxPressure : PressureValue = 30 [kPa];
        require device.currentPressure <= maxPressure;
    }
    
    requirement def StabilityRequirement {
        doc /* The device must remain stable during daily activities without shifting or expulsion. */
        subject device : PessaryDevice;
        attribute maxDisplacement : LengthValue = 5 [mm];
        require device.currentDisplacement <= maxDisplacement;
    }
    
    requirement def MaterialFlexibilityRequirement {
        doc /* Device stiffness must balance structural support with flexibility for comfort. */
        subject device : PessaryDevice;
        attribute minStiffness : StiffnessValue = 1.0 [N_per_mm];
        attribute maxStiffness : StiffnessValue = 5.0 [N_per_mm];
        require device.material.stiffness >= minStiffness and device.material.stiffness <= maxStiffness;
    }
    
    part def PessarySystem {
        part device : PessaryDevice;
        part patient : Patient;
        connection organSupport : OrganSupportConnection connect device.supportPort to patient.organSupportPort;
        connection tissueContact : TissueContactConnection connect device.contactPort to patient.tissueContactPort;
        perform PessaryOperationSM;
        satisfy ElevationRequirement by device;
        satisfy ComfortRequirement by device;
        satisfy StabilityRequirement by device;
        satisfy MaterialFlexibilityRequirement by device;
    }
    
    part pessarySystem : PessarySystem;
}
