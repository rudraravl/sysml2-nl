package VaginalSyringeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== UNITS =====
    unit mL;
    unit mm;
    unit kPa;
    unit degC;
    unit g;
    unit mL_per_s;

    // ===== VALUE TYPES =====
    value type VolumeVal :> Real { unit :> mL; }
    value type LengthVal :> Real { unit :> mm; }
    value type ForceVal :> Real { unit :> N; }
    value type PressureVal :> Real { unit :> kPa; }
    value type MassVal :> Real { unit :> g; }
    value type TempVal :> Real { unit :> degC; }
    value type FlowVal :> Real { unit :> mL_per_s; }

    // ===== ITEM DEFINITIONS =====
    item def MedicinalFluid {
        attribute designation : String;
        attribute prescribedVolume : VolumeVal;
        attribute storageTempMin : TempVal;
        attribute storageTempMax : TempVal;
    }

    item def CleansingSolution {
        attribute designation : String;
        attribute prescribedVolume : VolumeVal;
        attribute concentrationPercent : Real;
    }

    item def AdministeredFluid {
        item medicinalContent : MedicinalFluid[0..1];
        item cleansingContent : CleansingSolution[0..1];
        attribute totalVolume : VolumeVal;
        attribute temperature : TempVal;
    }

    // ===== MATERIAL DEFINITIONS =====
    part def MedicalGradePolypropylene {
        attribute designation : String = "Medical-grade polypropylene";
        attribute uspClass : String = "USP Class VI";
        attribute density : MassVal;
        attribute maxUseTemp : TempVal;
    }

    part def SiliconeSealMaterial {
        attribute designation : String = "Medical-grade silicone";
        attribute shoreHardness : Real;
        attribute tensileStrength : PressureVal;
    }

    // ===== PORT DEFINITIONS =====
    port def FluidInletPort {
        in item incomingFluid : AdministeredFluid;
    }

    port def FluidOutletPort {
        out item dispensedFluid : AdministeredFluid;
    }

    port def PlungerMechPort {
        attribute appliedForce : ForceVal;
        attribute displacement : LengthVal;
    }

    port def CapInterfacePort {
        attribute sealed : Boolean;
        attribute tamperEvidence : Boolean;
    }

    // ===== CONNECTION DEFINITIONS =====
    connection def FluidFlowConnection {
        end source : FluidOutletPort;
        end target : FluidInletPort;
        item flowingFluid : AdministeredFluid;
    }

    connection def PlungerBarrelConnection {
        end source : PlungerMechPort;
        end target : PlungerMechPort;
    }

    connection def CapNozzleConnection {
        end source : CapInterfacePort;
        end target : CapInterfacePort;
    }

    // ===== COMPONENT PART DEFINITIONS =====
    part def MainBarrel {
        attribute material : MedicalGradePolypropylene;
        attribute capacity : VolumeVal = 150 [mL];
        attribute innerDiameter : LengthVal = 28 [mm];
        attribute barrelLength : LengthVal = 200 [mm];
        attribute isGraduated : Boolean = true;
        attribute graduationIncrement : VolumeVal = 10 [mL];
        attribute graduationAccuracy : VolumeVal = 2 [mL];
        attribute isSterile : Boolean = true;
        attribute currentFillVolume : VolumeVal = 0 [mL];

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port plungerSealInterface : PlungerMechPort;
        port nozzleInterface : FluidOutletPort;
    }

    part def PlungerRod {
        attribute material : MedicalGradePolypropylene;
        attribute rodLength : LengthVal = 180 [mm];
        attribute rodDiameter : LengthVal = 10 [mm];
        attribute isReinforced : Boolean = true;
    }

    part def PlungerSeal {
        attribute material : SiliconeSealMaterial;
        attribute sealDiameter : LengthVal = 28 [mm];
        attribute sealIntegrity : Boolean = true;
        attribute isReliable : Boolean = true;
    }

    part def PlungerAssembly {
        part rod : PlungerRod;
        part seal : PlungerSeal;

        attribute totalStroke : LengthVal = 200 [mm];
        attribute currentDisplacement : LengthVal = 0 [mm];
        attribute appliedForce : ForceVal = 0 [N];
        attribute isSealed : Boolean = true;

        port barrelInterface : PlungerMechPort;
        port userInterface : PlungerMechPort;
    }

    part def Nozzle {
        attribute material : MedicalGradePolypropylene;
        attribute nozzleLength : LengthVal = 120 [mm];
        attribute outerDiameter : LengthVal = 8 [mm];
        attribute outletDiameter : LengthVal = 4 [mm];
        attribute tipRadius : LengthVal = 3 [mm];
        attribute isAtraumatic : Boolean = true;
        attribute isSmoothRounded : Boolean = true;
        attribute surfaceFinish : String = "Smooth, polished";
        attribute isLongSlender : Boolean = true;

        port barrelConnection : FluidInletPort;
        port outletPort : FluidOutletPort;
        port capInterface : CapInterfacePort;
    }

    part def SafetyCap {
        attribute material : MedicalGradePolypropylene;
        attribute capLength : LengthVal = 130 [mm];
        attribute isTamperEvident : Boolean = true;
        attribute isSealed : Boolean = true;
        attribute tamperIndicator : String = "Breakaway ring";
        attribute tamperIndicatorColor : String = "Red";
        attribute isIntact : Boolean = true;

        port nozzleInterface : CapInterfacePort;
    }

    // ===== ACTION DEFINITIONS =====
    action def VerifySterilityAction {
        in safetyCap : SafetyCap;
        out isVerified : Boolean;
        out isTampered : Boolean;
    }

    action def FillBarrelAction {
        in barrel : MainBarrel;
        in fluid : AdministeredFluid;
        out filledBarrel : MainBarrel;
        attribute targetVolume : VolumeVal;
    }

    action def PositionDeviceAction {
        in nozzle : Nozzle;
        attribute insertionAngle : Real;
        attribute insertionDepth : LengthVal;
    }

    action def DispenseFluidAction {
        in plunger : PlungerAssembly;
        in barrel : MainBarrel;
        out dispensedVolume : VolumeVal;
        attribute appliedForce : ForceVal;
        attribute flowRate : FlowVal;
    }

    // ===== STATE MACHINE DEFINITION =====
    state def SyringeStateMachine {
        state SterileIdle {
            entry { /* Initialize device in sterile sealed state */ }
            do { /* Maintain sterility with safety cap sealed */ }
        }

        state VerifyingSterility {
            entry { /* Begin tamper-evident seal inspection */ }
            do { /* Verify cap integrity and tamper evidence */ }
        }

        state Filling {
            entry { /* Remove safety cap from nozzle */ }
            do { /* Draw fluid into barrel using graduation markings for accurate volume measurement */ }
            exit { /* Verify filled volume against graduation markings */ }
        }

        state Positioned {
            entry { /* Position nozzle for vaginal administration */ }
            do { /* Ensure atraumatic tip is correctly oriented for patient comfort */ }
        }

        state Dispensing {
            entry { /* Begin plunger depression */ }
            do { /* Push plunger to dispense fluid through nozzle */ }
            exit { /* Confirm all fluid has been dispensed */ }
        }

        state Used {
            entry { /* Mark device as single-use spent */ }
            do { /* Await proper disposal */ }
        }

        state Disposed {
            entry { /* Dispose per medical waste protocol */ }
        }

        transition from SterileIdle to VerifyingSterility;
        transition from VerifyingSterility to Filling;
        transition from Filling to Positioned;
        transition from Positioned to Dispensing;
        transition from Dispensing to Used;
        transition from Used to Disposed;
    }

    // ===== SYSTEM ASSEMBLY =====
    part def VaginalSyringe {
        part barrel : MainBarrel;
        part plunger : PlungerAssembly;
        part nozzle : Nozzle;
        part safetyCap : SafetyCap;

        port systemFluidInput : FluidInletPort;
        port systemFluidOutput : FluidOutletPort;
        port userActuation : PlungerMechPort;

        connection barrelPlungerConn connect barrel.plungerSealInterface to plunger.barrelInterface;
        connection barrelNozzleConn connect barrel.nozzleInterface to nozzle.barrelConnection;
        connection nozzleCapConn connect nozzle.capInterface to safetyCap.nozzleInterface;

        attribute isSterile : Boolean = true;
        attribute isSingleUse : Boolean = true;
        attribute isUsed : Boolean = false;
        attribute maxCapacity : VolumeVal = 150 [mL];
        attribute currentFluidVolume : VolumeVal = 0 [mL];
        attribute deviceDesignation : String = "Single-use vaginal syringe system";

        state operation : SyringeStateMachine;

        item administeredFluid : AdministeredFluid;
    }

    // ===== REQUIREMENTS =====
    requirement def SterilityRequirement {
        doc /* The system shall be provided sterile and maintain sterility until the tamper-evident cap is removed. */;
        attribute requirementId : String = "REQ-001";
        attribute priority : String = "High";
    }

    requirement def CapacityRequirement {
        doc /* The main barrel shall hold up to 150 mL of fluid. */;
        attribute requirementId : String = "REQ-002";
        attribute maxVolume : VolumeVal = 150 [mL];
    }

    requirement def MaterialRequirement {
        doc /* The main barrel, plunger rod, and nozzle shall be made from medical-grade polypropylene. */;
        attribute requirementId : String = "REQ-003";
    }

    requirement def GraduationRequirement {
        doc /* The barrel shall include clear graduation markings for accurate volume measurement. */;
        attribute requirementId : String = "REQ-004";
        attribute increment : VolumeVal = 10 [mL];
        attribute accuracy : VolumeVal = 2 [mL];
    }

    requirement def AtraumaticTipRequirement {
        doc /* The nozzle tip shall be smooth, rounded, and atraumatic to ensure patient comfort and prevent tissue injury during insertion and use. */;
        attribute requirementId : String = "REQ-005";
    }

    requirement def TamperEvidentCapRequirement {
        doc /* The nozzle shall be covered by a tamper-evident safety cap to guarantee sterility and product integrity before use. */;
        attribute requirementId : String = "REQ-006";
    }

    requirement def SingleUseRequirement {
        doc /* The device is intended for one-time use to ensure hygiene and prevent any risk of cross-contamination. */;
        attribute requirementId : String = "REQ-007";
    }

    requirement def PlungerSealRequirement {
        doc /* The plunger shall have a reliable seal that moves within the barrel, allowing a user to apply force to dispense the contained fluid. */;
        attribute requirementId : String = "REQ-008";
    }

    requirement def OperationalFlowRequirement {
        doc /* The device shall follow a straightforward operational flow: begin in sterile idle state, verify sterility by checking tamper-evident seal, fill barrel with appropriate fluid, position device for use, and dispense fluid by pushing the plunger. */;
        attribute requirementId : String = "REQ-009";
    }

    requirement def NozzleDesignRequirement {
        doc /* The nozzle shall be long and slender with a smooth, rounded, and atraumatic tip designed to ensure patient comfort and prevent tissue injury during insertion and use. */;
        attribute requirementId : String = "REQ-010";
    }

    // ===== REQUIREMENT SATISFACTION =====
    satisfy sterilitySatisfaction : SterilityRequirement by VaginalSyringe;
    satisfy capacitySatisfaction : CapacityRequirement by VaginalSyringe;
    satisfy materialSatisfaction : MaterialRequirement by VaginalSyringe;
    satisfy graduationSatisfaction : GraduationRequirement by VaginalSyringe;
    satisfy atraumaticTipSatisfaction : AtraumaticTipRequirement by VaginalSyringe;
    satisfy tamperEvidentCapSatisfaction : TamperEvidentCapRequirement by VaginalSyringe;
    satisfy singleUseSatisfaction : SingleUseRequirement by VaginalSyringe;
    satisfy plungerSealSatisfaction : PlungerSealRequirement by VaginalSyringe;
    satisfy operationalFlowSatisfaction : OperationalFlowRequirement by VaginalSyringe;
    satisfy nozzleDesignSatisfaction : NozzleDesignRequirement by VaginalSyringe;
}
