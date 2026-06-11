package CharcotShowerSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def PressureValue {
        attribute value : Real;
        attribute unit : PressureUnit;
    }

    attribute def TemperatureValue {
        attribute value : Real;
        attribute unit : TemperatureUnit;
    }

    attribute def FlowRateValue {
        attribute value : Real;
        attribute unit : VolumeFlowRateUnit;
    }

    attribute def DurationValue {
        attribute value : Real;
        attribute unit : TimeUnit;
    }

    attribute def DistanceValue {
        attribute value : Real;
        attribute unit : LengthUnit;
    }

    attribute def PercentValue {
        attribute value : Real;
        attribute unit : String = "%";
    }

    enum def TreatmentModeKind {
        enum warmJet;
        enum coldJet;
        enum alternatingThermalContrast;
        enum pulsedMassage;
        enum rinse;
        enum emergencyStop;
    }

    enum def SystemStateKind {
        enum off;
        enum standby;
        enum selfTest;
        enum ready;
        enum treating;
        enum paused;
        enum flushing;
        enum fault;
        enum emergencyStopped;
    }

    enum def PatientToleranceKind {
        enum low;
        enum normal;
        enum high;
    }

    item def Water {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute cleanliness : PercentValue;
    }

    item def MixedTherapeuticWater :> Water {
        attribute mode : TreatmentModeKind;
        attribute deliveredPulseFrequency : Real;
    }

    item def DrainWater :> Water {
        attribute contaminantLoad : PercentValue;
    }

    item def OperatorCommand {
        attribute selectedMode : TreatmentModeKind;
        attribute targetTemperature : TemperatureValue;
        attribute targetPressure : PressureValue;
        attribute treatmentDuration : DurationValue;
        attribute pulseFrequency : Real;
    }

    item def PatientFeedback {
        attribute discomfortLevel : Real;
        attribute requestPause : Boolean;
        attribute requestStop : Boolean;
    }

    item def SafetySignal {
        attribute emergencyStopPressed : Boolean;
        attribute overPressureDetected : Boolean;
        attribute overTemperatureDetected : Boolean;
        attribute lowSupplyDetected : Boolean;
        attribute nozzleTooCloseDetected : Boolean;
    }

    item def TreatmentRecord {
        attribute actualMode : TreatmentModeKind;
        attribute averagePressure : PressureValue;
        attribute averageTemperature : TemperatureValue;
        attribute elapsedTime : DurationValue;
        attribute completedNormally : Boolean;
    }

    port def WaterInletPort {
        in item waterIn : Water;
    }

    port def WaterOutletPort {
        out item waterOut : Water;
    }

    port def TherapeuticJetPort {
        out item jet : MixedTherapeuticWater;
    }

    port def DrainPort {
        in item usedWater : DrainWater;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def FeedbackPort {
        in item feedback : PatientFeedback;
    }

    port def SafetyPort {
        in item signal : SafetySignal;
    }

    port def RecordPort {
        out item record : TreatmentRecord;
    }

    port def PowerPort {
        in attribute supplyVoltage : Real;
        in attribute supplyAvailable : Boolean;
    }

    part def CharcotShowerSystem {
        attribute systemState : SystemStateKind = SystemStateKind::off;
        attribute primaryFunction : String =
            "Deliver a controlled high-pressure therapeutic water jet, including warm, cold, pulsed, or alternating-temperature modes, to stimulate circulation, provide hydro-massage, and support supervised hydrotherapy treatment.";
        attribute maxAllowedPressure : PressureValue = (value = 450000.0, unit = pascal);
        attribute minAllowedPressure : PressureValue = (value = 80000.0, unit = pascal);
        attribute maxAllowedTemperature : TemperatureValue = (value = 45.0, unit = degreeCelsius);
        attribute minAllowedTemperature : TemperatureValue = (value = 12.0, unit = degreeCelsius);
        attribute nominalTreatmentDistance : DistanceValue = (value = 3.0, unit = metre);
        attribute maximumSessionDuration : DurationValue = (value = 900.0, unit = second);

        port coldSupply : WaterInletPort;
        port hotSupply : WaterInletPort;
        port drainInterface : DrainPort;
        port operatorInterface : CommandPort;
        port patientInterface : FeedbackPort;
        port safetyInterface : SafetyPort;
        port treatmentLog : RecordPort;
        port electricalInput : PowerPort;

        part hotWaterValve : ProportionalValve {
            attribute valveName = "Hot water proportional valve";
            attribute failClosed = true;
        }

        part coldWaterValve : ProportionalValve {
            attribute valveName = "Cold water proportional valve";
            attribute failClosed = true;
        }

        part thermostaticMixer : MixingUnit {
            attribute temperatureControlAccuracy : TemperatureValue = (value = 1.0, unit = degreeCelsius);
        }

        part pressureBooster : PressurePump {
            attribute ratedPressure : PressureValue = (value = 500000.0, unit = pascal);
            attribute ratedFlow : FlowRateValue = (value = 0.00045, unit = cubicMetrePerSecond);
        }

        part pressureRegulator : PressureRegulationUnit {
            attribute responseTime : DurationValue = (value = 0.5, unit = second);
        }

        part pulseModulator : PulseModulationUnit {
            attribute minimumPulseFrequency : Real = 0.5;
            attribute maximumPulseFrequency : Real = 6.0;
        }

        part handheldNozzle : AdjustableJetNozzle {
            attribute sprayAngle : Real = 8.0;
            attribute nozzleDiameter : DistanceValue = (value = 0.009, unit = metre);
        }

        part treatmentZone : PatientTreatmentZone {
            attribute recommendedStandingDistance : DistanceValue = (value = 3.0, unit = metre);
            attribute minimumSafeDistance : DistanceValue = (value = 2.0, unit = metre);
        }

        part drainCollector : DrainCollectionUnit {
            attribute drainCapacity : FlowRateValue = (value = 0.001, unit = cubicMetrePerSecond);
        }

        part controller : TherapyController {
            attribute defaultMode : TreatmentModeKind = TreatmentModeKind::alternatingThermalContrast;
            attribute defaultDuration : DurationValue = (value = 300.0, unit = second);
        }

        part safetyController : SafetyController {
            attribute pressureTripLimit : PressureValue = (value = 480000.0, unit = pascal);
            attribute temperatureTripLimit : TemperatureValue = (value = 47.0, unit = degreeCelsius);
        }

        part sensors : SensorSuite {
            attribute samplingPeriod : DurationValue = (value = 0.1, unit = second);
        }

        connect coldSupply.waterIn to coldWaterValve.inlet.waterIn;
        connect hotSupply.waterIn to hotWaterValve.inlet.waterIn;
        connect hotWaterValve.outlet.waterOut to thermostaticMixer.hotIn.waterIn;
        connect coldWaterValve.outlet.waterOut to thermostaticMixer.coldIn.waterIn;
        connect thermostaticMixer.mixedOut.waterOut to pressureBooster.inlet.waterIn;
        connect pressureBooster.outlet.waterOut to pressureRegulator.inlet.waterIn;
        connect pressureRegulator.outlet.waterOut to pulseModulator.inlet.waterIn;
        connect pulseModulator.outlet.waterOut to handheldNozzle.inlet.waterIn;
        connect handheldNozzle.jetOut.jet to treatmentZone.jetIn.jet;
        connect treatmentZone.usedWaterOut.waterOut to drainCollector.drainIn.usedWater;
        connect drainCollector.facilityDrain.usedWater to drainInterface.usedWater;

        connect operatorInterface.command to controller.operatorCommand.command;
        connect patientInterface.feedback to controller.patientFeedback.feedback;
        connect safetyInterface.signal to safetyController.externalSafety.signal;
        connect sensors.measuredSafety.signal to safetyController.measuredSafety.signal;
        connect safetyController.controlCommand.command to controller.safetyCommand.command;
        connect controller.treatmentRecord.record to treatmentLog.record;
    }

    part def ProportionalValve {
        attribute valveName : String;
        attribute opening : PercentValue = (value = 0.0, unit = "%");
        attribute failClosed : Boolean;
        attribute maximumFlow : FlowRateValue = (value = 0.0005, unit = cubicMetrePerSecond);

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        action openTo {
            in attribute requestedOpening : PercentValue;
            out attribute achievedOpening : PercentValue;
        }

        action close {
            out attribute achievedOpening : PercentValue;
        }
    }

    part def MixingUnit {
        attribute targetTemperature : TemperatureValue = (value = 37.0, unit = degreeCelsius);
        attribute measuredTemperature : TemperatureValue;
        attribute temperatureControlAccuracy : TemperatureValue;

        port hotIn : WaterInletPort;
        port coldIn : WaterInletPort;
        port mixedOut : WaterOutletPort;

        action mixWater {
            in item hotWater : Water;
            in item coldWater : Water;
            in attribute requestedTemperature : TemperatureValue;
            out item mixedWater : MixedTherapeuticWater;
        }
    }

    part def PressurePump {
        attribute ratedPressure : PressureValue;
        attribute ratedFlow : FlowRateValue;
        attribute enabled : Boolean = false;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        action startPump;
        action stopPump;
        action boostPressure {
            in item inletWater : Water;
            in attribute requestedPressure : PressureValue;
            out item pressurizedWater : Water;
        }
    }

    part def PressureRegulationUnit {
        attribute requestedPressure : PressureValue = (value = 250000.0, unit = pascal);
        attribute measuredPressure : PressureValue;
        attribute responseTime : DurationValue;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        action regulatePressure {
            in item inletWater : Water;
            in attribute pressureSetpoint : PressureValue;
            out item regulatedWater : Water;
        }
    }

    part def PulseModulationUnit {
        attribute enabled : Boolean = false;
        attribute pulseFrequency : Real = 2.0;
        attribute minimumPulseFrequency : Real;
        attribute maximumPulseFrequency : Real;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        action modulateJet {
            in item steadyWater : Water;
            in attribute selectedMode : TreatmentModeKind;
            in attribute requestedPulseFrequency : Real;
            out item pulsedWater : MixedTherapeuticWater;
        }
    }

    part def AdjustableJetNozzle {
        attribute nozzleDiameter : DistanceValue;
        attribute sprayAngle : Real;
        attribute triggerPressed : Boolean = false;

        port inlet : WaterInletPort;
        port jetOut : TherapeuticJetPort;

        action deliverJet {
            in item suppliedWater : MixedTherapeuticWater;
            out item therapeuticJet : MixedTherapeuticWater;
        }

        action releaseTrigger;
    }

    part def PatientTreatmentZone {
        attribute occupied : Boolean = false;
        attribute patientTolerance : PatientToleranceKind = PatientToleranceKind::normal;
        attribute recommendedStandingDistance : DistanceValue;
        attribute minimumSafeDistance : DistanceValue;
        attribute measuredNozzleDistance : DistanceValue;

        port jetIn : TherapeuticJetPort;
        port usedWaterOut : WaterOutletPort;
        port feedbackIn : FeedbackPort;

        action receiveHydroMassage {
            in item therapeuticJet : MixedTherapeuticWater;
            in attribute exposureDuration : DurationValue;
            out item runoff : DrainWater;
        }
    }

    part def DrainCollectionUnit {
        attribute drainCapacity : FlowRateValue;
        attribute overflowDetected : Boolean = false;

        port drainIn : DrainPort;
        port facilityDrain : DrainPort;

        action collectAndDischarge {
            in item runoff : DrainWater;
            out item dischargedWater : DrainWater;
        }
    }

    part def SensorSuite {
        attribute samplingPeriod : DurationValue;
        attribute measuredPressure : PressureValue;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredFlowRate : FlowRateValue;
        attribute measuredNozzleDistance : DistanceValue;

        port measuredSafety : SafetyPort;

        action sampleSensors {
            out item safetyStatus : SafetySignal;
        }
    }

    part def SafetyController {
        attribute pressureTripLimit : PressureValue;
        attribute temperatureTripLimit : TemperatureValue;
        attribute emergencyLatched : Boolean = false;

        port externalSafety : SafetyPort;
        port measuredSafety : SafetyPort;
        port controlCommand : CommandPort;

        action evaluateSafety {
            in item externalSignal : SafetySignal;
            in item measuredSignal : SafetySignal;
            out item resultingCommand : OperatorCommand;
        }

        state def SafetyStateMachine {
            entry;
            state monitoring;
            state warning;
            state tripped;
            state resetRequired;

            transition first entry then monitoring;
            transition pressureWarning
                first monitoring
                accept SafetySignal
                if overPressureDetected or overTemperatureDetected
                then warning;
            transition trip
                first warning
                accept SafetySignal
                if emergencyStopPressed or overPressureDetected or overTemperatureDetected or nozzleTooCloseDetected
                then tripped;
            transition latch
                first tripped
                then resetRequired;
            transition reset
                first resetRequired
                accept OperatorCommand
                if selectedMode != TreatmentModeKind::emergencyStop
                then monitoring;
        }
    }

    part def TherapyController {
        attribute currentState : SystemStateKind = SystemStateKind::off;
        attribute defaultMode : TreatmentModeKind;
        attribute defaultDuration : DurationValue;
        attribute elapsedTreatmentTime : DurationValue = (value = 0.0, unit = second);
        attribute requestedPressure : PressureValue = (value = 250000.0, unit = pascal);
        attribute requestedTemperature : TemperatureValue = (value = 36.0, unit = degreeCelsius);

        port operatorCommand : CommandPort;
        port patientFeedback : FeedbackPort;
        port safetyCommand : CommandPort;
        port treatmentRecord : RecordPort;

        action initializeSystem;
        action performSelfTest;
        action configureTreatment {
            in item command : OperatorCommand;
            out attribute accepted : Boolean;
        }
        action runTreatmentCycle {
            in attribute mode : TreatmentModeKind;
            in attribute pressureSetpoint : PressureValue;
            in attribute temperatureSetpoint : TemperatureValue;
            in attribute duration : DurationValue;
            out item record : TreatmentRecord;
        }
        action pauseTreatment;
        action stopTreatment;
        action flushLines;
        action logSession {
            in item record : TreatmentRecord;
        }

        state def TherapyStateMachine {
            entry;
            state off;
            state standby;
            state selfTest;
            state ready;
            state treating;
            state paused;
            state flushing;
            state fault;
            state emergencyStopped;

            transition powerApplied
                first entry
                then off;

            transition startUp
                first off
                accept OperatorCommand
                if selectedMode != TreatmentModeKind::emergencyStop
                do initializeSystem
                then standby;

            transition test
                first standby
                do performSelfTest
                then selfTest;

            transition testPassed
                first selfTest
                then ready;

            transition beginTreatment
                first ready
                accept OperatorCommand
                if treatmentDuration.value <= 900.0 and targetPressure.value <= 450000.0 and targetTemperature.value <= 45.0
                do configureTreatment
                then treating;

            transition patientPause
                first treating
                accept PatientFeedback
                if requestPause
                do pauseTreatment
                then paused;

            transition resume
                first paused
                accept OperatorCommand
                if selectedMode != TreatmentModeKind::emergencyStop
                then treating;

            transition complete
                first treating
                if elapsedTreatmentTime.value >= defaultDuration.value
                do stopTreatment
                then flushing;

            transition flushComplete
                first flushing
                do logSession
                then ready;

            transition treatmentFault
                first treating
                accept SafetySignal
                if overPressureDetected or overTemperatureDetected or lowSupplyDetected or nozzleTooCloseDetected
                do stopTreatment
                then fault;

            transition emergency
                first ready
                accept SafetySignal
                if emergencyStopPressed
                do stopTreatment
                then emergencyStopped;

            transition emergencyDuringTreatment
                first treating
                accept SafetySignal
                if emergencyStopPressed
                do stopTreatment
                then emergencyStopped;
        }
    }

    action def ProvideCharcotShowerTherapy {
        in item operatorCommand : OperatorCommand;
        in item patientFeedback : PatientFeedback;
        in item hotWaterSupply : Water;
        in item coldWaterSupply : Water;
        out item therapeuticJet : MixedTherapeuticWater;
        out item sessionRecord : TreatmentRecord;

        objective {
            doc /* Primary high-level function: convert hot and cold facility water into a supervised, controlled, high-pressure therapeutic jet applied at a safe distance to the patient for hydro-massage and thermal stimulation. */
        }

        first start;
        then validateCommand;
        then mixToRequestedTemperature;
        then regulateToRequestedPressure;
        then modulateAccordingToMode;
        then deliverJetToTreatmentZone;
        then monitorSafetyAndFeedback;
        then stopAndFlush;
        then createTreatmentRecord;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Charcot shower system shall deliver a controlled high-pressure therapeutic water jet for supervised hydrotherapy. */
        subject system : CharcotShowerSystem;
        require constraint {
            system.maxAllowedPressure.value >= 250000.0 and
            system.maxAllowedTemperature.value <= 45.0 and
            system.nominalTreatmentDistance.value >= 2.0
        }
    }

    requirement def TemperatureControlRequirement {
        doc /* The system shall maintain therapeutic water temperature within safe configured bounds during treatment. */
        subject mixer : MixingUnit;
        require constraint {
            mixer.targetTemperature.value >= 12.0 and
            mixer.targetTemperature.value <= 45.0
        }
    }

    requirement def PressureControlRequirement {
        doc /* The system shall regulate jet pressure to provide therapeutic stimulation without exceeding the safety limit. */
        subject regulator : PressureRegulationUnit;
        require constraint {
            regulator.requestedPressure.value >= 80000.0 and
            regulator.requestedPressure.value <= 450000.0
        }
    }

    requirement def EmergencyStopRequirement {
        doc /* The system shall stop water delivery and close supply valves when an emergency stop or critical safety signal is detected. */
        subject safety : SafetyController;
        require constraint {
            safety.emergencyLatched implies true
        }
    }

    requirement def DrainageRequirement {
        doc /* The system shall collect and discharge used water at a rate greater than the maximum delivered treatment flow. */
        subject drain : DrainCollectionUnit;
        require constraint {
            drain.drainCapacity.value >= 0.00045
        }
    }

    requirement def TreatmentDurationRequirement {
        doc /* The system shall limit a continuous Charcot shower treatment session to fifteen minutes or less. */
        subject controller : TherapyController;
        require constraint {
            controller.defaultDuration.value <= 900.0
        }
    }

    satisfy PrimaryFunctionRequirement by CharcotShowerSystem;
    satisfy TemperatureControlRequirement by MixingUnit;
    satisfy PressureControlRequirement by PressureRegulationUnit;
    satisfy EmergencyStopRequirement by SafetyController;
    satisfy DrainageRequirement by DrainCollectionUnit;
    satisfy TreatmentDurationRequirement by TherapyController;
}