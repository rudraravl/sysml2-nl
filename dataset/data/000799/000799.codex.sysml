package TENSSystemModel {

    import ScalarValues::*;
    import SI::*;

    item def ElectricalPulse {
        attribute amplitude : ElectricCurrent;
        attribute pulseWidth : Time;
        attribute frequency : Frequency;
        attribute phaseDuration : Time;
        attribute netCharge : ElectricCharge;
        attribute waveformKind : PulseWaveformKind;
        attribute channelId : Integer;
    }

    item def SkinContactStatus {
        attribute impedance : Resistance;
        attribute electrodeAttached : Boolean;
        attribute contactQuality : ContactQualityKind;
    }

    item def TherapyCommand {
        attribute requestedMode : TherapyModeKind;
        attribute requestedIntensity : ElectricCurrent;
        attribute requestedFrequency : Frequency;
        attribute requestedPulseWidth : Time;
        attribute requestedDuration : Time;
        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
    }

    item def TherapyStatus {
        attribute active : Boolean;
        attribute elapsedTime : Time;
        attribute remainingTime : Time;
        attribute deliveredPulseCount : Integer;
        attribute currentMode : TherapyModeKind;
        attribute faultPresent : Boolean;
        attribute faultCode : FaultKind;
    }

    enum def TherapyModeKind {
        enum conventional;
        enum burst;
        enum modulation;
        enum acupunctureLike;
    }

    enum def PulseWaveformKind {
        enum biphasicSymmetric;
        enum biphasicAsymmetric;
        enum burstTrain;
        enum rampedModulated;
    }

    enum def ContactQualityKind {
        enum good;
        enum marginal;
        enum openCircuit;
        enum shortCircuit;
    }

    enum def FaultKind {
        enum none;
        enum lowBattery;
        enum overCurrent;
        enum electrodeDetached;
        enum excessiveImpedance;
        enum hardwareFailure;
        enum therapyTimeout;
    }

    value def Milliampere : ElectricCurrent = 1e-3 [A];
    value def Microsecond : Time = 1e-6 [s];
    value def Minute : Time = 60 [s];
    value def Ohm : Resistance = 1 [Ohm];

    part def TENSDevice {
        attribute maxOutputCurrent : ElectricCurrent = 80 [mA];
        attribute minOutputCurrent : ElectricCurrent = 0 [mA];
        attribute maxPulseWidth : Time = 300 [us];
        attribute minPulseWidth : Time = 50 [us];
        attribute maxPulseFrequency : Frequency = 150 [Hz];
        attribute minPulseFrequency : Frequency = 1 [Hz];
        attribute nominalTherapyDuration : Time = 30 [min];

        port userCommandIn : in TherapyCommand;
        port therapyStatusOut : out TherapyStatus;
        port channelAPulseOut : out ElectricalPulse;
        port channelBPulseOut : out ElectricalPulse;
        port channelAContactIn : in SkinContactStatus;
        port channelBContactIn : in SkinContactStatus;

        part controller : TherapyController;
        part userInterface : UserInterface;
        part pulseGenerator : PulseGenerator;
        part outputStage : IsolatedOutputStage;
        part electrodeSet : ElectrodeSet;
        part powerSubsystem : PowerSubsystem;
        part safetyMonitor : SafetyMonitor;

        connect userCommandIn to userInterface.externalCommandIn;
        connect userInterface.commandOut to controller.commandIn;
        connect controller.pulseRequestOut to pulseGenerator.pulseRequestIn;
        connect pulseGenerator.rawPulseOut to outputStage.rawPulseIn;
        connect outputStage.channelAPulseOut to channelAPulseOut;
        connect outputStage.channelBPulseOut to channelBPulseOut;
        connect outputStage.channelAPulseOut to electrodeSet.channelAStimulusIn;
        connect outputStage.channelBPulseOut to electrodeSet.channelBStimulusIn;
        connect electrodeSet.channelAContactOut to channelAContactIn;
        connect electrodeSet.channelBContactOut to channelBContactIn;
        connect channelAContactIn to safetyMonitor.channelAContactIn;
        connect channelBContactIn to safetyMonitor.channelBContactIn;
        connect powerSubsystem.powerStatusOut to safetyMonitor.powerStatusIn;
        connect safetyMonitor.faultOut to controller.faultIn;
        connect controller.statusOut to therapyStatusOut;
    }

    part def TherapyController {
        port commandIn : in TherapyCommand;
        port faultIn : in FaultKind;
        port pulseRequestOut : out ElectricalPulse;
        port statusOut : out TherapyStatus;

        attribute selectedMode : TherapyModeKind = TherapyModeKind::conventional;
        attribute targetIntensity : ElectricCurrent = 20 [mA];
        attribute targetFrequency : Frequency = 80 [Hz];
        attribute targetPulseWidth : Time = 200 [us];
        attribute therapyDuration : Time = 30 [min];
        attribute elapsed : Time = 0 [s];

        state def TherapyControlStateMachine {
            state idle;
            state configured;
            state rampingUp;
            state stimulating;
            state paused;
            state faulted;
            state complete;

            initial then idle;

            transition idle_to_configured
                first idle
                then configured
                accept commandIn
                if commandIn.requestedDuration > 0 [s];

            transition configured_to_rampingUp
                first configured
                then rampingUp
                accept commandIn
                if commandIn.startRequested == true and faultIn == FaultKind::none;

            transition rampingUp_to_stimulating
                first rampingUp
                then stimulating
                if targetIntensity <= commandIn.requestedIntensity;

            transition stimulating_to_paused
                first stimulating
                then paused
                accept commandIn
                if commandIn.stopRequested == true;

            transition paused_to_rampingUp
                first paused
                then rampingUp
                accept commandIn
                if commandIn.startRequested == true and faultIn == FaultKind::none;

            transition stimulating_to_complete
                first stimulating
                then complete
                if elapsed >= therapyDuration;

            transition configured_to_faulted
                first configured
                then faulted
                if faultIn != FaultKind::none;

            transition rampingUp_to_faulted
                first rampingUp
                then faulted
                if faultIn != FaultKind::none;

            transition stimulating_to_faulted
                first stimulating
                then faulted
                if faultIn != FaultKind::none;

            transition paused_to_faulted
                first paused
                then faulted
                if faultIn != FaultKind::none;

            transition complete_to_idle
                first complete
                then idle
                accept commandIn
                if commandIn.stopRequested == true;

            transition faulted_to_idle
                first faulted
                then idle
                accept commandIn
                if commandIn.stopRequested == true;
        }

        action def ConfigureTherapy {
            in command : TherapyCommand;
            out mode : TherapyModeKind;
            out intensity : ElectricCurrent;
            out frequency : Frequency;
            out pulseWidth : Time;
            out duration : Time;

            constraint intensityLimit {
                intensity >= 0 [mA] and intensity <= 80 [mA]
            }

            constraint frequencyLimit {
                frequency >= 1 [Hz] and frequency <= 150 [Hz]
            }

            constraint pulseWidthLimit {
                pulseWidth >= 50 [us] and pulseWidth <= 300 [us]
            }
        }

        action def GeneratePulseRequest {
            in mode : TherapyModeKind;
            in intensity : ElectricCurrent;
            in frequency : Frequency;
            in pulseWidth : Time;
            out requestedPulse : ElectricalPulse;
        }
    }

    part def UserInterface {
        port externalCommandIn : in TherapyCommand;
        port commandOut : out TherapyCommand;

        part display : Display;
        part buttons : ControlButtons;
        part intensityDial : IntensityControl;

        attribute locked : Boolean = false;
        attribute visibleIntensity : ElectricCurrent;
        attribute visibleRemainingTime : Time;
    }

    part def Display {
        attribute brightness : Real;
        attribute showsMode : Boolean = true;
        attribute showsIntensity : Boolean = true;
        attribute showsTimer : Boolean = true;
        attribute showsFault : Boolean = true;
    }

    part def ControlButtons {
        attribute startStopPressed : Boolean;
        attribute modePressed : Boolean;
        attribute timerPressed : Boolean;
    }

    part def IntensityControl {
        attribute setpoint : ElectricCurrent;
        attribute increment : ElectricCurrent = 1 [mA];
    }

    part def PulseGenerator {
        port pulseRequestIn : in ElectricalPulse;
        port rawPulseOut : out ElectricalPulse;

        attribute timingAccuracy : Real = 0.05;
        attribute waveform : PulseWaveformKind = PulseWaveformKind::biphasicSymmetric;

        action def ShapePulse {
            in request : ElectricalPulse;
            out shapedPulse : ElectricalPulse;

            constraint chargeBalance {
                shapedPulse.netCharge == 0 [C]
            }
        }
    }

    part def IsolatedOutputStage {
        port rawPulseIn : in ElectricalPulse;
        port channelAPulseOut : out ElectricalPulse;
        port channelBPulseOut : out ElectricalPulse;

        attribute isolationRating : ElectricPotential = 1500 [V];
        attribute maxComplianceVoltage : ElectricPotential = 100 [V];
        attribute currentRegulationTolerance : Real = 0.10;

        part currentLimiter : CurrentLimiter;
        part channelA : StimulationChannel;
        part channelB : StimulationChannel;

        connect rawPulseIn to channelA.pulseIn;
        connect rawPulseIn to channelB.pulseIn;
        connect channelA.pulseOut to channelAPulseOut;
        connect channelB.pulseOut to channelBPulseOut;
    }

    part def CurrentLimiter {
        attribute tripCurrent : ElectricCurrent = 90 [mA];
        attribute tripTime : Time = 10 [ms];
    }

    part def StimulationChannel {
        port pulseIn : in ElectricalPulse;
        port pulseOut : out ElectricalPulse;

        attribute enabled : Boolean = true;
        attribute channelImpedance : Resistance;
        attribute deliveredCurrent : ElectricCurrent;
    }

    part def ElectrodeSet {
        port channelAStimulusIn : in ElectricalPulse;
        port channelBStimulusIn : in ElectricalPulse;
        port channelAContactOut : out SkinContactStatus;
        port channelBContactOut : out SkinContactStatus;

        part channelAPad1 : ElectrodePad;
        part channelAPad2 : ElectrodePad;
        part channelBPad1 : ElectrodePad;
        part channelBPad2 : ElectrodePad;

        attribute placementRegion : String = "pain-adjacent dermatomal region";
    }

    part def ElectrodePad {
        attribute gelArea : Area = 25 [cm^2];
        attribute skinImpedance : Resistance;
        attribute attached : Boolean;
        attribute reusableCyclesRemaining : Integer;
    }

    part def PowerSubsystem {
        port powerStatusOut : out PowerStatus;

        part battery : Battery;
        part regulator : VoltageRegulator;

        connect battery.batteryVoltageOut to regulator.inputVoltageIn;
    }

    item def PowerStatus {
        attribute voltage : ElectricPotential;
        attribute stateOfCharge : Real;
        attribute lowBattery : Boolean;
    }

    part def Battery {
        port batteryVoltageOut : out ElectricPotential;

        attribute nominalVoltage : ElectricPotential = 3.7 [V];
        attribute capacity : ElectricCharge = 2500 [mA*h];
        attribute stateOfCharge : Real;
    }

    part def VoltageRegulator {
        port inputVoltageIn : in ElectricPotential;
        port regulatedVoltageOut : out ElectricPotential;

        attribute outputVoltage : ElectricPotential = 5 [V];
        attribute efficiency : Real = 0.90;
    }

    part def SafetyMonitor {
        port channelAContactIn : in SkinContactStatus;
        port channelBContactIn : in SkinContactStatus;
        port powerStatusIn : in PowerStatus;
        port faultOut : out FaultKind;

        attribute maximumAllowedCurrent : ElectricCurrent = 80 [mA];
        attribute maximumAllowedPulseWidth : Time = 300 [us];
        attribute minimumAcceptableBatteryCharge : Real = 0.10;
        attribute maximumAcceptableImpedance : Resistance = 10000 [Ohm];
        attribute minimumAcceptableImpedance : Resistance = 100 [Ohm];

        action def EvaluateSafety {
            in contactA : SkinContactStatus;
            in contactB : SkinContactStatus;
            in power : PowerStatus;
            out detectedFault : FaultKind;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject tens : TENSDevice;

        doc
        /* The system shall provide non-invasive transcutaneous electrical nerve stimulation by generating controlled, charge-balanced electrical pulses through surface electrodes placed on the skin to modulate pain signaling at a high level. */

        require constraint {
            tens.pulseGenerator.waveform == PulseWaveformKind::biphasicSymmetric or
            tens.pulseGenerator.waveform == PulseWaveformKind::biphasicAsymmetric
        }
    }

    requirement def AdjustableTherapyRequirement {
        subject tens : TENSDevice;

        doc
        /* The system shall allow the user or supervising clinician to select stimulation mode, intensity, pulse width, frequency, and therapy duration within safe operating limits. */

        require constraint {
            tens.maxOutputCurrent <= 80 [mA] and
            tens.maxPulseWidth <= 300 [us] and
            tens.maxPulseFrequency <= 150 [Hz]
        }
    }

    requirement def ChargeBalanceRequirement {
        subject pulse : ElectricalPulse;

        doc
        /* Each delivered therapeutic pulse shall be charge-balanced to reduce net direct current through skin tissue. */

        require constraint {
            pulse.netCharge == 0 [C]
        }
    }

    requirement def SkinContactSafetyRequirement {
        subject monitor : SafetyMonitor;

        doc
        /* The system shall inhibit stimulation when electrode contact is open, shorted, detached, or outside the acceptable impedance range. */

        require constraint {
            monitor.maximumAcceptableImpedance == 10000 [Ohm] and
            monitor.minimumAcceptableImpedance == 100 [Ohm]
        }
    }

    requirement def ElectricalIsolationRequirement {
        subject output : IsolatedOutputStage;

        doc
        /* The stimulation output shall be electrically isolated from user-accessible control electronics and limited to the prescribed therapeutic current. */

        require constraint {
            output.isolationRating >= 1500 [V] and
            output.currentLimiter.tripCurrent <= 90 [mA]
        }
    }

    requirement def TherapyTimeoutRequirement {
        subject controller : TherapyController;

        doc
        /* The system shall automatically stop stimulation when the configured therapy duration has elapsed. */

        require constraint {
            controller.therapyDuration <= 60 [min]
        }
    }

    part tensTherapySystem : TENSDevice {
        attribute maxOutputCurrent = 80 [mA];
        attribute maxPulseWidth = 300 [us];
        attribute maxPulseFrequency = 150 [Hz];
        attribute nominalTherapyDuration = 30 [min];

        part controller {
            attribute selectedMode = TherapyModeKind::conventional;
            attribute targetIntensity = 20 [mA];
            attribute targetFrequency = 80 [Hz];
            attribute targetPulseWidth = 200 [us];
            attribute therapyDuration = 30 [min];
        }

        part pulseGenerator {
            attribute waveform = PulseWaveformKind::biphasicSymmetric;
        }

        part safetyMonitor {
            attribute maximumAllowedCurrent = 80 [mA];
            attribute maximumAllowedPulseWidth = 300 [us];
            attribute maximumAcceptableImpedance = 10000 [Ohm];
            attribute minimumAcceptableImpedance = 100 [Ohm];
        }
    }

    satisfy PrimaryFunctionRequirement by tensTherapySystem;
    satisfy AdjustableTherapyRequirement by tensTherapySystem;
    satisfy ElectricalIsolationRequirement by tensTherapySystem.outputStage;
    satisfy SkinContactSafetyRequirement by tensTherapySystem.safetyMonitor;
    satisfy TherapyTimeoutRequirement by tensTherapySystem.controller;
}