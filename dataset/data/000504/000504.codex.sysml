package StereotaxisMagneticNavigationSystem {
    import ScalarValues::*;
    import SI::*;

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }

    item def MagneticFieldCommand {
        attribute targetFluxDensity_T : Real;
        attribute directionX : Real;
        attribute directionY : Real;
        attribute directionZ : Real;
        attribute slewRate_T_per_s : Real;
    }

    item def NavigationPlan {
        attribute targetChamber : String;
        attribute targetPointX_mm : Real;
        attribute targetPointY_mm : Real;
        attribute targetPointZ_mm : Real;
        attribute maxTipForce_mN : Real;
        attribute maxFieldStrength_T : Real;
    }

    item def CatheterPose {
        attribute positionX_mm : Real;
        attribute positionY_mm : Real;
        attribute positionZ_mm : Real;
        attribute yaw_deg : Real;
        attribute pitch_deg : Real;
        attribute roll_deg : Real;
        attribute tipForce_mN : Real;
    }

    item def FluoroscopyFrame {
        attribute frameTime_s : Real;
        attribute imageWidth_px : Integer;
        attribute imageHeight_px : Integer;
        attribute doseRate_mGy_per_min : Real;
    }

    item def SafetyStatus {
        attribute emergencyStopActive : Boolean;
        attribute collisionRisk : Boolean;
        attribute magneticFieldWithinLimit : Boolean;
        attribute radiationWithinLimit : Boolean;
        attribute catheterForceWithinLimit : Boolean;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def CommandPort {
        in item plan : NavigationPlan;
        out item command : MagneticFieldCommand;
    }

    port def ImagingPort {
        in item frame : FluoroscopyFrame;
        out item pose : CatheterPose;
    }

    port def SafetyPort {
        inout item status : SafetyStatus;
    }

    port def CatheterInterfacePort {
        out item pose : CatheterPose;
        in item fieldCommand : MagneticFieldCommand;
    }

    part def MagneticNavigationSystem {
        attribute primaryFunction : String = "Create and control external magnetic fields that remotely orient and advance a magnetically tipped catheter through patient anatomy with image-guided precision.";

        port powerPort : PowerInputPort;
        port operatorCommandPort : CommandPort;
        port imagingPort : ImagingPort;
        port safetyPort : SafetyPort;
        port catheterPort : CatheterInterfacePort;

        part operatorConsole : OperatorConsole;
        part planningWorkstation : ProcedurePlanningWorkstation;
        part navigationController : NavigationController;
        part magneticFieldGenerator : MagneticFieldGenerator;
        part imagingSubsystem : ImagingSubsystem;
        part roboticCatheterAdvancer : RoboticCatheterAdvancer;
        part patientTable : PatientTable;
        part catheter : MagneticCatheter;
        part safetyManager : SafetyManager;

        connect powerPort to magneticFieldGenerator.powerPort;
        connect powerPort to imagingSubsystem.powerPort;
        connect powerPort to navigationController.powerPort;
        connect powerPort to roboticCatheterAdvancer.powerPort;

        connect operatorCommandPort to operatorConsole.commandPort;
        connect operatorConsole.planPort to planningWorkstation.planPort;
        connect planningWorkstation.controllerPort to navigationController.commandPort;
        connect navigationController.fieldCommandPort to magneticFieldGenerator.commandPort;
        connect magneticFieldGenerator.catheterPort to catheter.magneticTipPort;

        connect imagingSubsystem.imagePort to navigationController.imagingPort;
        connect navigationController.catheterPosePort to roboticCatheterAdvancer.posePort;
        connect roboticCatheterAdvancer.catheterPort to catheter.mechanicalPort;

        connect safetyManager.safetyPort to safetyPort;
        connect safetyManager.controllerPort to navigationController.safetyPort;
        connect safetyManager.fieldGeneratorPort to magneticFieldGenerator.safetyPort;
        connect safetyManager.imagingPort to imagingSubsystem.safetyPort;
        connect safetyManager.advancerPort to roboticCatheterAdvancer.safetyPort;

        perform action guideCatheter : HighLevelGuidedNavigation;
        exhibit state procedureState : ProcedureControlStateMachine;
    }

    part def OperatorConsole {
        port commandPort : CommandPort;
        port planPort : CommandPort;

        attribute displayLatency_ms : Real = 80.0;
        attribute joystickResolution_deg : Real = 0.5;
        attribute supportsEmergencyStop : Boolean = true;
    }

    part def ProcedurePlanningWorkstation {
        port planPort : CommandPort;
        port controllerPort : CommandPort;

        attribute anatomicalModelResolution_mm : Real = 0.6;
        attribute registeredCoordinateError_mm : Real = 1.2;
        attribute supportsTargetPathPreview : Boolean = true;
    }

    part def NavigationController {
        port powerPort : PowerInputPort;
        port commandPort : CommandPort;
        port fieldCommandPort : CommandPort;
        port imagingPort : ImagingPort;
        port catheterPosePort : CatheterInterfacePort;
        port safetyPort : SafetyPort;

        attribute controlLoopRate_Hz : Real = 100.0;
        attribute poseEstimationError_mm : Real = 1.0;
        attribute maxCommandLatency_ms : Real = 50.0;

        perform action computeMagneticVector : ComputeMagneticFieldVector;
    }

    part def MagneticFieldGenerator {
        port powerPort : PowerInputPort;
        port commandPort : CommandPort;
        port catheterPort : CatheterInterfacePort;
        port safetyPort : SafetyPort;

        part leftMagnet : ExternalMagnet {
            attribute nominalFluxDensity_T = 0.08;
            attribute maxFluxDensity_T = 0.10;
        }

        part rightMagnet : ExternalMagnet {
            attribute nominalFluxDensity_T = 0.08;
            attribute maxFluxDensity_T = 0.10;
        }

        attribute fieldUniformityPercent : Real = 95.0;
        attribute maxSlewRate_T_per_s : Real = 0.02;
        attribute patientClearance_mm : Real = 650.0;
    }

    part def ExternalMagnet {
        attribute nominalFluxDensity_T : Real;
        attribute maxFluxDensity_T : Real;
        attribute rotationRange_deg : Real = 180.0;
        attribute positioningAccuracy_deg : Real = 0.2;
        attribute coolingCapacity_W : Real = 1500.0;
    }

    part def ImagingSubsystem {
        port powerPort : PowerInputPort;
        port imagePort : ImagingPort;
        port safetyPort : SafetyPort;

        attribute modality : String = "Biplane fluoroscopy with electroanatomic map registration";
        attribute frameRate_Hz : Real = 15.0;
        attribute maxDoseRate_mGy_per_min : Real = 20.0;
        attribute imageRegistrationError_mm : Real = 1.5;
    }

    part def RoboticCatheterAdvancer {
        port powerPort : PowerInputPort;
        port posePort : CatheterInterfacePort;
        port catheterPort : CatheterInterfacePort;
        port safetyPort : SafetyPort;

        attribute translationRange_mm : Real = 500.0;
        attribute translationAccuracy_mm : Real = 0.2;
        attribute rotationRange_deg : Real = 360.0;
        attribute rotationAccuracy_deg : Real = 0.5;
        attribute maxInsertionSpeed_mm_per_s : Real = 10.0;
    }

    part def PatientTable {
        attribute maxPatientMass_kg : Real = 220.0;
        attribute longitudinalTravel_mm : Real = 1200.0;
        attribute lateralTravel_mm : Real = 300.0;
        attribute verticalTravel_mm : Real = 400.0;
        attribute positioningAccuracy_mm : Real = 0.5;
    }

    part def MagneticCatheter {
        port magneticTipPort : CatheterInterfacePort;
        port mechanicalPort : CatheterInterfacePort;

        attribute outerDiameter_mm : Real = 2.3;
        attribute usableLength_mm : Real = 1150.0;
        attribute tipMagneticMoment_A_m2 : Real = 0.018;
        attribute maxAllowableTipForce_mN : Real = 50.0;
        attribute minimumBendRadius_mm : Real = 18.0;
    }

    part def SafetyManager {
        port safetyPort : SafetyPort;
        port controllerPort : SafetyPort;
        port fieldGeneratorPort : SafetyPort;
        port imagingPort : SafetyPort;
        port advancerPort : SafetyPort;

        attribute emergencyStopResponse_ms : Real = 100.0;
        attribute maxPermittedField_T : Real = 0.10;
        attribute maxPermittedTipForce_mN : Real = 50.0;
        attribute maxPermittedDoseRate_mGy_per_min : Real = 20.0;

        perform action monitorSafety : SafetyMonitoring;
    }

    action def HighLevelGuidedNavigation {
        in item plan : NavigationPlan;
        in item liveImage : FluoroscopyFrame;
        out item achievedPose : CatheterPose;
        out item safetyStatus : SafetyStatus;

        action registerPatientAnatomy;
        action estimateCatheterPose;
        action computeNavigationVector;
        action commandExternalMagneticField;
        action advanceCatheter;
        action verifyTargetApproach;
        action holdStableField;

        first registerPatientAnatomy then estimateCatheterPose;
        first estimateCatheterPose then computeNavigationVector;
        first computeNavigationVector then commandExternalMagneticField;
        first commandExternalMagneticField then advanceCatheter;
        first advanceCatheter then verifyTargetApproach;
        first verifyTargetApproach then holdStableField;
    }

    action def ComputeMagneticFieldVector {
        in item desiredPlan : NavigationPlan;
        in item measuredPose : CatheterPose;
        out item fieldCommand : MagneticFieldCommand;

        attribute maximumPositionError_mm : Real = 2.0;
        attribute maximumAngularError_deg : Real = 3.0;
        attribute updatePeriod_ms : Real = 10.0;
    }

    action def SafetyMonitoring {
        in item pose : CatheterPose;
        in item frame : FluoroscopyFrame;
        in item command : MagneticFieldCommand;
        out item status : SafetyStatus;

        action checkEmergencyStop;
        action checkFieldStrength;
        action checkTipForce;
        action checkRadiationDose;
        action inhibitMotionOnFault;

        first checkEmergencyStop then checkFieldStrength;
        first checkFieldStrength then checkTipForce;
        first checkTipForce then checkRadiationDose;
        first checkRadiationDose then inhibitMotionOnFault;
    }

    state def ProcedureControlStateMachine {
        state idle;
        state planning;
        state patientRegistered;
        state navigating;
        state targetReached;
        state fieldHolding;
        state paused;
        state faulted;
        state shutdown;

        transition startProcedure first idle then planning;
        transition completePlan first planning then patientRegistered;
        transition beginNavigation first patientRegistered then navigating;
        transition reachTarget first navigating then targetReached;
        transition stabilizeCatheter first targetReached then fieldHolding;
        transition pauseProcedure first navigating then paused;
        transition resumeProcedure first paused then navigating;
        transition safetyFaultFromPlanning first planning then faulted;
        transition safetyFaultFromRegistration first patientRegistered then faulted;
        transition safetyFaultFromNavigation first navigating then faulted;
        transition resetAfterFault first faulted then idle;
        transition endProcedure first fieldHolding then shutdown;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall remotely navigate a magnetically tipped catheter through patient anatomy by coordinating imaging, planning, magnetic field generation, catheter advancement, and safety supervision. */
    }

    requirement def MagneticFieldControlRequirement {
        doc /* The system shall generate commanded magnetic field vectors up to 0.10 T with field direction accuracy within 3 degrees and command latency below 50 ms. */
    }

    requirement def CatheterNavigationAccuracyRequirement {
        doc /* The system shall maintain catheter tip position estimation error at or below 1.5 mm during image-guided navigation. */
    }

    requirement def PatientSafetyRequirement {
        doc /* The system shall inhibit magnetic field changes and catheter advancement within 100 ms when emergency stop, excessive tip force, excessive radiation dose rate, or magnetic field limit violation is detected. */
    }

    requirement def RadiationManagementRequirement {
        doc /* The imaging subsystem shall support navigation while keeping fluoroscopy dose rate at or below 20 mGy per minute during normal operation. */
    }

    requirement def RoboticAdvancementRequirement {
        doc /* The robotic catheter advancer shall translate the catheter with accuracy at or below 0.2 mm and shall not exceed 10 mm per second insertion speed. */
    }

    satisfy PrimaryFunctionRequirement by MagneticNavigationSystem;
    satisfy MagneticFieldControlRequirement by MagneticFieldGenerator;
    satisfy CatheterNavigationAccuracyRequirement by NavigationController;
    satisfy PatientSafetyRequirement by SafetyManager;
    satisfy RadiationManagementRequirement by ImagingSubsystem;
    satisfy RoboticAdvancementRequirement by RoboticCatheterAdvancer;
}