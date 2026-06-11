package VeinoplusBasedCalfPumpSystem {
    import ScalarValues::*;
    import ISQ::*;

    value def Volt :> ISQ::ElectricPotentialUnit;
    value def Milliampere :> ISQ::ElectricCurrentUnit;
    value def Hertz :> ISQ::FrequencyUnit;
    value def Microsecond :> ISQ::TimeUnit;
    value def Minute :> ISQ::TimeUnit;
    value def Percent :> ISQ::DimensionlessUnit;

    enum def TherapyMode {
        enum circulationSupport;
        enum recovery;
        enum comfortRamp;
    }

    enum def SessionState {
        enum off;
        enum standby;
        enum selfTest;
        enum electrodeCheck;
        enum rampUp;
        enum stimulation;
        enum paused;
        enum completed;
        enum fault;
    }

    enum def FaultCode {
        enum none;
        enum lowBattery;
        enum openElectrode;
        enum overCurrent;
        enum overTemperature;
        enum sessionTimeout;
        enum userStop;
    }

    item def TherapyCommand {
        attribute requestedMode : TherapyMode;
        attribute requestedIntensityLevel : Integer;
        attribute requestedDuration : Real [min];
    }

    item def ElectricalPulse {
        attribute amplitude : Real [mA];
        attribute pulseWidth : Real [us];
        attribute frequency : Real [Hz];
        attribute polarityBalanced : Boolean;
    }

    item def ElectrodeContactStatus {
        attribute leftContactImpedance : Real [Ohm];
        attribute rightContactImpedance : Real [Ohm];
        attribute contactValid : Boolean;
    }

    item def TherapyStatus {
        attribute activeState : SessionState;
        attribute elapsedTime : Real [min];
        attribute remainingTime : Real [min];
        attribute deliveredIntensityLevel : Integer;
        attribute fault : FaultCode;
    }

    port def UserControlPort {
        in command : TherapyCommand;
        out status : TherapyStatus;
    }

    port def ElectrodePort {
        out pulse : ElectricalPulse;
        in contactStatus : ElectrodeContactStatus;
    }

    port def PowerPort {
        out supplyVoltage : Real [V];
        out availableCharge : Real [%];
    }

    part def VeinoplusBasedSystem {
        doc /* High-level primary function: provide controlled neuromuscular electrical stimulation through skin electrodes on the lower limb to activate the calf muscle pump and support venous blood return during a timed therapy session. */

        attribute nominalSessionDuration : Real [min] = 20.0;
        attribute maximumSessionDuration : Real [min] = 30.0;
        attribute minimumPulseFrequency : Real [Hz] = 1.0;
        attribute maximumPulseFrequency : Real [Hz] = 50.0;
        attribute maximumOutputCurrent : Real [mA] = 70.0;
        attribute maximumPulseWidth : Real [us] = 400.0;

        port userInterface : UserControlPort;
        port leftElectrodeInterface : ElectrodePort;
        port rightElectrodeInterface : ElectrodePort;
        port batteryPower : PowerPort;

        part controller : TherapyController;
        part pulseGenerator : BiphasicPulseGenerator;
        part electrodeSet : SurfaceElectrodeSet;
        part battery : RechargeableBattery;
        part safetyMonitor : SafetyMonitor;
        part enclosure : HandheldEnclosure;

        connect userInterface to controller.userPort;
        connect controller.generatorCommandPort to pulseGenerator.commandPort;
        connect pulseGenerator.leftOutput to leftElectrodeInterface;
        connect pulseGenerator.rightOutput to rightElectrodeInterface;
        connect leftElectrodeInterface to electrodeSet.leftPad;
        connect rightElectrodeInterface to electrodeSet.rightPad;
        connect battery.powerOut to batteryPower;
        connect battery.powerOut to controller.powerIn;
        connect battery.powerOut to pulseGenerator.powerIn;
        connect safetyMonitor.monitoredStatus to controller.safetyStatus;
        connect pulseGenerator.telemetryPort to safetyMonitor.generatorTelemetry;
        connect electrodeSet.contactTelemetry to safetyMonitor.electrodeTelemetry;

        perform action runTherapySession : RunTherapySession;
        exhibit state therapyLifecycle : TherapyLifecycle;
    }

    part def TherapyController {
        attribute selectedMode : TherapyMode = TherapyMode::circulationSupport;
        attribute selectedIntensityLevel : Integer = 1;
        attribute sessionDuration : Real [min] = 20.0;
        attribute currentState : SessionState = SessionState::standby;

        port userPort : UserControlPort;
        port generatorCommandPort {
            out commandPulse : ElectricalPulse;
            out enableOutput : Boolean;
        }
        port powerIn : PowerPort;
        port safetyStatus {
            in fault : FaultCode;
            in outputAllowed : Boolean;
        }

        perform action computePulsePrescription : ComputePulsePrescription;
    }

    part def BiphasicPulseGenerator {
        attribute outputEnabled : Boolean = false;
        attribute amplitudeLimit : Real [mA] = 70.0;
        attribute pulseWidthLimit : Real [us] = 400.0;
        attribute frequencyLimit : Real [Hz] = 50.0;

        port commandPort {
            in commandPulse : ElectricalPulse;
            in enableOutput : Boolean;
        }

        port leftOutput : ElectrodePort;
        port rightOutput : ElectrodePort;

        port powerIn : PowerPort;

        port telemetryPort {
            out measuredCurrent : Real [mA];
            out measuredVoltage : Real [V];
            out generatorTemperature : Real [K];
        }
    }

    part def SurfaceElectrodeSet {
        attribute padArea : Real [cm^2] = 25.0;
        attribute gelConductive : Boolean = true;
        attribute intendedPlacement : String = "lower leg over motor points supporting calf muscle contraction";

        port leftPad : ElectrodePort;
        port rightPad : ElectrodePort;

        port contactTelemetry {
            out contactStatus : ElectrodeContactStatus;
        }
    }

    part def RechargeableBattery {
        attribute nominalVoltage : Real [V] = 3.7;
        attribute minimumOperatingVoltage : Real [V] = 3.3;
        attribute chargeRemaining : Real [%] = 100.0;

        port powerOut : PowerPort;
    }

    part def SafetyMonitor {
        attribute outputAllowed : Boolean = true;
        attribute activeFault : FaultCode = FaultCode::none;
        attribute maximumSafeCurrent : Real [mA] = 70.0;
        attribute maximumSafeTemperature : Real [K] = 318.15;
        attribute maximumValidElectrodeImpedance : Real [Ohm] = 5000.0;

        port generatorTelemetry {
            in measuredCurrent : Real [mA];
            in measuredVoltage : Real [V];
            in generatorTemperature : Real [K];
        }

        port electrodeTelemetry {
            in contactStatus : ElectrodeContactStatus;
        }

        port monitoredStatus {
            out fault : FaultCode;
            out outputAllowed : Boolean;
        }

        perform action evaluateSafety : EvaluateSafety;
    }

    part def HandheldEnclosure {
        attribute mass : Real [kg] = 0.15;
        attribute ingressProtection : String = "indoor personal therapy environment";
        attribute hasDisplay : Boolean = true;
        attribute hasIntensityButtons : Boolean = true;
        attribute hasStartStopButton : Boolean = true;
    }

    action def RunTherapySession {
        in command : TherapyCommand;
        out status : TherapyStatus;

        first start;
        then verifyBattery;
        then verifyElectrodeContact;
        then rampToComfortableIntensity;
        then deliverTimedStimulation;
        then stopOutput;
        then reportCompletion;

        action start;
        action verifyBattery;
        action verifyElectrodeContact;
        action rampToComfortableIntensity;
        action deliverTimedStimulation;
        action stopOutput;
        action reportCompletion;
    }

    action def ComputePulsePrescription {
        in requestedMode : TherapyMode;
        in requestedIntensityLevel : Integer;
        out prescribedPulse : ElectricalPulse;

        constraint intensityRange {
            requestedIntensityLevel >= 1 and requestedIntensityLevel <= 99
        }

        constraint prescribedLimits {
            prescribedPulse.amplitude <= 70.0 and
            prescribedPulse.pulseWidth <= 400.0 and
            prescribedPulse.frequency >= 1.0 and
            prescribedPulse.frequency <= 50.0 and
            prescribedPulse.polarityBalanced == true
        }
    }

    action def EvaluateSafety {
        in measuredCurrent : Real [mA];
        in generatorTemperature : Real [K];
        in contactStatus : ElectrodeContactStatus;
        out outputAllowed : Boolean;
        out fault : FaultCode;

        constraint currentLimit {
            measuredCurrent <= 70.0
        }

        constraint temperatureLimit {
            generatorTemperature <= 318.15
        }

        constraint contactLimit {
            contactStatus.contactValid == true and
            contactStatus.leftContactImpedance <= 5000.0 and
            contactStatus.rightContactImpedance <= 5000.0
        }
    }

    state def TherapyLifecycle {
        entry action initializeStatus;

        state off;
        state standby;
        state selfTest;
        state electrodeCheck;
        state rampUp;
        state stimulation;
        state paused;
        state completed;
        state fault;

        transition powerOn
            first off
            accept PowerButtonPressed
            then standby;

        transition startRequested
            first standby
            accept StartCommand
            then selfTest;

        transition selfTestPassed
            first selfTest
            if batteryVoltageOk and controllerOk and generatorOk
            then electrodeCheck;

        transition selfTestFailed
            first selfTest
            if not batteryVoltageOk or not controllerOk or not generatorOk
            then fault;

        transition electrodesValid
            first electrodeCheck
            if electrodeContactValid
            then rampUp;

        transition electrodesInvalid
            first electrodeCheck
            if not electrodeContactValid
            then fault;

        transition rampComplete
            first rampUp
            if comfortableContractionDetected or requestedIntensityReached
            then stimulation;

        transition pauseRequested
            first stimulation
            accept PauseCommand
            then paused;

        transition resumeRequested
            first paused
            accept ResumeCommand
            then stimulation;

        transition sessionComplete
            first stimulation
            if elapsedTime >= requestedDuration
            then completed;

        transition stopRequested
            first stimulation
            accept StopCommand
            then completed;

        transition safetyFault
            first stimulation
            if activeFault != FaultCode::none
            then fault;

        transition resetAfterCompletion
            first completed
            accept ResetCommand
            then standby;

        transition resetAfterFault
            first fault
            accept ResetCommand
            then standby;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : VeinoplusBasedSystem;

        doc /* The system shall provide controlled lower-limb electrical stimulation that produces repeated calf muscle contractions to support venous return during a user-selected therapy session. */

        require constraint {
            system.maximumOutputCurrent <= 70.0 and
            system.maximumPulseFrequency <= 50.0 and
            system.nominalSessionDuration == 20.0
        }
    }

    requirement def OutputWaveformRequirement {
        subject pulse : ElectricalPulse;

        require constraint {
            pulse.polarityBalanced == true and
            pulse.amplitude >= 0.0 and
            pulse.amplitude <= 70.0 and
            pulse.pulseWidth > 0.0 and
            pulse.pulseWidth <= 400.0 and
            pulse.frequency >= 1.0 and
            pulse.frequency <= 50.0
        }
    }

    requirement def ElectrodeContactRequirement {
        subject contact : ElectrodeContactStatus;

        require constraint {
            contact.contactValid == true and
            contact.leftContactImpedance <= 5000.0 and
            contact.rightContactImpedance <= 5000.0
        }
    }

    requirement def SessionControlRequirement {
        subject status : TherapyStatus;

        require constraint {
            status.elapsedTime >= 0.0 and
            status.remainingTime >= 0.0 and
            status.deliveredIntensityLevel >= 0 and
            status.deliveredIntensityLevel <= 99
        }
    }

    requirement def SafetyShutdownRequirement {
        subject monitor : SafetyMonitor;

        doc /* The system shall disable stimulation output when unsafe current, temperature, power, or electrode contact conditions are detected. */

        require constraint {
            monitor.outputAllowed == false implies monitor.activeFault != FaultCode::none
        }
    }

    satisfy PrimaryFunctionRequirement by VeinoplusBasedSystem;
    satisfy OutputWaveformRequirement by BiphasicPulseGenerator;
    satisfy ElectrodeContactRequirement by SurfaceElectrodeSet;
    satisfy SessionControlRequirement by TherapyController;
    satisfy SafetyShutdownRequirement by SafetyMonitor;
}