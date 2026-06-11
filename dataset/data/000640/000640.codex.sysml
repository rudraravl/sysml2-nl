package IncentiveSpirometerModel {
    import ScalarValues::*;
    import ISQ::*;

    attribute def Volume {
        :> ISQ::volume;
        unit = "mL";
    }

    attribute def FlowRate {
        :> ISQ::volumeFlowRate;
        unit = "mL/s";
    }

    attribute def Pressure {
        :> ISQ::pressure;
        unit = "Pa";
    }

    attribute def Duration {
        :> ISQ::time;
        unit = "s";
    }

    attribute def Count {
        :> ScalarValues::Integer;
    }

    attribute def BooleanFlag {
        :> ScalarValues::Boolean;
    }

    attribute def Percentage {
        :> ScalarValues::Real;
        unit = "%";
    }

    item def InspiredAir {
        attribute volume : Volume;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
        attribute oxygenFraction : Percentage;
    }

    item def ExhaledAir {
        attribute volume : Volume;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    item def PatientBreathEffort {
        attribute inspiratoryPressure : Pressure;
        attribute duration : Duration;
        attribute sustained : BooleanFlag;
    }

    item def TherapyFeedback {
        attribute currentInspiredVolume : Volume;
        attribute targetInspiredVolume : Volume;
        attribute targetReached : BooleanFlag;
        attribute holdTimeRemaining : Duration;
        attribute repetitionCount : Count;
    }

    item def CleaningStatus {
        attribute mouthpieceClean : BooleanFlag;
        attribute chamberClear : BooleanFlag;
        attribute oneWayValveFreeMoving : BooleanFlag;
    }

    port def PatientAirwayPort {
        in item effort : PatientBreathEffort;
        in item exhaledAir : ExhaledAir;
        out item inspiredAir : InspiredAir;
        out item feedback : TherapyFeedback;
    }

    port def AmbientAirPort {
        in item ambientAir : InspiredAir;
        out item ventedAir : ExhaledAir;
    }

    port def VisualFeedbackPort {
        out item feedback : TherapyFeedback;
    }

    port def ServiceInspectionPort {
        out item status : CleaningStatus;
    }

    action def DrawAirThroughSpirometer {
        in item effort : PatientBreathEffort;
        in item ambientAir : InspiredAir;
        out item deliveredAir : InspiredAir;
        out item measuredFeedback : TherapyFeedback;

        attribute minimumTherapeuticFlow : FlowRate = 100 [mL/s];
        attribute maximumComfortFlow : FlowRate = 900 [mL/s];

        assert constraint {
            deliveredAir.flowRate >= minimumTherapeuticFlow and
            deliveredAir.flowRate <= maximumComfortFlow
        }
    }

    action def MeasureInspiredVolume {
        in item deliveredAir : InspiredAir;
        out item feedback : TherapyFeedback;

        attribute measurementResolution : Volume = 50 [mL];
        attribute measurementRangeMinimum : Volume = 0 [mL];
        attribute measurementRangeMaximum : Volume = 4000 [mL];

        assert constraint {
            feedback.currentInspiredVolume >= measurementRangeMinimum and
            feedback.currentInspiredVolume <= measurementRangeMaximum
        }
    }

    action def ProvideVisualGoalFeedback {
        in item feedback : TherapyFeedback;
        out item displayedFeedback : TherapyFeedback;

        assert constraint {
            displayedFeedback.currentInspiredVolume == feedback.currentInspiredVolume and
            displayedFeedback.targetInspiredVolume == feedback.targetInspiredVolume
        }
    }

    action def HoldInspiratoryVolume {
        in item feedback : TherapyFeedback;
        out item sustainedFeedback : TherapyFeedback;

        attribute prescribedHoldDuration : Duration = 3 [s];

        assert constraint {
            sustainedFeedback.holdTimeRemaining <= prescribedHoldDuration
        }
    }

    action def PerformBreathingExercise {
        in item effort : PatientBreathEffort;
        in item ambientAir : InspiredAir;
        out item deliveredAir : InspiredAir;
        out item feedback : TherapyFeedback;

        first start;
        then action draw : DrawAirThroughSpirometer {
            in effort = PerformBreathingExercise::effort;
            in ambientAir = PerformBreathingExercise::ambientAir;
        }
        then action measure : MeasureInspiredVolume {
            in deliveredAir = draw.deliveredAir;
        }
        then action display : ProvideVisualGoalFeedback {
            in feedback = measure.feedback;
        }
        then action hold : HoldInspiratoryVolume {
            in feedback = display.displayedFeedback;
        }
        then done;

        bind deliveredAir = draw.deliveredAir;
        bind feedback = hold.sustainedFeedback;
    }

    state def SpirometerUseStateMachine {
        attribute currentVolume : Volume;
        attribute targetVolume : Volume;
        attribute holdDuration : Duration;
        attribute repetitionsCompleted : Count;

        state idle;
        state ready;
        state patientInhaling;
        state targetReached;
        state holdBreath;
        state resetForNextBreath;
        state sessionComplete;
        state cleaningRequired;

        transition initial then idle;

        transition idle_to_ready
            first idle
            accept event startTherapy
            then ready;

        transition ready_to_inhaling
            first ready
            accept event inhalationDetected
            if currentVolume < targetVolume
            then patientInhaling;

        transition inhaling_to_targetReached
            first patientInhaling
            accept event volumeUpdated
            if currentVolume >= targetVolume
            then targetReached;

        transition inhaling_to_reset
            first patientInhaling
            accept event inhalationStopped
            if currentVolume < targetVolume
            then resetForNextBreath;

        transition targetReached_to_hold
            first targetReached
            then holdBreath;

        transition hold_to_reset
            first holdBreath
            accept event holdTimerExpired
            then resetForNextBreath;

        transition reset_to_ready
            first resetForNextBreath
            accept event nextBreathRequested
            if repetitionsCompleted < 10
            then ready;

        transition reset_to_complete
            first resetForNextBreath
            accept event prescribedRepetitionsMet
            if repetitionsCompleted >= 10
            then sessionComplete;

        transition complete_to_cleaningRequired
            first sessionComplete
            accept event therapyEnded
            then cleaningRequired;
    }

    part def Mouthpiece {
        port patientPort : PatientAirwayPort;
        port chamberPort : PatientAirwayPort;

        attribute detachable : BooleanFlag = true;
        attribute internalDeadVolume : Volume = 20 [mL];
        attribute cleanAfterUseRequired : BooleanFlag = true;
    }

    part def OneWayValve {
        port patientSide : PatientAirwayPort;
        port chamberSide : PatientAirwayPort;

        attribute openingPressure : Pressure = 20 [Pa];
        attribute reverseLeakageAllowed : FlowRate = 5 [mL/s];

        assert constraint {
            reverseLeakageAllowed <= 10 [mL/s]
        }
    }

    part def FlowIndicator {
        port sensedAirPort : PatientAirwayPort;
        port displayPort : VisualFeedbackPort;

        attribute minimumMarkedFlow : FlowRate = 100 [mL/s];
        attribute optimalLowerFlow : FlowRate = 300 [mL/s];
        attribute optimalUpperFlow : FlowRate = 600 [mL/s];
        attribute maximumMarkedFlow : FlowRate = 900 [mL/s];

        assert constraint {
            optimalLowerFlow < optimalUpperFlow and
            minimumMarkedFlow < optimalLowerFlow and
            optimalUpperFlow < maximumMarkedFlow
        }
    }

    part def VolumeChamber {
        port inlet : AmbientAirPort;
        port outlet : PatientAirwayPort;
        port visualScale : VisualFeedbackPort;

        attribute capacity : Volume = 4000 [mL];
        attribute scaleIncrement : Volume = 250 [mL];
        attribute measurementResolution : Volume = 50 [mL];

        assert constraint {
            capacity >= 3000 [mL] and
            measurementResolution <= scaleIncrement
        }
    }

    part def GoalMarker {
        port visualPort : VisualFeedbackPort;

        attribute prescribedTargetVolume : Volume = 1500 [mL];
        attribute adjustableMinimum : Volume = 500 [mL];
        attribute adjustableMaximum : Volume = 4000 [mL];

        assert constraint {
            prescribedTargetVolume >= adjustableMinimum and
            prescribedTargetVolume <= adjustableMaximum
        }
    }

    part def PistonOrFloat {
        port chamberInterface : PatientAirwayPort;
        port visualPort : VisualFeedbackPort;

        attribute indicatedVolume : Volume;
        attribute frictionEquivalentPressure : Pressure = 15 [Pa];

        assert constraint {
            frictionEquivalentPressure <= 30 [Pa]
        }
    }

    part def OuterHousing {
        port ambientPort : AmbientAirPort;
        port servicePort : ServiceInspectionPort;

        attribute transparent : BooleanFlag = true;
        attribute stableOnFlatSurface : BooleanFlag = true;
        attribute cleanableMaterial : BooleanFlag = true;
    }

    part def IncentiveSpirometer {
        port patientInterface : PatientAirwayPort;
        port ambientInterface : AmbientAirPort;
        port feedbackInterface : VisualFeedbackPort;
        port serviceInterface : ServiceInspectionPort;

        part mouthpiece : Mouthpiece;
        part valve : OneWayValve;
        part flowIndicator : FlowIndicator;
        part chamber : VolumeChamber;
        part goalMarker : GoalMarker;
        part piston : PistonOrFloat;
        part housing : OuterHousing;

        attribute prescribedTargetVolume : Volume = 1500 [mL];
        attribute sessionRepetitionGoal : Count = 10;
        attribute inspiratoryHoldGoal : Duration = 3 [s];
        attribute maximumUsableVolume : Volume = 4000 [mL];
        attribute minimumTherapeuticInspiredVolume : Volume = 500 [mL];

        perform action breathingExercise : PerformBreathingExercise;
        exhibit state useStates : SpirometerUseStateMachine;

        connect patientInterface to mouthpiece.patientPort;
        connect mouthpiece.chamberPort to valve.patientSide;
        connect valve.chamberSide to chamber.outlet;
        connect chamber.outlet to piston.chamberInterface;
        connect chamber.outlet to flowIndicator.sensedAirPort;
        connect ambientInterface to housing.ambientPort;
        connect housing.ambientPort to chamber.inlet;
        connect piston.visualPort to feedbackInterface;
        connect flowIndicator.displayPort to feedbackInterface;
        connect chamber.visualScale to feedbackInterface;
        connect goalMarker.visualPort to feedbackInterface;
        connect housing.servicePort to serviceInterface;

        bind goalMarker.prescribedTargetVolume = prescribedTargetVolume;
        bind chamber.capacity = maximumUsableVolume;

        assert constraint {
            prescribedTargetVolume <= maximumUsableVolume and
            prescribedTargetVolume >= minimumTherapeuticInspiredVolume and
            sessionRepetitionGoal >= 5 and
            sessionRepetitionGoal <= 20
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject spirometer : IncentiveSpirometer;

        doc /* The incentive spirometer shall encourage slow, deep inspiration by providing visible feedback of inspired volume and flow so that a patient can exercise lung expansion after surgery, illness, or prolonged immobility. */

        require constraint {
            spirometer.prescribedTargetVolume >= 500 [mL] and
            spirometer.maximumUsableVolume >= 3000 [mL]
        }
    }

    requirement def VolumeMeasurementRequirement {
        subject chamber : VolumeChamber;

        doc /* The volume chamber shall indicate inspired volume over a range suitable for adult breathing exercises with readable increments. */

        require constraint {
            chamber.capacity >= 3000 [mL] and
            chamber.scaleIncrement <= 250 [mL] and
            chamber.measurementResolution <= 50 [mL]
        }
    }

    requirement def FlowGuidanceRequirement {
        subject indicator : FlowIndicator;

        doc /* The flow indicator shall guide the patient toward a slow sustained inspiratory flow rather than a short rapid inhalation. */

        require constraint {
            indicator.optimalLowerFlow >= 250 [mL/s] and
            indicator.optimalUpperFlow <= 700 [mL/s]
        }
    }

    requirement def ReverseFlowProtectionRequirement {
        subject valve : OneWayValve;

        doc /* The one-way valve shall limit reverse airflow from the patient into the chamber to reduce contamination and preserve inspiratory measurement accuracy. */

        require constraint {
            valve.reverseLeakageAllowed <= 10 [mL/s]
        }
    }

    requirement def PatientFeedbackRequirement {
        subject spirometer : IncentiveSpirometer;

        doc /* The system shall provide immediate visual feedback showing current inspired volume, target volume, and whether the patient has achieved the prescribed goal. */

        require constraint {
            spirometer.prescribedTargetVolume <= spirometer.maximumUsableVolume
        }
    }

    requirement def CleaningRequirement {
        subject housing : OuterHousing;

        doc /* Patient-contact and airflow surfaces shall be cleanable and inspectable after use. */

        require constraint {
            housing.cleanableMaterial == true and
            housing.transparent == true
        }
    }

    part spirometerSystem : IncentiveSpirometer {
        attribute prescribedTargetVolume = 1500 [mL];
        attribute sessionRepetitionGoal = 10;
        attribute inspiratoryHoldGoal = 3 [s];
        attribute maximumUsableVolume = 4000 [mL];
        attribute minimumTherapeuticInspiredVolume = 500 [mL];
    }

    satisfy PrimaryFunctionRequirement by spirometerSystem;
    satisfy PatientFeedbackRequirement by spirometerSystem;
    satisfy VolumeMeasurementRequirement by spirometerSystem.chamber;
    satisfy FlowGuidanceRequirement by spirometerSystem.flowIndicator;
    satisfy ReverseFlowProtectionRequirement by spirometerSystem.valve;
    satisfy CleaningRequirement by spirometerSystem.housing;
}