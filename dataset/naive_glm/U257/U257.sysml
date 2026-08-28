package IncentiveSpirometer {
    import ScalarValues::*;
    import MeasurementReferences::*;

    // =====================================================
    // UNIT DEFINITIONS
    // =====================================================

    attribute def milliLiter :> Unit {
        doc "Milliliter (mL), volume unit";
    }

    attribute def milliLiterPerSecond :> Unit {
        doc "Milliliter per second (mL/s), volumetric flow rate unit";
    }

    attribute def second :> Unit {
        doc "Second (s), time unit";
    }

    attribute def pascal :> Unit {
        doc "Pascal (Pa), pressure unit";
    }

    attribute def millimeter :> Unit {
        doc "Millimeter (mm), length unit";
    }

    attribute def gram :> Unit {
        doc "Gram (g), mass unit";
    }

    // =====================================================
    // VALUE TYPE DEFINITIONS
    // =====================================================

    value type VolumeValue :> Real {
        doc "Volume of air in milliliters (mL)";
        :>> unit = milliLiter;
    }

    value type FlowRateValue :> Real {
        doc "Volumetric flow rate in mL/s";
        :>> unit = milliLiterPerSecond;
    }

    value type DurationValue :> Real {
        doc "Time duration in seconds (s)";
        :>> unit = second;
    }

    value type PressureValue :> Real {
        doc "Pressure differential in Pascals (Pa)";
        :>> unit = pascal;
    }

    value type LengthValue :> Real {
        doc "Length in millimeters (mm)";
        :>> unit = millimeter;
    }

    value type DiameterValue :> Real {
        doc "Diameter in millimeters (mm)";
        :>> unit = millimeter;
    }

    value type MassValue :> Real {
        doc "Mass in grams (g)";
        :>> unit = gram;
    }

    // =====================================================
    // ENUMERATION DEFINITIONS
    // =====================================================

    enum def FlowRateStatus {
        doc "Flow rate status for patient inhalation speed feedback";
        literal tooLow;
        literal optimal;
        literal tooHigh;
    }

    enum def ExercisePhase {
        doc "Phase of the breathing exercise cycle";
        literal idle;
        literal inhaling;
        literal holding;
        literal exhaling;
        literal resetting;
    }

    // =====================================================
    // ITEM DEFINITIONS
    // =====================================================

    item def Air {
        doc "Atmospheric air drawn through the spirometer";
        attribute temperature : Real = 20;
        attribute humidityPercent : Real = 50;
    }

    item def Breath {
        doc "A single breath exercise recorded by the system";
        attribute inhaledVolume : VolumeValue;
        attribute peakFlowRate : FlowRateValue;
        attribute flowStatus : FlowRateStatus;
        attribute holdDuration : DurationValue;
    }

    // =====================================================
    // PORT DEFINITIONS
    // =====================================================

    port def AirFlowPort {
        doc "Port carrying air flow and pressure information between components";
        attribute volumetricFlowRate : FlowRateValue;
        attribute pressure : PressureValue;
        item air : Air;
    }

    // =====================================================
    // ACTION DEFINITIONS
    // =====================================================

    action def ComputeInhaledVolume {
        doc "Integrate flow rate over time to compute cumulative inhaled volume";
        in flowRate : FlowRateValue;
        in deltaTime : DurationValue;
        in previousVolume : VolumeValue;
        out currentVolume : VolumeValue;
    }

    action def AssessFlowRate {
        doc "Compare current flow rate against optimal range boundaries";
        in flowRate : FlowRateValue;
        in optimalMin : FlowRateValue;
        in optimalMax : FlowRateValue;
        out status : FlowRateStatus;
    }

    action def ResetIndicator {
        doc "Reset the volume piston and flow indicator ball to resting position";
        in currentVolume : VolumeValue;
        out resetVolume : VolumeValue;
    }

    // =====================================================
    // PART DEFINITIONS - COMPONENTS
    // =====================================================

    part def BaseUnit {
        doc "Stable base unit holding measurement chamber and flow coach, providing structural support and internal air manifold";
        attribute height : LengthValue = 150;
        attribute width : LengthValue = 80;
        attribute depth : LengthValue = 80;
        attribute baseMass : MassValue = 250;
        attribute isStable : Boolean = true;

        port chamberAirPort : AirFlowPort;
        port flowCoachAirPort : AirFlowPort;
        port tubeAirPort : AirFlowPort;
    }

    part def VolumePiston {
        doc "Piston or indicator inside the main measurement chamber that rises with patient inhalation";
        attribute position : Real = 0;
        attribute pistonMass : MassValue = 5;
        attribute maxPosition : Real = 100;
        attribute minPosition : Real = 0;
    }

    part def MeasurementChamber {
        doc "Large transparent chamber with volume scale markings for real-time visual feedback of inhaled volume";
        attribute maxVolume : VolumeValue = 5000;
        attribute currentVolume : VolumeValue = 0;
        attribute targetVolume : VolumeValue = 1500;
        attribute scaleIncrement : VolumeValue = 100;
        attribute chamberHeight : LengthValue = 200;
        attribute chamberDiameter : DiameterValue = 60;
        attribute isTransparent : Boolean = true;

        port airPort : AirFlowPort;

        part piston : VolumePiston;
    }

    part def FlowIndicatorBall {
        doc "Small ball in the flow rate coach chamber that indicates inhalation speed";
        attribute position : Real = 0;
        attribute ballMass : MassValue = 2;
        attribute maxPosition : Real = 50;
        attribute minPosition : Real = 0;
    }

    part def FlowRateCoach {
        doc "Flow rate indicator chamber providing feedback on the speed of patient inhalation";
        attribute optimalMinFlowRate : FlowRateValue = 200;
        attribute optimalMaxFlowRate : FlowRateValue = 500;
        attribute currentFlowRate : FlowRateValue = 0;
        attribute flowStatus : FlowRateStatus = FlowRateStatus::tooLow;
        attribute coachHeight : LengthValue = 100;
        attribute coachDiameter : DiameterValue = 30;
        attribute isTransparent : Boolean = true;

        port airPort : AirFlowPort;

        part ball : FlowIndicatorBall;
    }

    part def Mouthpiece {
        doc "Disposable patient mouthpiece for hygienic breathing interface";
        attribute isDisposable : Boolean = true;
        attribute mouthpieceDiameter : DiameterValue = 22;

        port patientPort : AirFlowPort;
        port devicePort : AirFlowPort;
    }

    part def FlexibleTube {
        doc "Flexible tube connecting the mouthpiece to the base unit";
        attribute tubeLength : LengthValue = 300;
        attribute tubeDiameter : DiameterValue = 15;
        attribute isFlexible : Boolean = true;

        port inletPort : AirFlowPort;
        port outletPort : AirFlowPort;
    }

    part def TargetVolumeAdjuster {
        doc "Adjustable target volume marker mechanism set by healthcare provider";
        attribute currentTarget : VolumeValue = 1500;
        attribute minTarget : VolumeValue = 100;
        attribute maxTarget : VolumeValue = 5000;
        attribute adjustmentStep : VolumeValue = 100;
    }

    // =====================================================
    // MAIN ASSEMBLY
    // =====================================================

    part def IncentiveSpirometer {
        doc "Complete incentive spirometer medical device for pulmonary therapy, encouraging slow, sustained, deep breaths";

        attribute prescribedTargetVolume : VolumeValue = 1500;
        attribute recommendedBreathHoldDuration : DurationValue = 5;
        attribute isReadyForUse : Boolean = true;
        attribute currentPhase : ExercisePhase = ExercisePhase::idle;

        port patientInterface : AirFlowPort;

        part base : BaseUnit;
        part chamber : MeasurementChamber {
            :>> targetVolume = prescribedTargetVolume;
        }
        part flowCoach : FlowRateCoach;
        part mouthpiece : Mouthpiece;
        part tube : FlexibleTube;
        part targetAdjuster : TargetVolumeAdjuster {
            :>> currentTarget = prescribedTargetVolume;
        }

        // Air flow connections
        connect chamber.airPort to base.chamberAirPort;
        connect flowCoach.airPort to base.flowCoachAirPort;
        connect base.tubeAirPort to tube.inletPort;
        connect tube.outletPort to mouthpiece.devicePort;
        connect mouthpiece.patientPort to patientInterface;

        // State machine for device usage behavior
        state deviceBehavior {
            state idle {
                doc "Device ready, waiting for patient to begin breathing exercise";
                entry / chamber.currentVolume = 0;
            }

            state inhaling {
                doc "Patient inhaling, piston rising in chamber, flow coach active";
                do : ComputeInhaledVolume;
                do : AssessFlowRate;
            }

            state holding {
                doc "Target volume reached, patient holds breath for recommended duration";
            }

            state exhaling {
                doc "Patient exhales, piston returns to bottom position";
            }

            state resetting {
                doc "System resetting for next breathing exercise";
                do : ResetIndicator;
            }

            transition startInhalation from idle to inhaling when patientInterface.volumetricFlowRate > 0;
            transition reachTargetVolume from inhaling to holding when chamber.currentVolume >= prescribedTargetVolume;
            transition breathHoldComplete from holding to exhaling when recommendedBreathHoldDuration == 0;
            transition breathOut from exhaling to resetting when patientInterface.volumetricFlowRate <= 0;
            transition resetComplete from resetting to idle when chamber.currentVolume == 0;
        }
    }

    // =====================================================
    // REQUIREMENT DEFINITIONS
    // =====================================================

    requirement def PulmonaryTherapyDeviceRequirement {
        doc "The system shall function as an incentive spirometer for pulmonary therapy, helping patients improve lung function by encouraging slow, sustained, deep breaths to prevent respiratory complications";
    }

    requirement def VisualFeedbackRequirement {
        doc "The system shall provide real-time visual feedback of inhaled volume through a transparent measurement chamber with volume scale markings in milliliters";
        attribute minDisplayVolume : VolumeValue = 0;
        attribute maxDisplayVolume : VolumeValue = 5000;
        attribute scaleUnitLabel : String = "mL";
    }

    requirement def FlowRateCoachingRequirement {
        doc "The system shall include a flow rate coach that indicates whether the patient inhalation flow is too low, optimal, or too high to encourage slow steady breathing";
        attribute optimalMinFlowRate : FlowRateValue = 200;
        attribute optimalMaxFlowRate : FlowRateValue = 500;
    }

    requirement def TargetVolumeAdjustmentRequirement {
        doc "The system shall allow a healthcare provider to adjust the prescribed target volume for the patient";
        attribute minAdjustableTarget : VolumeValue = 100;
        attribute maxAdjustableTarget : VolumeValue = 5000;
    }

    requirement def BreathHoldGuidanceRequirement {
        doc "The system shall instruct the patient to hold their breath for a recommended duration after reaching the target volume before exhaling";
        attribute recommendedHoldDuration : DurationValue = 5;
    }

    requirement def SystemResetRequirement {
        doc "The system shall reset after each breathing exercise with the volume piston returning to the bottom position, ready for the next cycle";
    }

    requirement def BaseStabilityRequirement {
        doc "The base unit shall be stable enough to support the measurement chamber and prevent tipping during normal use";
        attribute minimumBaseMass : MassValue = 100;
    }

    requirement def HygieneRequirement {
        doc "The mouthpiece shall be disposable to maintain hygiene between patient uses";
        attribute isDisposable : Boolean = true;
    }

    requirement def FlexibleConnectionRequirement {
        doc "A flexible tube shall connect the mouthpiece to the measurement chamber to allow comfortable patient positioning";
        attribute minimumTubeLength : LengthValue = 200;
    }

    // =====================================================
    // REQUIREMENT SATISFACTION
    // =====================================================

    satisfaction of PulmonaryTherapyDeviceRequirement by IncentiveSpirometer;
    satisfaction of VisualFeedbackRequirement by chamber;
    satisfaction of FlowRateCoachingRequirement by flowCoach;
    satisfaction of TargetVolumeAdjustmentRequirement by targetAdjuster;
    satisfaction of BreathHoldGuidanceRequirement by IncentiveSpirometer;
    satisfaction of SystemResetRequirement by deviceBehavior;
    satisfaction of BaseStabilityRequirement by base;
    satisfaction of HygieneRequirement by mouthpiece;
    satisfaction of FlexibleConnectionRequirement by tube;
}
