package AlternatingElectricFieldTherapyModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Duration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Impedance :> ISQ::resistance {
        unit = SI::ohm;
    }

    attribute def ElectricFieldStrength :> ISQ::electricFieldStrength {
        unit = SI::voltPerMeter;
    }

    attribute def Percent {
        :>> range = "0..100";
    }

    enum def TherapyMode {
        enum off;
        enum standby;
        enum impedanceCheck;
        enum deliveringTherapy;
        enum paused;
        enum alarm;
        enum service;
    }

    enum def AlarmKind {
        enum none;
        enum highTemperature;
        enum poorContact;
        enum excessiveCurrent;
        enum lowBattery;
        enum generatorFault;
        enum treatmentInterrupted;
    }

    enum def ElectrodeLocation {
        enum anterior;
        enum posterior;
        enum leftLateral;
        enum rightLateral;
        enum superior;
        enum inferior;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
        attribute phaseAngle : Real;
    }

    item def AlternatingFieldCommand {
        attribute targetFrequency : Frequency;
        attribute targetAmplitude : Voltage;
        attribute dutyCycle : Percent;
        attribute activePairId : Integer;
    }

    item def SkinContactMeasurement {
        attribute impedance : Impedance;
        attribute contactQuality : Percent;
        attribute electrodeTemperature : Temperature;
    }

    item def TherapySessionPlan {
        attribute prescribedFrequency : Frequency;
        attribute prescribedFieldStrength : ElectricFieldStrength;
        attribute dailyTreatmentDuration : Duration;
        attribute maximumSkinTemperature : Temperature;
        attribute maximumCurrent : Current;
        attribute minimumContactQuality : Percent;
    }

    item def TherapyStatus {
        attribute mode : TherapyMode;
        attribute deliveredDuration : Duration;
        attribute activeAlarm : AlarmKind;
        attribute remainingBatteryPercent : Percent;
        attribute measuredFieldStrength : ElectricFieldStrength;
    }

    port def PowerInputPort {
        in item dcPower : ElectricalEnergy;
    }

    port def PowerOutputPort {
        out item acPower : ElectricalEnergy;
    }

    port def SensorInputPort {
        in item contactMeasurement : SkinContactMeasurement;
    }

    port def CommandInputPort {
        in item sessionPlan : TherapySessionPlan;
        in item operatorStart : Boolean;
        in item operatorPause : Boolean;
        in item operatorStop : Boolean;
    }

    port def StatusOutputPort {
        out item status : TherapyStatus;
    }

    port def FieldApplicatorPort {
        out item appliedField : ElectricalEnergy;
        in item contactMeasurement : SkinContactMeasurement;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 14.4 [SI::volt];
        attribute capacityWh : Real = 90.0;
        attribute stateOfCharge : Percent;
        attribute lowChargeThreshold : Percent = 15.0;

        port powerOut : PowerOutputPort;

        action providePower {
            out item suppliedEnergy : ElectricalEnergy;
            first start;
            then regulateDcVoltage;
            then emitPower;
            action regulateDcVoltage;
            action emitPower {
                suppliedEnergy.voltage = nominalVoltage;
            }
        }
    }

    part def TherapyController {
        attribute mode : TherapyMode = TherapyMode::off;
        attribute activeAlarm : AlarmKind = AlarmKind::none;
        attribute targetFrequency : Frequency = 200000 [SI::hertz];
        attribute targetFieldStrength : ElectricFieldStrength = 150 [SI::voltPerMeter];
        attribute treatmentTimer : Duration = 0 [SI::second];

        port commandIn : CommandInputPort;
        port sensorIn : SensorInputPort;
        port commandOut : StatusOutputPort;

        action evaluateSafety {
            in item measurement : SkinContactMeasurement;
            in item plan : TherapySessionPlan;
            out item alarm : AlarmKind;

            if measurement.electrodeTemperature > plan.maximumSkinTemperature then {
                alarm = AlarmKind::highTemperature;
            } else if measurement.contactQuality < plan.minimumContactQuality then {
                alarm = AlarmKind::poorContact;
            } else {
                alarm = AlarmKind::none;
            }
        }

        state def TherapyControlStateMachine {
            state off;
            state standby;
            state checkingImpedance;
            state delivering;
            state paused;
            state alarmed;
            state service;

            initial then off;

            transition off_to_standby
                first off
                accept commandIn.operatorStart
                then standby;

            transition standby_to_check
                first standby
                accept commandIn.sessionPlan
                then checkingImpedance;

            transition check_to_deliver
                first checkingImpedance
                if sensorIn.contactMeasurement.contactQuality >= commandIn.sessionPlan.minimumContactQuality
                then delivering;

            transition check_to_alarm
                first checkingImpedance
                if sensorIn.contactMeasurement.contactQuality < commandIn.sessionPlan.minimumContactQuality
                then alarmed;

            transition deliver_to_pause
                first delivering
                accept commandIn.operatorPause
                then paused;

            transition pause_to_deliver
                first paused
                accept commandIn.operatorStart
                then delivering;

            transition deliver_to_alarm
                first delivering
                if sensorIn.contactMeasurement.electrodeTemperature > commandIn.sessionPlan.maximumSkinTemperature
                then alarmed;

            transition deliver_to_standby
                first delivering
                accept commandIn.operatorStop
                then standby;

            transition alarm_to_standby
                first alarmed
                accept commandIn.operatorStop
                then standby;
        }
    }

    part def FieldGenerator {
        attribute outputFrequency : Frequency = 200000 [SI::hertz];
        attribute outputVoltage : Voltage = 60 [SI::volt];
        attribute maxCurrent : Current = 2.0 [SI::ampere];
        attribute conversionEfficiency : Percent = 88.0;

        port powerIn : PowerInputPort;
        port fieldOut : FieldApplicatorPort;

        action synthesizeAlternatingField {
            in item command : AlternatingFieldCommand;
            out item generatedEnergy : ElectricalEnergy;

            first receiveCommand;
            then setOscillatorFrequency;
            then modulateAmplitude;
            then driveElectrodePair;

            action receiveCommand;
            action setOscillatorFrequency {
                outputFrequency = command.targetFrequency;
            }
            action modulateAmplitude {
                outputVoltage = command.targetAmplitude;
            }
            action driveElectrodePair {
                generatedEnergy.frequency = outputFrequency;
                generatedEnergy.voltage = outputVoltage;
            }
        }
    }

    part def ElectrodeArray {
        attribute location : ElectrodeLocation;
        attribute contactAreaCm2 : Real;
        attribute skinTemperature : Temperature = 32 [SI::degreeCelsius];
        attribute measuredImpedance : Impedance = 1000 [SI::ohm];
        attribute contactQuality : Percent = 95.0;

        port applicatorPort : FieldApplicatorPort;

        action coupleFieldToTissue {
            in item appliedEnergy : ElectricalEnergy;
            out item measurement : SkinContactMeasurement;

            first receiveAlternatingEnergy;
            then distributeFieldThroughGelLayer;
            then senseSkinInterface;

            action receiveAlternatingEnergy;
            action distributeFieldThroughGelLayer;
            action senseSkinInterface {
                measurement.impedance = measuredImpedance;
                measurement.contactQuality = contactQuality;
                measurement.electrodeTemperature = skinTemperature;
            }
        }
    }

    part def PatientTissueRegion {
        attribute tumorRegionDepthMm : Real = 25.0;
        attribute tissueConductivitySm : Real = 0.4;
        attribute achievedFieldStrength : ElectricFieldStrength = 150 [SI::voltPerMeter];

        port fieldIn : FieldApplicatorPort;

        action exposeDividingCellsToAlternatingField {
            in item appliedEnergy : ElectricalEnergy;
            out attribute fieldStrength : ElectricFieldStrength;

            first receiveField;
            then polarizeCellularStructures;
            then interfereWithMitoticAlignment;

            action receiveField;
            action polarizeCellularStructures;
            action interfereWithMitoticAlignment {
                fieldStrength = achievedFieldStrength;
            }
        }
    }

    part def UserInterface {
        attribute displayedMode : TherapyMode;
        attribute displayedAlarm : AlarmKind;
        attribute displayedDailyUseHours : Real;

        port commandPort : CommandInputPort;
        port statusPort : StatusOutputPort;

        action displayTherapyStatus {
            in item status : TherapyStatus;
            first updateModeIndicator;
            then updateAlarmIndicator;
            then updateTreatmentTimer;
            action updateModeIndicator {
                displayedMode = status.mode;
            }
            action updateAlarmIndicator {
                displayedAlarm = status.activeAlarm;
            }
            action updateTreatmentTimer;
        }
    }

    part def AlternatingElectricFieldTherapySystem {
        attribute primaryFunction : String =
            "Deliver low-intensity, intermediate-frequency alternating electric fields through external electrode arrays to the prescribed tissue region in order to disrupt proliferation of rapidly dividing pathological cells while monitoring patient safety and treatment continuity.";

        attribute prescribedPlan : TherapySessionPlan {
            :>> prescribedFrequency = 200000 [SI::hertz];
            :>> prescribedFieldStrength = 150 [SI::voltPerMeter];
            :>> dailyTreatmentDuration = 64800 [SI::second];
            :>> maximumSkinTemperature = 39 [SI::degreeCelsius];
            :>> maximumCurrent = 2.0 [SI::ampere];
            :>> minimumContactQuality = 80.0;
        }

        part battery : BatteryPack;
        part controller : TherapyController;
        part generator : FieldGenerator;
        part userInterface : UserInterface;
        part anteriorArray : ElectrodeArray {
            :>> location = ElectrodeLocation::anterior;
            :>> contactAreaCm2 = 25.0;
        }
        part posteriorArray : ElectrodeArray {
            :>> location = ElectrodeLocation::posterior;
            :>> contactAreaCm2 = 25.0;
        }
        part leftArray : ElectrodeArray {
            :>> location = ElectrodeLocation::leftLateral;
            :>> contactAreaCm2 = 22.0;
        }
        part rightArray : ElectrodeArray {
            :>> location = ElectrodeLocation::rightLateral;
            :>> contactAreaCm2 = 22.0;
        }
        part tissueRegion : PatientTissueRegion;

        port clinicianCommand : CommandInputPort;
        port systemStatus : StatusOutputPort;

        connect battery.powerOut to generator.powerIn;
        connect clinicianCommand to userInterface.commandPort;
        connect userInterface.commandPort to controller.commandIn;
        connect controller.commandOut to userInterface.statusPort;
        connect controller.commandOut to systemStatus;
        connect generator.fieldOut to anteriorArray.applicatorPort;
        connect generator.fieldOut to posteriorArray.applicatorPort;
        connect generator.fieldOut to leftArray.applicatorPort;
        connect generator.fieldOut to rightArray.applicatorPort;
        connect anteriorArray.applicatorPort to tissueRegion.fieldIn;
        connect posteriorArray.applicatorPort to tissueRegion.fieldIn;
        connect leftArray.applicatorPort to tissueRegion.fieldIn;
        connect rightArray.applicatorPort to tissueRegion.fieldIn;
        connect anteriorArray.applicatorPort to controller.sensorIn;
        connect posteriorArray.applicatorPort to controller.sensorIn;
        connect leftArray.applicatorPort to controller.sensorIn;
        connect rightArray.applicatorPort to controller.sensorIn;

        action conductTherapySession {
            in item plan : TherapySessionPlan;
            out item status : TherapyStatus;

            first receivePrescription;
            then verifyElectrodeContact;
            then deliverAlternatingFields;
            then monitorSafety;
            then recordTreatmentUse;

            action receivePrescription {
                controller.targetFrequency = plan.prescribedFrequency;
                controller.targetFieldStrength = plan.prescribedFieldStrength;
            }

            action verifyElectrodeContact {
                anteriorArray.coupleFieldToTissue;
                posteriorArray.coupleFieldToTissue;
                leftArray.coupleFieldToTissue;
                rightArray.coupleFieldToTissue;
            }

            action deliverAlternatingFields {
                generator.synthesizeAlternatingField;
                tissueRegion.exposeDividingCellsToAlternatingField;
            }

            action monitorSafety {
                controller.evaluateSafety;
            }

            action recordTreatmentUse {
                status.mode = controller.mode;
                status.deliveredDuration = controller.treatmentTimer;
                status.activeAlarm = controller.activeAlarm;
                status.remainingBatteryPercent = battery.stateOfCharge;
                status.measuredFieldStrength = tissueRegion.achievedFieldStrength;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The therapy system shall apply low-intensity alternating electric fields to a target tissue region through non-invasive electrode arrays as its primary therapeutic function. */

        subject therapySystem : AlternatingElectricFieldTherapySystem;

        require constraint {
            therapySystem.tissueRegion.achievedFieldStrength >= 100 [SI::voltPerMeter] and
            therapySystem.tissueRegion.achievedFieldStrength <= 250 [SI::voltPerMeter]
        }
    }

    requirement def FrequencyControlRequirement {
        doc
        /* The field generator shall maintain the prescribed intermediate-frequency alternating field within a clinically controlled tolerance during therapy delivery. */

        subject generator : FieldGenerator;
        subject plan : TherapySessionPlan;

        require constraint {
            generator.outputFrequency >= plan.prescribedFrequency * 0.95 and
            generator.outputFrequency <= plan.prescribedFrequency * 1.05
        }
    }

    requirement def SkinSafetyRequirement {
        doc
        /* The system shall pause therapy and raise an alarm when any electrode array exceeds the maximum permitted skin temperature. */

        subject controller : TherapyController;
        subject measurement : SkinContactMeasurement;
        subject plan : TherapySessionPlan;

        require constraint {
            measurement.electrodeTemperature <= plan.maximumSkinTemperature
        }
    }

    requirement def ContactQualityRequirement {
        doc
        /* The system shall verify adequate electrode-to-skin contact before and during field delivery. */

        subject measurement : SkinContactMeasurement;
        subject plan : TherapySessionPlan;

        require constraint {
            measurement.contactQuality >= plan.minimumContactQuality
        }
    }

    requirement def TreatmentContinuityRequirement {
        doc
        /* The system shall track delivered therapy time against the prescribed daily treatment duration and report interruptions to the user. */

        subject status : TherapyStatus;
        subject plan : TherapySessionPlan;

        require constraint {
            status.deliveredDuration <= plan.dailyTreatmentDuration
        }
    }

    satisfy PrimaryFunctionRequirement by AlternatingElectricFieldTherapySystem;
    satisfy FrequencyControlRequirement by FieldGenerator;
    satisfy SkinSafetyRequirement by TherapyController;
    satisfy ContactQualityRequirement by ElectrodeArray;
    satisfy TreatmentContinuityRequirement by UserInterface;
}