package MedicalDeviceDesignModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    enum def TherapyMode {
        enum continuous;
        enum bolus;
        enum keepVeinOpen;
        enum paused;
    }

    enum def AlarmSeverity {
        enum advisory;
        enum caution;
        enum critical;
    }

    enum def PumpStateKind {
        enum poweredOff;
        enum selfTesting;
        enum ready;
        enum priming;
        enum infusing;
        enum paused;
        enum alarmed;
        enum serviceRequired;
    }

    enum def BatteryChemistry {
        enum lithiumIon;
    }

    attribute def FlowRate :> Real {
        unit = L/h;
    }

    attribute def DoseRate :> Real {
        unit = mg/h;
    }

    attribute def FluidVolume :> Real {
        unit = mL;
    }

    attribute def Pressure :> Real {
        unit = kPa;
    }

    attribute def BatteryCharge :> Real {
        unit = percent;
    }

    attribute def Voltage :> Real {
        unit = V;
    }

    attribute def Current :> Real {
        unit = A;
    }

    attribute def TimeDuration :> Real {
        unit = s;
    }

    attribute def MassConcentration :> Real {
        unit = mg/mL;
    }

    attribute def Temperature :> Real {
        unit = degC;
    }

    item def SterileMedication {
        attribute medicationName : String;
        attribute concentration : MassConcentration;
        attribute remainingVolume : FluidVolume;
        attribute lotNumber : String;
        attribute expirationDate : String;
    }

    item def InfusionCommand {
        attribute prescribedMode : TherapyMode;
        attribute targetFlowRate : FlowRate;
        attribute targetDoseRate : DoseRate;
        attribute bolusVolume : FluidVolume;
        attribute bolusDuration : TimeDuration;
        attribute patientWeightKg : Real;
    }

    item def PumpTelemetry {
        attribute operatingState : PumpStateKind;
        attribute actualFlowRate : FlowRate;
        attribute deliveredVolume : FluidVolume;
        attribute linePressure : Pressure;
        attribute batteryCharge : BatteryCharge;
        attribute enclosureTemperature : Temperature;
        attribute activeAlarmCount : Integer;
    }

    item def AlarmMessage {
        attribute alarmCode : String;
        attribute severity : AlarmSeverity;
        attribute alarmText : String;
        attribute timeActive : TimeDuration;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def MotorDriveSignal {
        attribute stepFrequency : Real;
        attribute driveCurrent : Current;
        attribute enabled : Boolean;
    }

    item def SensorSample {
        attribute sampleTime : TimeDuration;
        attribute measuredPressure : Pressure;
        attribute measuredFlowRate : FlowRate;
        attribute measuredAirInLine : Boolean;
        attribute doorClosed : Boolean;
        attribute cassetteLatched : Boolean;
    }

    port def MedicationInletPort {
        in item medication : SterileMedication;
    }

    port def MedicationOutletPort {
        out item medication : SterileMedication;
    }

    port def CommandPort {
        in item command : InfusionCommand;
    }

    port def TelemetryPort {
        out item telemetry : PumpTelemetry;
    }

    port def AlarmPort {
        out item alarm : AlarmMessage;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerDistributionPort {
        out item power : ElectricalPower;
    }

    port def MotorControlPort {
        out item drive : MotorDriveSignal;
    }

    port def SensorPort {
        out item sample : SensorSample;
    }

    part def SmartInfusionPump {
        attribute primaryFunction : String = "Deliver prescribed sterile medication from a reservoir to a patient at controlled flow or dose rates while monitoring delivery safety conditions and alerting caregivers to hazardous conditions.";
        attribute deviceIdentifier : String;
        attribute currentState : PumpStateKind;
        attribute selectedMode : TherapyMode;
        attribute commandedFlowRate : FlowRate;
        attribute commandedDoseRate : DoseRate;
        attribute deliveredVolumeTotal : FluidVolume;
        attribute maximumAllowablePressure : Pressure = 120.0 [kPa];
        attribute minimumBatteryForTherapy : BatteryCharge = 20.0 [percent];

        port medicationIn : MedicationInletPort;
        port patientLine : MedicationOutletPort;
        port clinicianCommand : CommandPort;
        port telemetryOut : TelemetryPort;
        port alarmOut : AlarmPort;
        port mainsPower : PowerInputPort;

        part reservoir : MedicationReservoir;
        part pumpingMechanism : PeristalticPumpMechanism;
        part controller : TherapyController;
        part sensorSuite : DeliverySensorSuite;
        part powerSubsystem : PowerSubsystem;
        part userInterface : ClinicianUserInterface;
        part alarmSubsystem : AlarmSubsystem;
        part safetyInterlock : SafetyInterlock;

        connect medicationIn to reservoir.fillPort;
        connect reservoir.outlet to pumpingMechanism.inlet;
        connect pumpingMechanism.outlet to patientLine;
        connect clinicianCommand to userInterface.commandIn;
        connect userInterface.validatedCommandOut to controller.prescriptionIn;
        connect controller.motorDriveOut to pumpingMechanism.driveIn;
        connect sensorSuite.sensorOut to controller.sensorIn;
        connect sensorSuite.sensorOut to safetyInterlock.sensorIn;
        connect safetyInterlock.stopCommandOut to controller.safetyStopIn;
        connect controller.telemetryOut to telemetryOut;
        connect controller.alarmOut to alarmSubsystem.alarmIn;
        connect safetyInterlock.alarmOut to alarmSubsystem.alarmIn;
        connect alarmSubsystem.audibleVisualAlarmOut to alarmOut;
        connect mainsPower to powerSubsystem.externalPowerIn;
        connect powerSubsystem.controllerPowerOut to controller.powerIn;
        connect powerSubsystem.motorPowerOut to pumpingMechanism.powerIn;
        connect powerSubsystem.uiPowerOut to userInterface.powerIn;
        connect powerSubsystem.sensorPowerOut to sensorSuite.powerIn;

        perform action startTherapy {
            in item command : InfusionCommand;
            first accept command;
            then validatePrescription;
            then primeLine;
            then beginClosedLoopInfusion;
        }

        perform action stopTherapy {
            first commandMotorStop;
            then updateDeliveredVolume;
            then publishFinalTelemetry;
        }

        state def PumpOperationalStates {
            entry action initializeTelemetry;

            state poweredOff;
            state selfTesting;
            state ready;
            state priming;
            state infusing;
            state paused;
            state alarmed;
            state serviceRequired;

            transition powerApplied
                first poweredOff
                then selfTesting;

            transition selfTestPassed
                first selfTesting
                then ready;

            transition selfTestFailed
                first selfTesting
                then serviceRequired;

            transition prescriptionAccepted
                first ready
                then priming;

            transition primeComplete
                first priming
                then infusing;

            transition pauseRequested
                first infusing
                then paused;

            transition resumeRequested
                first paused
                then infusing;

            transition therapyComplete
                first infusing
                then ready;

            transition criticalAlarmDetected
                first infusing
                then alarmed;

            transition alarmAcknowledgedAndResolved
                first alarmed
                then ready;

            transition powerRemoved
                first ready
                then poweredOff;
        }
    }

    part def MedicationReservoir {
        attribute nominalCapacity : FluidVolume = 250.0 [mL];
        attribute currentVolume : FluidVolume;
        attribute loadedMedicationName : String;
        attribute medicationConcentration : MassConcentration;

        port fillPort : MedicationInletPort;
        port outlet : MedicationOutletPort;
    }

    part def PeristalticPumpMechanism {
        attribute rollerCount : Integer = 3;
        attribute calibratedStrokeVolume : FluidVolume = 0.05 [mL];
        attribute commandedStepFrequency : Real;
        attribute motorEnabled : Boolean;

        port inlet : MedicationInletPort;
        port outlet : MedicationOutletPort;
        port driveIn : MotorControlPort;
        port powerIn : PowerInputPort;

        perform action convertDriveToFlow {
            in item drive : MotorDriveSignal;
            out attribute estimatedFlowRate : FlowRate;
        }
    }

    part def TherapyController {
        attribute activeMode : TherapyMode;
        attribute setFlowRate : FlowRate;
        attribute setDoseRate : DoseRate;
        attribute cumulativeDeliveredVolume : FluidVolume;
        attribute lastMeasuredPressure : Pressure;
        attribute closedLoopUpdatePeriod : TimeDuration = 0.25 [s];

        port prescriptionIn : CommandPort;
        port sensorIn : SensorPort;
        port safetyStopIn : CommandPort;
        port motorDriveOut : MotorControlPort;
        port telemetryOut : TelemetryPort;
        port alarmOut : AlarmPort;
        port powerIn : PowerInputPort;

        perform action validatePrescription {
            in item command : InfusionCommand;
            out attribute accepted : Boolean;
        }

        perform action calculateMotorDrive {
            in item command : InfusionCommand;
            in item sample : SensorSample;
            out item drive : MotorDriveSignal;
        }

        perform action monitorTherapy {
            in item sample : SensorSample;
            out item telemetry : PumpTelemetry;
            out item alarm : AlarmMessage;
        }

        perform action commandMotorStop {
            out item drive : MotorDriveSignal {
                attribute enabled = false;
            }
        }
    }

    part def DeliverySensorSuite {
        attribute pressureAccuracy : Pressure = 5.0 [kPa];
        attribute flowAccuracy : FlowRate = 0.05 [L/h];
        attribute airBubbleDetectionThreshold : FluidVolume = 0.02 [mL];

        port powerIn : PowerInputPort;
        port sensorOut : SensorPort;

        part pressureSensor : LinePressureSensor;
        part flowSensor : InlineFlowSensor;
        part airDetector : AirInLineDetector;
        part doorSwitch : DoorClosedSwitch;
        part cassetteLatchSwitch : CassetteLatchSwitch;
    }

    part def LinePressureSensor {
        attribute measurementRangeLow : Pressure = 0.0 [kPa];
        attribute measurementRangeHigh : Pressure = 200.0 [kPa];
        attribute measuredPressure : Pressure;
    }

    part def InlineFlowSensor {
        attribute measurementRangeLow : FlowRate = 0.0 [L/h];
        attribute measurementRangeHigh : FlowRate = 2.0 [L/h];
        attribute measuredFlowRate : FlowRate;
    }

    part def AirInLineDetector {
        attribute airDetected : Boolean;
        attribute detectionThreshold : FluidVolume = 0.02 [mL];
    }

    part def DoorClosedSwitch {
        attribute doorClosed : Boolean;
    }

    part def CassetteLatchSwitch {
        attribute cassetteLatched : Boolean;
    }

    part def PowerSubsystem {
        attribute batteryChemistry : BatteryChemistry = BatteryChemistry::lithiumIon;
        attribute batteryCapacityWh : Real = 60.0;
        attribute currentBatteryCharge : BatteryCharge;
        attribute externalPowerPresent : Boolean;

        port externalPowerIn : PowerInputPort;
        port controllerPowerOut : PowerDistributionPort;
        port motorPowerOut : PowerDistributionPort;
        port uiPowerOut : PowerDistributionPort;
        port sensorPowerOut : PowerDistributionPort;

        part acDcConverter : MedicalGradePowerSupply;
        part rechargeableBattery : RechargeableBattery;
        part powerManager : PowerManager;
    }

    part def MedicalGradePowerSupply {
        attribute inputVoltage : Voltage = 120.0 [V];
        attribute outputVoltage : Voltage = 24.0 [V];
        attribute isolationRatingVrms : Real = 4000.0;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : Voltage = 14.4 [V];
        attribute chargeRemaining : BatteryCharge;
        attribute supportsHotSwap : Boolean = false;
    }

    part def PowerManager {
        attribute selectedSource : String;
        attribute lowBatteryThreshold : BatteryCharge = 20.0 [percent];
        attribute criticalBatteryThreshold : BatteryCharge = 10.0 [percent];
    }

    part def ClinicianUserInterface {
        attribute displayBrightnessPercent : Real;
        attribute keypadLocked : Boolean;
        attribute lastEnteredAccessCodeAccepted : Boolean;

        port commandIn : CommandPort;
        port validatedCommandOut : CommandPort;
        port powerIn : PowerInputPort;

        perform action authenticateClinician {
            in attribute accessCode : String;
            out attribute authenticated : Boolean;
        }

        perform action displayTherapyStatus {
            in item telemetry : PumpTelemetry;
            in item alarm : AlarmMessage;
        }
    }

    part def AlarmSubsystem {
        attribute activeAlarmCount : Integer;
        attribute maximumSoundPressureLevelDbA : Real = 75.0;
        attribute visualIndicatorActive : Boolean;

        port alarmIn : AlarmPort;
        port audibleVisualAlarmOut : AlarmPort;

        perform action prioritizeAlarm {
            in item alarm : AlarmMessage;
            out item prioritizedAlarm : AlarmMessage;
        }

        perform action annunciateAlarm {
            in item prioritizedAlarm : AlarmMessage;
        }
    }

    part def SafetyInterlock {
        attribute occlusionPressureLimit : Pressure = 120.0 [kPa];
        attribute minimumBatteryCharge : BatteryCharge = 10.0 [percent];
        attribute airInLineTripEnabled : Boolean = true;

        port sensorIn : SensorPort;
        port stopCommandOut : CommandPort;
        port alarmOut : AlarmPort;

        perform action evaluateHazards {
            in item sample : SensorSample;
            out attribute stopRequired : Boolean;
            out item alarm : AlarmMessage;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The infusion pump shall deliver prescribed sterile medication to a patient at the clinician-selected flow or dose rate while continuously monitoring delivery status and hazardous conditions. */
        subject pump : SmartInfusionPump;
        require constraint {
            pump.commandedFlowRate >= 0.0 [L/h] and
            pump.deliveredVolumeTotal >= 0.0 [mL]
        }
    }

    requirement def FlowAccuracyRequirement {
        doc /* During continuous infusion, the pump shall maintain actual flow within plus or minus five percent of the prescribed flow rate after stabilization. */
        subject telemetry : PumpTelemetry;
        subject command : InfusionCommand;
        require constraint {
            telemetry.actualFlowRate >= command.targetFlowRate * 0.95 and
            telemetry.actualFlowRate <= command.targetFlowRate * 1.05
        }
    }

    requirement def OcclusionDetectionRequirement {
        doc /* The pump shall stop infusion and generate a critical alarm when measured line pressure exceeds the occlusion limit. */
        subject sample : SensorSample;
        subject interlock : SafetyInterlock;
        require constraint {
            sample.measuredPressure <= interlock.occlusionPressureLimit
        }
    }

    requirement def AirInLineRequirement {
        doc /* The pump shall prevent continued infusion when air is detected in the patient line. */
        subject sample : SensorSample;
        require constraint {
            sample.measuredAirInLine == false
        }
    }

    requirement def LowBatteryRequirement {
        doc /* The pump shall provide an alarm before battery charge falls below the minimum charge required to continue therapy safely. */
        subject telemetry : PumpTelemetry;
        require constraint {
            telemetry.batteryCharge >= 20.0 [percent]
        }
    }

    requirement def DoorAndCassetteRequirement {
        doc /* The pump shall permit medication delivery only when the access door is closed and the cassette is latched. */
        subject sample : SensorSample;
        require constraint {
            sample.doorClosed == true and
            sample.cassetteLatched == true
        }
    }

    requirement def ElectricalSafetyRequirement {
        doc /* The power subsystem shall provide isolated medical-grade low-voltage power to controller, sensor, user-interface, and motor subsystems. */
        subject supply : MedicalGradePowerSupply;
        require constraint {
            supply.outputVoltage == 24.0 [V] and
            supply.isolationRatingVrms >= 4000.0
        }
    }

    requirement def AlarmPriorityRequirement {
        doc /* Critical therapy hazards shall produce alarms with critical severity and shall command the pump motor to stop. */
        subject alarm : AlarmMessage;
        require constraint {
            alarm.severity == AlarmSeverity::critical
        }
    }

    part infusionPumpSystem : SmartInfusionPump {
        attribute deviceIdentifier = "MD-INF-CTRL-001";
        attribute currentState = PumpStateKind::poweredOff;
        attribute selectedMode = TherapyMode::continuous;
        attribute commandedFlowRate = 0.1 [L/h];
        attribute commandedDoseRate = 5.0 [mg/h];
        attribute deliveredVolumeTotal = 0.0 [mL];

        part reservoir {
            attribute currentVolume = 100.0 [mL];
            attribute loadedMedicationName = "Sterile Saline With Medication";
            attribute medicationConcentration = 50.0 [mg/mL];
        }

        part powerSubsystem {
            attribute currentBatteryCharge = 100.0 [percent];
            attribute externalPowerPresent = true;
        }
    }

    satisfy PrimaryFunctionRequirement by infusionPumpSystem;
    satisfy FlowAccuracyRequirement by infusionPumpSystem.controller;
    satisfy OcclusionDetectionRequirement by infusionPumpSystem.safetyInterlock;
    satisfy AirInLineRequirement by infusionPumpSystem.sensorSuite.airDetector;
    satisfy LowBatteryRequirement by infusionPumpSystem.powerSubsystem.powerManager;
    satisfy DoorAndCassetteRequirement by infusionPumpSystem.safetyInterlock;
    satisfy ElectricalSafetyRequirement by infusionPumpSystem.powerSubsystem.acDcConverter;
    satisfy AlarmPriorityRequirement by infusionPumpSystem.alarmSubsystem;
}