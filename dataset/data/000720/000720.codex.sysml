package OsteomedSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def millimeter :> Real;
    attribute def newton :> Real;
    attribute def newtonMillimeter :> Real;
    attribute def degreeCelsius :> Real;
    attribute def minute :> Real;
    attribute def percent :> Real;

    item def SterileImplant {
        attribute material : ImplantMaterial;
        attribute sterilityAssuranceLevel : Real;
        attribute lotIdentifier : String;
        attribute expirationRemaining : minute;
    }

    item def BoneSegment {
        attribute corticalThickness : millimeter;
        attribute density : Real;
        attribute fractureGap : millimeter;
    }

    item def FixationPlan {
        attribute targetCompression : newton;
        attribute plannedScrewCount : Integer;
        attribute plannedPlateLength : millimeter;
        attribute maxAllowedDrillDepth : millimeter;
    }

    item def SurgicalFeedback {
        attribute insertionTorque : newtonMillimeter;
        attribute drillDepth : millimeter;
        attribute implantSeated : Boolean;
        attribute alignmentDeviation : millimeter;
    }

    enum def ImplantMaterial {
        enum titaniumAlloy;
        enum stainlessSteel;
        enum bioresorbablePolymer;
    }

    enum def ProcedurePhase {
        enum preoperativePlanning;
        enum sterilePreparation;
        enum fractureReduction;
        enum drilling;
        enum implantPlacement;
        enum fixationVerification;
        enum closureReady;
    }

    port def ImplantSupplyPort {
        out item implant : SterileImplant;
    }

    port def BoneInterfacePort {
        in item bone : BoneSegment;
        out item feedback : SurgicalFeedback;
    }

    port def PlanPort {
        in item plan : FixationPlan;
    }

    port def TorqueDrivePort {
        out attribute appliedTorque : newtonMillimeter;
        in attribute torqueLimit : newtonMillimeter;
    }

    port def IrrigationPort {
        out attribute flowRate : Real;
        out attribute fluidTemperature : degreeCelsius;
    }

    part def OsteomedFixationSystem {
        attribute primaryFunction : String = "Provide sterile orthopedic implants and guided instruments to stabilize fractured or surgically reconstructed bone segments while preserving alignment, compression, and procedural safety.";
        attribute systemMass : Real;
        attribute operatingTemperature : degreeCelsius;
        attribute maximumScrewTorque : newtonMillimeter;
        attribute nominalPlateThickness : millimeter;

        port planInput : PlanPort;
        port boneInterface : BoneInterfacePort;
        port implantOutput : ImplantSupplyPort;
        port torqueDrive : TorqueDrivePort;
        port irrigation : IrrigationPort;

        part implantTray : SterileImplantTray;
        part plateModule : BonePlateModule;
        part screwModule : LockingScrewModule;
        part drillGuide : DrillGuideAssembly;
        part torqueDriver : TorqueLimitingDriver;
        part depthGauge : DepthGauge;
        part sterilizationBarrier : SterileBarrierSystem;
        part clinicalUserInterface : SurgicalWorkflowInterface;

        connection planToWorkflow connect planInput to clinicalUserInterface.planInput;
        connection trayToImplantOutput connect implantTray.implantOutput to implantOutput;
        connection plateToBone connect plateModule.boneInterface to boneInterface;
        connection screwToBone connect screwModule.boneInterface to boneInterface;
        connection guideToBone connect drillGuide.boneInterface to boneInterface;
        connection driverToScrews connect torqueDriver.driveOutput to screwModule.driveInput;
        connection driverExternalTorque connect torqueDriver.externalDrive to torqueDrive;
        connection gaugeToWorkflow connect depthGauge.feedbackOutput to clinicalUserInterface.feedbackInput;
        connection irrigationToGuide connect irrigation to drillGuide.irrigationInput;

        perform action stabilizeBone;
        exhibit state procedureState;
    }

    part def SterileImplantTray {
        attribute implantCount : Integer;
        attribute sterilityAssuranceLevel : Real = 0.000001;
        attribute sealIntegrity : percent;
        port implantOutput : ImplantSupplyPort;

        part plates[1..8] : BonePlateModule;
        part screws[8..64] : LockingScrewModule;
    }

    part def BonePlateModule {
        attribute length : millimeter;
        attribute thickness : millimeter;
        attribute holeCount : Integer;
        attribute contourBendLimit : Real;
        attribute material : ImplantMaterial = ImplantMaterial::titaniumAlloy;

        port boneInterface : BoneInterfacePort;
        port screwPassage[4..16] : BoneInterfacePort;
    }

    part def LockingScrewModule {
        attribute diameter : millimeter;
        attribute length : millimeter;
        attribute threadPitch : millimeter;
        attribute maximumInsertionTorque : newtonMillimeter;
        attribute material : ImplantMaterial = ImplantMaterial::titaniumAlloy;

        port boneInterface : BoneInterfacePort;
        port driveInput : TorqueDrivePort;
    }

    part def DrillGuideAssembly {
        attribute guideDiameter : millimeter;
        attribute angularTolerance : millimeter;
        attribute maxThermalRise : degreeCelsius;

        port boneInterface : BoneInterfacePort;
        port irrigationInput : IrrigationPort;
    }

    part def TorqueLimitingDriver {
        attribute torqueSetpoint : newtonMillimeter;
        attribute torqueAccuracy : percent;
        attribute clutchReleased : Boolean;

        port driveOutput : TorqueDrivePort;
        port externalDrive : TorqueDrivePort;
    }

    part def DepthGauge {
        attribute measuredDepth : millimeter;
        attribute measurementTolerance : millimeter;

        port boneInput : BoneInterfacePort;
        port feedbackOutput : BoneInterfacePort;
    }

    part def SterileBarrierSystem {
        attribute packageSealStrength : Real;
        attribute sterilizationMethod : String = "Gamma irradiation or validated hospital steam sterilization";
        attribute opened : Boolean;
    }

    part def SurgicalWorkflowInterface {
        attribute currentPhase : ProcedurePhase;
        attribute warningActive : Boolean;

        port planInput : PlanPort;
        port feedbackInput : BoneInterfacePort;
    }

    action def StabilizeBoneAction {
        in item patientBone : BoneSegment;
        in item fixationPlan : FixationPlan;
        out item finalFeedback : SurgicalFeedback;

        action prepareSterileField;
        action reduceFracture;
        action selectPlate;
        action drillPilotHoles;
        action measureDepth;
        action insertScrews;
        action verifyFixation;

        first start;
        then prepareSterileField;
        then reduceFracture;
        then selectPlate;
        then drillPilotHoles;
        then measureDepth;
        then insertScrews;
        then verifyFixation;
        then done;
    }

    state def OsteomedProcedureStateMachine {
        entry action initializeProcedure;

        state Planning;
        state SterileSetup;
        state Reduction;
        state PilotDrilling;
        state DepthMeasurement;
        state ImplantInsertion;
        state Verification;
        state Complete;
        state Exception;

        initial then Planning;

        transition Planning_to_SterileSetup
            first Planning
            accept FixationPlan
            then SterileSetup;

        transition SterileSetup_to_Reduction
            first SterileSetup
            if sealIntegrityAcceptable
            then Reduction;

        transition Reduction_to_PilotDrilling
            first Reduction
            if fractureGapAcceptable
            then PilotDrilling;

        transition PilotDrilling_to_DepthMeasurement
            first PilotDrilling
            if drillDepthWithinPlan
            then DepthMeasurement;

        transition DepthMeasurement_to_ImplantInsertion
            first DepthMeasurement
            if screwLengthSelected
            then ImplantInsertion;

        transition ImplantInsertion_to_Verification
            first ImplantInsertion
            if torqueWithinLimit
            then Verification;

        transition Verification_to_Complete
            first Verification
            if alignmentAndCompressionAcceptable
            then Complete;

        transition Any_to_Exception
            first Planning
            if criticalSafetyFault
            then Exception;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : OsteomedFixationSystem;
        doc /* The Osteomed system shall support high-level orthopedic fixation by enabling clinicians to plan, place, and verify sterile plates and screws that stabilize bone segments. */
        require constraint {
            system.maximumScrewTorque <= 180.0
        }
    }

    requirement def SterilityRequirement {
        subject tray : SterileImplantTray;
        doc /* The implant tray shall maintain a sterility assurance level of at least 10^-6 until opened within the sterile field. */
        require constraint {
            tray.sterilityAssuranceLevel <= 0.000001
        }
    }

    requirement def TorqueSafetyRequirement {
        subject driver : TorqueLimitingDriver;
        doc /* The torque limiting driver shall release the clutch when applied screw torque exceeds the selected setpoint. */
        require constraint {
            driver.clutchReleased == true implies driver.torqueSetpoint <= 180.0
        }
    }

    requirement def ThermalProtectionRequirement {
        subject guide : DrillGuideAssembly;
        doc /* The drill guide and irrigation interface shall limit drill-site temperature rise during pilot-hole preparation. */
        require constraint {
            guide.maxThermalRise <= 8.0
        }
    }

    requirement def AlignmentRequirement {
        subject feedback : SurgicalFeedback;
        doc /* Final fixation verification shall confirm implant seating and bone alignment within clinical tolerance. */
        require constraint {
            feedback.implantSeated == true and feedback.alignmentDeviation <= 1.0
        }
    }

    requirement def DepthControlRequirement {
        subject plan : FixationPlan;
        doc /* Drilling depth shall not exceed the planned maximum depth for the selected bone segment and implant construct. */
        require constraint {
            plan.maxAllowedDrillDepth > 0.0
        }
    }

    satisfy PrimaryFunctionRequirement by OsteomedFixationSystem;
    satisfy SterilityRequirement by SterileImplantTray;
    satisfy TorqueSafetyRequirement by TorqueLimitingDriver;
    satisfy ThermalProtectionRequirement by DrillGuideAssembly;
    satisfy AlignmentRequirement by OsteomedFixationSystem;
    satisfy DepthControlRequirement by DrillGuideAssembly;
}