package tDCS_System {

    import ScalarValues::*;

    /* ===== Value Types with Units ===== */
    value type ElectricCurrent :> Real {
        :>> unit = 'A';
        constraint { 0 <= self; }
    }

    value type CurrentIntensityValue :> ElectricCurrent {
        constraint { 0 <= self and self <= 0.004; }
    }

    value type VoltageValue :> Real {
        :>> unit = 'V';
    }

    value type ResistanceValue :> Real {
        :>> unit = 'ohm';
    }

    value type ImpedanceValue :> ResistanceValue {
        constraint { 0 <= self; }
    }

    value type DurationValue :> Real {
        :>> unit = 's';
        constraint { 0 <= self; }
    }

    value type ChargeValue :> Real {
        :>> unit = 'C';
    }

    value type PowerValue :> Real {
        :>> unit = 'W';
    }

    value type AreaValue :> Real {
        :>> unit = 'm2';
    }

    /* ===== Enumerations ===== */
    enum SessionStateKind {
        off;
        idle;
        rampingUp;
        active;
        rampingDown;
        emergency;
        complete;
        fault;
    }

    enum AlertLevelKind {
        normal;
        warning;
        critical;
    }

    enum SystemStateKind {
        initializing;
        ready;
        active;
        shuttingDown;
        error;
    }

    enum CommandTypeKind {
        start;
        stop;
        configure;
        reset;
    }

    /* ===== Item Definitions ===== */
    item def ElectricStimulus {
        attribute current : ElectricCurrent;
        attribute voltage : VoltageValue;
    }

    item def SafetyAlertMessage {
        attribute level : AlertLevelKind;
        attribute description : String;
        attribute timestamp : DurationValue;
    }

    /* ===== Attribute Definitions ===== */
    attribute def StimulationParameters {
        attribute targetCurrent : CurrentIntensityValue = 0.002 [A];
        attribute sessionDuration : DurationValue = 1200 [s];
        attribute rampUpTime : DurationValue = 30 [s];
        attribute rampDownTime : DurationValue = 30 [s];
        attribute maxImpedance : ImpedanceValue = 5000 [ohm];
        attribute maxCurrent : CurrentIntensityValue = 0.004 [A];
        attribute maxSessionDuration : DurationValue = 1800 [s];
    }

    /* ===== Requirements ===== */
    requirement def tDCS_Requirement;

    requirement TherapeuticCurrentDeliveryReq : tDCS_Requirement {
        doc /* The system shall deliver a controlled, low-intensity electrical current to the patient's scalp through a pair of electrodes. */
        subject patient : Patient;
        attribute targetCurrent : CurrentIntensityValue;
        constraint { targetCurrent >= 0.0005 [A]; }
        constraint { targetCurrent <= 0.004 [A]; }
    }

    requirement ControlledRampProfileReq : tDCS_Requirement {
        doc /* The current generator shall ramp up to target level, maintain for set duration, and ramp down safely. */
        attribute rampUpTime : DurationValue;
        attribute rampDownTime : DurationValue;
        constraint { rampUpTime >= 15 [s]; }
        constraint { rampDownTime >= 15 [s]; }
    }

    requirement ImpedanceMonitoringReq : tDCS_Requirement {
        doc /* The system shall continuously monitor the electrical impedance between electrodes and scalp. */
        attribute measuredImpedance : ImpedanceValue;
        attribute threshold : ImpedanceValue = 5000 [ohm];
        constraint { measuredImpedance <= threshold; }
    }

    requirement EmergencyShutdownReq : tDCS_Requirement {
        doc /* The safety controller shall initiate emergency shutdown if any parameter exceeds predefined safety limits. */
        attribute emergencyTriggered : Boolean;
        constraint { emergencyTriggered implies currentShutdown <= 0 [A]; }
    }

    requirement MaxCurrentLimitReq : tDCS_Requirement {
        doc /* The current delivered to the patient shall not exceed 4 mA under any operating condition. */
        attribute deliveredCurrent : ElectricCurrent;
        constraint { deliveredCurrent <= 0.004 [A]; }
    }

    requirement MaxSessionDurationReq : tDCS_Requirement {
        doc /* A single stimulation session shall not exceed 30 minutes (1800 s). */
        attribute sessionDuration : DurationValue;
        constraint { sessionDuration <= 1800 [s]; }
    }

    requirement UserInterfaceConfigurationReq : tDCS_Requirement {
        doc /* The user interface shall allow configuration of current intensity, total duration, and ramp times. */
    }

    requirement PowerSupplyReliabilityReq : tDCS_Requirement {
        doc /* The power supply shall provide stable voltage to the current generator throughout the session. */
        attribute supplyVoltage : VoltageValue = 12 [V];
        constraint { supplyVoltage >= 10 [V]; }
    }

    /* ===== Port Definitions ===== */
    port def ElectricalOutputPort {
        out current : ElectricCurrent;
        out voltage : VoltageValue;
    }

    port def ElectricalInputPort {
        in current : ElectricCurrent;
        in voltage : VoltageValue;
    }

    port def PowerOutputPort {
        out voltage : VoltageValue;
        out current : ElectricCurrent;
        out available : Boolean;
    }

    port def CommandOutputPort {
        out command : CommandTypeKind;
        out parameters : StimulationParameters;
        out requestStop : Boolean;
    }

    port def StatusOutputPort {
        out systemState : SystemStateKind;
        out sessionState : SessionStateKind;
        out alertLevel : AlertLevelKind;
        out elapsed : DurationValue;
    }

    port def ImpedanceOutputPort {
        out impedance : ImpedanceValue;
        out connectionValid : Boolean;
    }

    port def AlertOutputPort {
        out alert : SafetyAlertMessage;
        out shutdownRequested : Boolean;
    }

    port def ControlInputPort {
        in enable : Boolean;
        in emergencyStop : Boolean;
        in targetCurrent : CurrentIntensityValue;
        in sessionDuration : DurationValue;
        in rampUpTime : DurationValue;
        in rampDownTime : DurationValue;
    }

    port def MeasurementOutputPort {
        out measuredCurrent : ElectricCurrent;
        out measuredVoltage : VoltageValue;
        out elapsed : DurationValue;
    }

    port def ImpedanceMeasurementInputPort {
        in measuredCurrent : ElectricCurrent;
        in measuredVoltage : VoltageValue;
    }

    /* ===== Part Definitions ===== */
    part def Electrode {
        attribute electrodeType : String;
        attribute area : AreaValue = 0.0025 [m2];
        attribute material : String = "Ag/AgCl";
        attribute contactQuality : Real = 1.0;
        port electricalInterface : ElectricalOutputPort;
    }

    part def AnodeElectrode :> Electrode {
        :>> electrodeType = "anode";
    }

    part def CathodeElectrode :> Electrode {
        :>> electrodeType = "cathode";
    }

    /* ----- Power Supply ----- */
    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 12 [V];
        attribute maxOutputCurrent : ElectricCurrent = 2 [A];
        attribute batteryCapacity : ChargeValue = 5000 [C];
        attribute batteryLevel : Real = 100;
        attribute enabled : Boolean = false;
        attribute isLowBattery : Boolean = false;
        attribute outputVoltage : VoltageValue = 12 [V];
        attribute outputCurrent : ElectricCurrent = 0 [A];

        port powerOutput : PowerOutputPort;
        port statusOutput : StatusOutputPort;

        state def PowerSupplyState {
            state Off {
                entry { outputVoltage = 0 [V]; }
            }
            state On {
                state Discharging {
                    do { batteryLevel -= 0.01; }
                }
                state LowBattery {
                    entry { isLowBattery = true; }
                }
                transition Discharging to LowBattery when batteryLevel < 20;
            }
            transition Off to On when enabled;
            transition On to Off when !enabled;
        }
    }

    /* ----- Current Generator ----- */
    part def CurrentGenerator {
        attribute targetCurrent : CurrentIntensityValue = 0.002 [A];
        attribute actualCurrent : ElectricCurrent = 0 [A];
        attribute outputVoltage : VoltageValue = 0 [V];
        attribute rampUpTime : DurationValue = 30 [s];
        attribute rampDownTime : DurationValue = 30 [s];
        attribute activeDuration : DurationValue = 1200 [s];
        attribute elapsedTime : DurationValue = 0 [s];
        attribute enabled : Boolean = false;
        attribute emergencyActive : Boolean = false;
        attribute sessionComplete : Boolean = false;
        attribute dt : DurationValue = 0.1 [s];

        port powerInput : ElectricalInputPort;
        port stimulusOutput : ElectricalOutputPort;
        port controlInput : ControlInputPort;
        port measurementOutput : MeasurementOutputPort;

        action def ComputeRampUp {
            out current : ElectricCurrent;
            then {
                current = (elapsedTime / rampUpTime) * targetCurrent;
            }
        }

        action def ComputeRampDown {
            out current : ElectricCurrent;
            then {
                current = ((rampUpTime + activeDuration + rampDownTime - elapsedTime) / rampDownTime) * targetCurrent;
            }
        }

        state def CurrentGeneratorState {
            state Idle {
                entry { actualCurrent = 0 [A]; elapsedTime = 0 [s]; }
            }
            state RampingUp {
                do {
                    perform ComputeRampUp -> current;
                    actualCurrent = current;
                    elapsedTime += dt;
                }
            }
            state Active {
                entry { actualCurrent = targetCurrent; }
                do { elapsedTime += dt; }
            }
            state RampingDown {
                do {
                    perform ComputeRampDown -> current;
                    actualCurrent = current;
                    elapsedTime += dt;
                }
            }
            state Emergency {
                entry { actualCurrent = 0 [A]; }
            }
            state Complete {
                entry { actualCurrent = 0 [A]; sessionComplete = true; }
            }
            transition Idle to RampingUp when controlInput.enable and !emergencyActive;
            transition RampingUp to Active when elapsedTime >= rampUpTime;
            transition Active to RampingDown when elapsedTime >= (rampUpTime + activeDuration);
            transition RampingDown to Complete when elapsedTime >= (rampUpTime + activeDuration + rampDownTime);
            transition RampingUp to Emergency when emergencyActive;
            transition Active to Emergency when emergencyActive;
            transition RampingDown to Emergency when emergencyActive;
            transition Complete to Idle when !controlInput.enable;
        }
    }

    /* ----- User Interface ----- */
    part def UserInterface {
        attribute configuredCurrent : CurrentIntensityValue = 0.002 [A];
        attribute configuredDuration : DurationValue = 1200 [s];
        attribute configuredRampUp : DurationValue = 30 [s];
        attribute configuredRampDown : DurationValue = 30 [s];
        attribute displayedState : SystemStateKind = ready;
        attribute displayedAlert : AlertLevelKind = normal;
        attribute displayedElapsed : DurationValue = 0 [s];

        port commandOutput : CommandOutputPort;
        port statusInput : StatusOutputPort;

        action def ConfigureSession {
            in targetCurrent : CurrentIntensityValue;
            in duration : DurationValue;
            in rampUp : DurationValue;
            in rampDown : DurationValue;
            then {
                configuredCurrent = targetCurrent;
                configuredDuration = duration;
                configuredRampUp = rampUp;
                configuredRampDown = rampDown;
            }
        }

        action def StartSession {
            then {
                commandOutput.command = start;
                commandOutput.parameters = StimulationParameters {
                    targetCurrent = configuredCurrent;
                    sessionDuration = configuredDuration;
                    rampUpTime = configuredRampUp;
                    rampDownTime = configuredRampDown;
                };
                commandOutput.requestStop = false;
            }
        }

        action def StopSession {
            then {
                commandOutput.command = stop;
                commandOutput.requestStop = true;
            }
        }

        action def UpdateDisplay {
            in status : StatusOutputPort;
            then {
                displayedState = status.systemState;
                displayedAlert = status.alertLevel;
                displayedElapsed = status.elapsed;
            }
        }
    }

    /* ----- Impedance Monitor ----- */
    part def ImpedanceMonitor {
        attribute currentImpedance : ImpedanceValue = 0 [ohm];
        attribute thresholdImpedance : ImpedanceValue = 5000 [ohm];
        attribute isMonitoring : Boolean = false;
        attribute measurementInterval : DurationValue = 1 [s];
        attribute lastMeasurementTime : DurationValue = 0 [s];
        attribute connectionValid : Boolean = true;
        attribute alarmTriggered : Boolean = false;

        port impedanceOutput : ImpedanceOutputPort;
        port measurementInput : ImpedanceMeasurementInputPort;

        action def MeasureImpedance {
            in measurementCurrent : ElectricCurrent;
            in measurementVoltage : VoltageValue;
            out impedance : ImpedanceValue;
            then {
                if (measurementCurrent > 0 [A]) {
                    currentImpedance = measurementVoltage / measurementCurrent;
                }
                impedance = currentImpedance;
                connectionValid = currentImpedance <= thresholdImpedance;
                if (!connectionValid) {
                    alarmTriggered = true;
                }
            }
        }

        state def ImpedanceMonitorState {
            state Idle;
            state Monitoring {
                do {
                    perform MeasureImpedance(measurementInput.measuredCurrent, measurementInput.measuredVoltage) -> measuredImpedance;
                    currentImpedance = measuredImpedance;
                    lastMeasurementTime += measurementInterval;
                }
            }
            state Alarm {
                entry {
                    connectionValid = false;
                    alarmTriggered = true;
                }
            }
            transition Idle to Monitoring when isMonitoring;
            transition Monitoring to Alarm when currentImpedance > thresholdImpedance;
            transition Alarm to Monitoring when currentImpedance <= thresholdImpedance and isMonitoring;
            transition Monitoring to Idle when !isMonitoring;
        }
    }

    /* ----- Safety Controller ----- */
    part def SafetyController {
        attribute maxAllowedCurrent : CurrentIntensityValue = 0.004 [A];
        attribute maxAllowedImpedance : ImpedanceValue = 5000 [ohm];
        attribute maxAllowedDuration : DurationValue = 1800 [s];
        attribute alertLevel : AlertLevelKind = normal;
        attribute isEmergency : Boolean = false;
        attribute resetRequested : Boolean = false;
        attribute isMonitoring : Boolean = false;
        attribute lastMeasuredCurrent : ElectricCurrent = 0 [A];
        attribute lastMeasuredImpedance : ImpedanceValue = 0 [ohm];
        attribute lastElapsed : DurationValue = 0 [s];
        attribute lastAlertDescription : String = "";
        attribute lastAlertTime : DurationValue = 0 [s];

        port measurementInput : MeasurementOutputPort;
        port impedanceInput : ImpedanceOutputPort;
        port alertOutput : AlertOutputPort;
        port emergencyControl : ControlInputPort;

        action def EvaluateSafetyConditions {
            in measuredCurrent : ElectricCurrent;
            in measuredImpedance : ImpedanceValue;
            in elapsed : DurationValue;
            out emergency : Boolean;
            out level : AlertLevelKind;
            out description : String;
            then {
                emergency = false;
                level = normal;
                description = "";
                if (measuredCurrent > maxAllowedCurrent) {
                    emergency = true;
                    level = critical;
                    description = "Current limit exceeded";
                }
                if (measuredImpedance > maxAllowedImpedance) {
                    level = warning;
                    description = "Impedance limit exceeded";
                    if (measuredImpedance > 2 * maxAllowedImpedance) {
                        emergency = true;
                        level = critical;
                    }
                }
                if (elapsed > maxAllowedDuration) {
                    emergency = true;
                    level = critical;
                    description = "Session duration exceeded";
                }
            }
        }

        state def SafetyControllerState {
            state Idle;
            state Monitoring {
                do {
                    lastMeasuredCurrent = measurementInput.measuredCurrent;
                    lastMeasuredImpedance = impedanceInput.impedance;
                    lastElapsed = measurementInput.elapsed;
                    perform EvaluateSafetyConditions(lastMeasuredCurrent, lastMeasuredImpedance, lastElapsed) -> (emergencyResult, levelResult, descriptionResult);
                    alertLevel = levelResult;
                    lastAlertDescription = descriptionResult;
                    lastAlertTime = lastElapsed;
                    isEmergency = emergencyResult;
                    if (emergencyResult) {
                        emergencyControl.emergencyStop = true;
                        alertOutput.shutdownRequested = true;
                        alertOutput.alert = SafetyAlertMessage {
                            level = levelResult;
                            description = descriptionResult;
                            timestamp = lastElapsed;
                        };
                    }
                }
            }
            state EmergencyShutdown {
                entry {
                    alertLevel = critical;
                    emergencyControl.emergencyStop = true;
                    alertOutput.shutdownRequested = true;
                }
            }
            transition Idle to Monitoring when isMonitoring;
            transition Monitoring to EmergencyShutdown when isEmergency;
            transition EmergencyShutdown to Idle when resetRequested;
        }
    }

    /* ===== Patient Context ===== */
    part def Patient {
        attribute scalpResistance : ImpedanceValue = 500 [ohm];
        attribute targetBrainRegion : String = "dorsolateral prefrontal cortex";
        attribute patientName : String;
        attribute sessionAuthorized : Boolean = true;
        port scalpContact : ElectricalInputPort;
    }

    /* ===== Top-Level tDCS System ===== */
    part def tDCS_System {
        part powerSupply : PowerSupply;
        part currentGenerator : CurrentGenerator;
        part userInterface : UserInterface;
        part impedanceMonitor : ImpedanceMonitor;
        part safetyController : SafetyController;
        part anodeElectrode : AnodeElectrode;
        part cathodeElectrode : CathodeElectrode;
        part patient : Patient;

        attribute systemState : SystemStateKind = initializing;
        attribute activeParameters : StimulationParameters;

        /* Connections */
        connection powerConnection from powerSupply.powerOutput to currentGenerator.powerInput;
        connection stimulusConnection from currentGenerator.stimulusOutput to anodeElectrode.electricalInterface;
        connection patientDeliveryConnection from anodeElectrode.electricalInterface to patient.scalpContact;
        connection returnConnection from patient.scalpContact to cathodeElectrode.electricalInterface;
        connection returnToGenerator from cathodeElectrode.electricalInterface to currentGenerator.powerInput;
        connection commandConnection from userInterface.commandOutput to safetyController.emergencyControl;
        connection controlConnection from safetyController.emergencyControl to currentGenerator.controlInput;
        connection measurementConnection from currentGenerator.measurementOutput to safetyController.measurementInput;
        connection impedanceMeasurementConnection from currentGenerator.measurementOutput to impedanceMonitor.measurementInput;
        connection impedanceConnection from impedanceMonitor.impedanceOutput to safetyController.impedanceInput;
        connection alertConnection from safetyController.alertOutput to userInterface.statusInput;
        connection statusConnection from currentGenerator.measurementOutput to userInterface.statusInput;

        /* Bindings */
        bind currentGenerator.enabled = safetyController.emergencyControl.enable;
        bind currentGenerator.emergencyActive = safetyController.emergencyControl.emergencyStop;
        bind currentGenerator.targetCurrent = userInterface.configuredCurrent;
        bind currentGenerator.rampUpTime = userInterface.configuredRampUp;
        bind currentGenerator.rampDownTime = userInterface.configuredRampDown;
        bind currentGenerator.activeDuration = userInterface.configuredDuration;
        bind powerSupply.enabled = userInterface.commandOutput.command == start;
        bind impedanceMonitor.isMonitoring = currentGenerator.enabled;
        bind safetyController.isMonitoring = currentGenerator.enabled;

        /* System-level State Machine */
        state def tDCS_SystemState {
            state Initializing {
                do {
                    powerSupply.enabled = true;
                    systemState = initializing;
                }
            }
            state Ready {
                entry { systemState = ready; }
            }
            state Active {
                entry { systemState = active; }
                do {
                    activeParameters = StimulationParameters {
                        targetCurrent = userInterface.configuredCurrent;
                        sessionDuration = userInterface.configuredDuration;
                        rampUpTime = userInterface.configuredRampUp;
                        rampDownTime = userInterface.configuredRampDown;
                    };
                }
            }
            state ShuttingDown {
                entry { powerSupply.enabled = false; }
            }
            state EmergencyShutdown {
                entry {
                    powerSupply.enabled = false;
                    systemState = error;
                }
            }
            state Complete {
                entry { systemState = ready; }
            }
            state Error {
                entry { systemState = error; }
            }
            transition Initializing to Ready when powerSupply.batteryLevel > 20;
            transition Ready to Active when userInterface.commandOutput.command == start;
            transition Active to Complete when currentGenerator.sessionComplete;
            transition Active to EmergencyShutdown when safetyController.isEmergency;
            transition Complete to Ready when userInterface.commandOutput.command == reset;
            transition Ready to ShuttingDown when userInterface.commandOutput.command == stop;
            transition ShuttingDown to Ready when !powerSupply.enabled;
            transition EmergencyShutdown to Ready when safetyController.resetRequested;
            transition Error to Initializing when safetyController.resetRequested;
        }

        /* Requirement Satisfactions */
        satisfy TherapeuticCurrentDeliveryReq by currentGenerator;
        satisfy ControlledRampProfileReq by currentGenerator;
        satisfy ImpedanceMonitoringReq by impedanceMonitor;
        satisfy EmergencyShutdownReq by safetyController;
        satisfy MaxCurrentLimitReq by currentGenerator;
        satisfy MaxSessionDurationReq by safetyController;
        satisfy UserInterfaceConfigurationReq by userInterface;
        satisfy PowerSupplyReliabilityReq by powerSupply;
    }

    /* ===== Verification Actions ===== */
    action def VerifyCurrentLimit {
        in generator : CurrentGenerator;
        out verified : Boolean;
        then {
            verified = generator.actualCurrent <= 0.004 [A];
        }
    }

    action def VerifyRampProfile {
        in generator : CurrentGenerator;
        out verified : Boolean;
        then {
            verified = (generator.rampUpTime >= 15 [s]) and (generator.rampDownTime >= 15 [s]);
        }
    }

    action def VerifyImpedanceMonitoring {
        in monitor : ImpedanceMonitor;
        out verified : Boolean;
        then {
            verified = monitor.currentImpedance <= 5000 [ohm];
        }
    }

    action def VerifyEmergencyShutdown {
        in controller : SafetyController;
        in measuredCurrent : ElectricCurrent;
        in measuredImpedance : ImpedanceValue;
        in elapsed : DurationValue;
        out verified : Boolean;
        then {
            verified = (measuredCurrent <= controller.maxAllowedCurrent)
                and (measuredImpedance <= controller.maxAllowedImpedance)
                and (elapsed <= controller.maxAllowedDuration);
        }
    }

    action def VerifySessionDuration {
        in generator : CurrentGenerator;
        out verified : Boolean;
        then {
            verified = generator.activeDuration <= 1800 [s];
        }
    }

    /* ===== Test Case ===== */
    testcase def tDCS_FunctionalTest {
        attribute testPatient : Patient;
        attribute testSystem : tDCS_System;

        action ConfigureParameters {
            then {
                testSystem.userInterface.configuredCurrent = 0.002 [A];
                testSystem.userInterface.configuredDuration = 1200 [s];
                testSystem.userInterface.configuredRampUp = 30 [s];
                testSystem.userInterface.configuredRampDown = 30 [s];
            }
        }
        action StartSession;
        action MonitorCurrent {
            then {
                assert testSystem.currentGenerator.actualCurrent <= 0.004 [A];
            }
        }
        action VerifyImpedance {
            then {
                assert testSystem.impedanceMonitor.currentImpedance <= 5000 [ohm];
            }
        }
        action StopSession;
        action VerifyCompletion;

        flow from ConfigureParameters to StartSession;
        flow from StartSession to MonitorCurrent;
        flow from MonitorCurrent to VerifyImpedance;
        flow from VerifyImpedance to StopSession;
        flow from StopSession to VerifyCompletion;
    }

}
