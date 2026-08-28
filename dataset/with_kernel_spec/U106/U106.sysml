package PtosisCrutchSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;

    part def MountingPoint;

    part def EyeglassFrame {
        doc /* Durable titanium alloy frame serving as the mounting structure. */
        attribute material : String = "Titanium Alloy";
        part leftMount : MountingPoint[1];
        part rightMount : MountingPoint[1];
    }

    part def CrutchBar {
        doc /* Thin adjustable bar extending from the frame towards the eye. */
        attribute barLength :> length = 15 [mm];
        attribute barAngle :> planeAngle = 30 [degree];
        attribute material : String = "Stainless Steel";
    }

    part def ContactPad {
        doc /* Soft medical-grade silicone pad resting on the upper eyelid. */
        attribute material : String = "Medical-Grade Silicone";
        attribute contactArea :> area = 50 [mm^2];
        attribute appliedPressure :> pressure;
    }

    part def AdjustmentScrew {
        doc /* Precision screw for tuning crutch bar position and angle. */
        attribute threadPitch :> length = 0.5 [mm];
        attribute adjustmentRange :> length = 10 [mm];
    }

    part def UpperEyelid {
        doc /* User eyelid context for force application and droop assessment. */
        attribute droopSeverity :> length;
        attribute tissueTolerance :> pressure;
    }

    event irritationEvent;

    action def EvaluateDroop {
        doc /* Assess degree of eyelid droop to calculate necessary support force and optimal position. */
        in eyelidDroop :> length;
        out requiredForce :> force;
        out optimalAngle :> planeAngle;
    }

    action def AdjustPosition {
        doc /* Set crutch bar position and angle to calculated values. */
        in targetAngle :> planeAngle;
        in targetLength :> length;
        out isSet : Boolean;
    }

    action def ApplySupport {
        doc /* Apply gentle, constant force to hold eyelid in elevated position. */
        in supportForce :> force;
        out currentPressure :> pressure;
    }

    action def DetectIrritation {
        doc /* Monitor for user discomfort or tissue irritation signals. */
        out irritationDetected : Boolean;
    }

    action def Readjust {
        doc /* Modify position and angle if irritation is detected. */
        in newAngle :> planeAngle;
        out isSet : Boolean;
    }

    part def SupportAssembly {
        doc /* Adjustable support unit for a single affected eye. */
        attribute liftForce :> force;
        part crutchBar : CrutchBar[1];
        part contactPad : ContactPad[1];
        part adjustmentScrew : AdjustmentScrew[1];

        connect crutchBar to contactPad;
        connect adjustmentScrew to crutchBar;

        state machine operation {
            doc /* Operational phases: evaluation, adjustment, continuous support, and readjustment. */
            state evaluating;
            state adjusting;
            state supporting;
            state readjusting;

            transition from evaluating to adjusting;
            transition from adjusting to supporting;
            transition from supporting to readjusting when irritationEvent;
            transition from readjusting to supporting;
        }
    }

    connection def BarPadConnection {
        end bar : CrutchBar[1];
        end pad : ContactPad[1];
    }

    connection def AdjustmentConnection {
        end screw : AdjustmentScrew[1];
        end bar : CrutchBar[1];
    }

    connection def MountingConnection {
        end frameMount : MountingPoint[1];
        end support : SupportAssembly[1];
    }

    connection def EyelidContact {
        end pad : ContactPad[1];
        end eyelid : UpperEyelid[1];
    }

    part def PtosisCrutchDevice {
        doc /* Complete ptosis crutch system mounted on eyeglass frame. */
        part frame : EyeglassFrame[1];
        part leftSupport : SupportAssembly[0..1];
        part rightSupport : SupportAssembly[0..1];

        connect frame.leftMount to leftSupport;
        connect frame.rightMount to rightSupport;
    }

    part def User {
        part leftEyelid : UpperEyelid[1];
        part rightEyelid : UpperEyelid[1];
    }

    part system : PtosisCrutchDevice {
        part user : User[1];
        connect leftSupport.contactPad to user.leftEyelid;
        connect rightSupport.contactPad to user.rightEyelid;
    }

    requirement def MaxPressureRequirement {
        doc /* The contact pressure on the eyelid shall not exceed the maximum safe pressure to prevent tissue damage. */
        subject pad : ContactPad;
        attribute maxSafePressure :> pressure = 4 [kPa];
        require constraint { pad.appliedPressure <= maxSafePressure }
    }

    requirement def ForceSufficiencyRequirement {
        doc /* The support force shall be sufficient to lift the eyelid to clear the pupil. */
        subject assembly : SupportAssembly;
        attribute requiredLiftForce :> force;
        require constraint { assembly.liftForce >= requiredLiftForce }
    }

    requirement def NonSurgicalSolutionRequirement {
        doc /* The device shall provide a non-surgical mechanical lift of the eyelid. */
        subject device : PtosisCrutchDevice;
    }

    requirement def VisionClearanceRequirement {
        doc /* The crutch shall elevate the eyelid sufficiently to clear the pupil and restore unobstructed vision. */
        subject assembly : SupportAssembly;
        subject eyelid : UpperEyelid;
        attribute requiredClearance :> length;
        require constraint { assembly.crutchBar.barLength >= eyelid.droopSeverity }
    }
}
