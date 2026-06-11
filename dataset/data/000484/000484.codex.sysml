package PacemakerSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def ElectricPotentialDifference :> ISQ::electricPotentialDifference;
    attribute def ElectricCurrent :> ISQ::electricCurrent;
    attribute def ElectricCharge :> ISQ::electricCharge;
    attribute def Frequency :> ISQ::frequency;
    attribute def Duration :> ISQ::time;
    attribute def Energy :> ISQ::energy;
    attribute def Resistance :> ISQ::resistance;

    item def ElectricalPulse {
        attribute amplitude : ElectricPotentialDifference;
        attribute pulseWidth : Duration;
        attribute current : ElectricCurrent;
        attribute deliveredEnergy : Energy;
        attribute targetChamber : HeartChamberKind;
        attribute timestamp : Duration;
    }

    item def IntracardiacSignal {
        attribute sensedVoltage : ElectricPotentialDifference;
        attribute sourceChamber : HeartChamberKind;
        attribute eventTime : Duration;
        attribute classifiedAsBeat : Boolean;
    }

    item def TelemetryPacket {
        attribute batteryRemaining : Real;
        attribute operatingMode : PacingModeKind;
        attribute lowerRateLimit : Frequency;
        attribute upperTrackingRate : Frequency;
        attribute atrialCaptureThreshold : ElectricPotentialDifference;
        attribute ventricularCaptureThreshold : ElectricPotentialDifference;
        attribute lastFaultCode : FaultKind;
    }

    item def ProgrammingCommand {
        attribute requestedMode : PacingModeKind;
        attribute requestedLowerRateLimit : Frequency;
        attribute requestedUpperTrackingRate : Frequency;
        attribute requestedAtrialOutput : ElectricPotentialDifference;
        attribute requestedVentricularOutput : ElectricPotentialDifference;
        attribute authenticated : Boolean;
    }

    enum def HeartChamberKind {
        enum atrium;
        enum ventricle;
    }

    enum def PacingModeKind {
        enum AAI;
        enum VVI;
        enum DDD;
        enum DOO;
        enum safeVVI;
        enum standby;
    }

    enum def FaultKind {
        enum none;
        enum lowBattery;
        enum leadImpedanceOutOfRange;
        enum captureNotConfirmed;
        enum sensingNoise;
        enum therapyInhibited;
        enum processorWatchdogReset;
    }

    port def ElectrodePort {
        in item cardiacSignal : IntracardiacSignal;
        out item pacingPulse : ElectricalPulse;
        attribute electrodeImpedance : Resistance;
    }

    port def TelemetryPort {
        in item command : ProgrammingCommand;
        out item status : TelemetryPacket;
    }

    port def PowerPort {
        out attribute supplyVoltage : ElectricPotentialDifference;
        out attribute availableCharge : ElectricCharge;
    }

    part def CardiacTissue {
        port atrialInterface : ElectrodePort;
        port ventricularInterface : ElectrodePort;

        attribute intrinsicAtrialRate : Frequency = 1.17 [Hz];
        attribute intrinsicVentricularRate : Frequency = 1.0 [Hz];
        attribute atrialCaptureThreshold : ElectricPotentialDifference = 0.75 [V];
        attribute ventricularCaptureThreshold : ElectricPotentialDifference = 1.0 [V];
        attribute refractoryPeriod : Duration = 250 [ms];

        perform action generateIntrinsicActivity {
            out item atrialSignal : IntracardiacSignal;
            out item ventricularSignal : IntracardiacSignal;
        }
    }

    part def PulseGenerator {
        port atrialLeadPort : ElectrodePort;
        port ventricularLeadPort : ElectrodePort;
        port powerInput : PowerPort;

        attribute atrialOutputAmplitude : ElectricPotentialDifference = 2.5 [V];
        attribute ventricularOutputAmplitude : ElectricPotentialDifference = 3.0 [V];
        attribute atrialPulseWidth : Duration = 0.4 [ms];
        attribute ventricularPulseWidth : Duration = 0.4 [ms];
        attribute maxPulseCurrent : ElectricCurrent = 10 [mA];

        perform action deliverAtrialPulse {
            out item pulse : ElectricalPulse {
                attribute targetChamber = HeartChamberKind::atrium;
                attribute amplitude = atrialOutputAmplitude;
                attribute pulseWidth = atrialPulseWidth;
            }
        }

        perform action deliverVentricularPulse {
            out item pulse : ElectricalPulse {
                attribute targetChamber = HeartChamberKind::ventricle;
                attribute amplitude = ventricularOutputAmplitude;
                attribute pulseWidth = ventricularPulseWidth;
            }
        }
    }

    part def SenseAmplifier {
        port atrialSensePort : ElectrodePort;
        port ventricularSensePort : ElectrodePort;

        attribute atrialSensitivity : ElectricPotentialDifference = 0.5 [mV];
        attribute ventricularSensitivity : ElectricPotentialDifference = 2.0 [mV];
        attribute blankingPeriod : Duration = 120 [ms];
        attribute noiseThreshold : ElectricPotentialDifference = 8.0 [mV];

        perform action classifyAtrialEvent {
            in item rawSignal : IntracardiacSignal;
            out item sensedEvent : IntracardiacSignal;
        }

        perform action classifyVentricularEvent {
            in item rawSignal : IntracardiacSignal;
            out item sensedEvent : IntracardiacSignal;
        }
    }

    part def TimingController {
        attribute mode : PacingModeKind = PacingModeKind::DDD;
        attribute lowerRateLimit : Frequency = 1.0 [Hz];
        attribute upperTrackingRate : Frequency = 2.17 [Hz];
        attribute atrioventricularDelay : Duration = 160 [ms];
        attribute postVentricularAtrialRefractoryPeriod : Duration = 250 [ms];
        attribute ventricularRefractoryPeriod : Duration = 250 [ms];

        perform action evaluateCycle {
            in item atrialEvent : IntracardiacSignal;
            in item ventricularEvent : IntracardiacSignal;
            out attribute paceAtrium : Boolean;
            out attribute paceVentricle : Boolean;
        }

        state machine pacingControl {
            state initializing;
            state monitoring;
            state atrialSensed;
            state atrialPaced;
            state waitingForVentricle;
            state ventricularSensed;
            state ventricularPaced;
            state refractory;
            state safeMode;

            entry;
            transition first initialize from entry to initializing;

            transition ready from initializing to monitoring
                accept after 2 [s];

            transition atrialDetected from monitoring to atrialSensed
                accept IntracardiacSignal
                if classifiedAsBeat == true and sourceChamber == HeartChamberKind::atriium;

            transition atrialTimeout from monitoring to atrialPaced
                accept after 1000 [ms];

            transition startAVAfterSense from atrialSensed to waitingForVentricle;

            transition startAVAfterPace from atrialPaced to waitingForVentricle
                do sendAtrialPaceCommand;

            transition ventricularDetected from waitingForVentricle to ventricularSensed
                accept IntracardiacSignal
                if classifiedAsBeat == true and sourceChamber == HeartChamberKind::ventricle;

            transition avTimeout from waitingForVentricle to ventricularPaced
                accept after atrioventricularDelay
                do sendVentricularPaceCommand;

            transition sensedRefractory from ventricularSensed to refractory;

            transition pacedRefractory from ventricularPaced to refractory;

            transition endRefractory from refractory to monitoring
                accept after ventricularRefractoryPeriod;

            transition faulted from monitoring to safeMode
                accept FaultKind
                if self != FaultKind::none;

            transition recover from safeMode to monitoring
                accept ProgrammingCommand
                if authenticated == true and requestedMode != PacingModeKind::safeVVI;
        }

        action sendAtrialPaceCommand;
        action sendVentricularPaceCommand;
    }

    part def Battery {
        port output : PowerPort;

        attribute nominalVoltage : ElectricPotentialDifference = 2.8 [V];
        attribute electiveReplacementVoltage : ElectricPotentialDifference = 2.6 [V];
        attribute endOfServiceVoltage : ElectricPotentialDifference = 2.2 [V];
        attribute remainingCharge : ElectricCharge = 1.2 [A*h];
        attribute selfDischargeRate : ElectricCurrent = 0.5 [uA];

        perform action supplyPower {
            out attribute voltage : ElectricPotentialDifference = nominalVoltage;
            out attribute charge : ElectricCharge = remainingCharge;
        }
    }

    part def Lead {
        port proximal : ElectrodePort;
        port distal : ElectrodePort;

        attribute conductorResistance : Resistance = 80 [Ohm];
        attribute expectedImpedanceMin : Resistance = 200 [Ohm];
        attribute expectedImpedanceMax : Resistance = 1500 [Ohm];
        attribute insulationIntegrity : Real = 1.0;

        perform action conductPulse {
            in item pulseIn : ElectricalPulse;
            out item pulseOut : ElectricalPulse;
        }

        perform action conductSenseSignal {
            in item signalIn : IntracardiacSignal;
            out item signalOut : IntracardiacSignal;
        }
    }

    part def TelemetryModule {
        port telemetry : TelemetryPort;

        attribute communicationRange : LengthValue = 2.0 [m];
        attribute authenticatedSession : Boolean = false;

        perform action receiveProgramming {
            in item command : ProgrammingCommand;
            out item verifiedCommand : ProgrammingCommand;
        }

        perform action transmitStatus {
            in item status : TelemetryPacket;
            out item packet : TelemetryPacket;
        }
    }

    part def Diagnostics {
        attribute currentFault : FaultKind = FaultKind::none;
        attribute minimumBatteryMargin : ElectricPotentialDifference = 0.2 [V];
        attribute lastMeasuredAtrialImpedance : Resistance = 600 [Ohm];
        attribute lastMeasuredVentricularImpedance : Resistance = 650 [Ohm];

        perform action checkBattery {
            in attribute voltage : ElectricPotentialDifference;
            out attribute lowBatteryDetected : Boolean;
        }

        perform action checkLeadIntegrity {
            in attribute atrialImpedance : Resistance;
            in attribute ventricularImpedance : Resistance;
            out attribute leadFaultDetected : Boolean;
        }

        perform action confirmCapture {
            in item deliveredPulse : ElectricalPulse;
            in item responseSignal : IntracardiacSignal;
            out attribute captured : Boolean;
        }
    }

    part def Pacemaker {
        part battery : Battery;
        part pulseGenerator : PulseGenerator;
        part senseAmplifier : SenseAmplifier;
        part timingController : TimingController;
        part telemetryModule : TelemetryModule;
        part diagnostics : Diagnostics;
        part atrialLead : Lead;
        part ventricularLead : Lead;

        port atrialElectrode : ElectrodePort;
        port ventricularElectrode : ElectrodePort;
        port clinicalProgrammerLink : TelemetryPort;

        attribute mass : MassValue = 25 [g];
        attribute implantLifetimeTarget : Duration = 10 [yr];
        attribute primaryFunction : String = "Monitor intrinsic cardiac electrical activity and deliver timed electrical stimulation to maintain adequate heart rhythm when intrinsic pacing is absent or unsafe.";

        connect battery.output to pulseGenerator.powerInput;

        connect pulseGenerator.atrialLeadPort to atrialLead.proximal;
        connect pulseGenerator.ventricularLeadPort to ventricularLead.proximal;

        connect senseAmplifier.atrialSensePort to atrialLead.proximal;
        connect senseAmplifier.ventricularSensePort to ventricularLead.proximal;

        connect atrialLead.distal to atrialElectrode;
        connect ventricularLead.distal to ventricularElectrode;

        connect telemetryModule.telemetry to clinicalProgrammerLink;

        perform action provideBradycardiaTherapy {
            first start;
            then senseCardiacSignals;
            then classifyRhythm;
            then decideTherapy;
            then deliverRequiredPulse;
            then updateDiagnostics;
            then reportStatus;
        }

        action senseCardiacSignals {
            out item atrialEvent : IntracardiacSignal;
            out item ventricularEvent : IntracardiacSignal;
        }

        action classifyRhythm {
            in item atrialEvent : IntracardiacSignal;
            in item ventricularEvent : IntracardiacSignal;
            out attribute bradycardiaDetected : Boolean;
            out attribute avBlockDetected : Boolean;
        }

        action decideTherapy {
            in attribute bradycardiaDetected : Boolean;
            in attribute avBlockDetected : Boolean;
            out attribute commandAtrialPace : Boolean;
            out attribute commandVentricularPace : Boolean;
        }

        action deliverRequiredPulse {
            in attribute commandAtrialPace : Boolean;
            in attribute commandVentricularPace : Boolean;
            out item deliveredPulse : ElectricalPulse;
        }

        action updateDiagnostics {
            in item deliveredPulse : ElectricalPulse;
            out attribute fault : FaultKind;
        }

        action reportStatus {
            out item telemetryPacket : TelemetryPacket;
        }
    }

    part def ExternalProgrammer {
        port telemetry : TelemetryPort;

        attribute operatorAuthenticated : Boolean = false;

        perform action configurePacemaker {
            out item command : ProgrammingCommand {
                attribute requestedMode = PacingModeKind::DDD;
                attribute requestedLowerRateLimit = 1.0 [Hz];
                attribute requestedUpperTrackingRate = 2.17 [Hz];
                attribute requestedAtrialOutput = 2.5 [V];
                attribute requestedVentricularOutput = 3.0 [V];
                attribute authenticated = operatorAuthenticated;
            }
        }

        perform action readPacemakerStatus {
            in item status : TelemetryPacket;
        }
    }

    part def Patient {
        part heart : CardiacTissue;
        part implantedPacemaker : Pacemaker;

        connect heart.atrialInterface to implantedPacemaker.atrialElectrode;
        connect heart.ventricularInterface to implantedPacemaker.ventricularElectrode;
    }

    part def PacemakerTherapySystem {
        part patient : Patient;
        part programmer : ExternalProgrammer;

        connect programmer.telemetry to patient.implantedPacemaker.clinicalProgrammerLink;
    }

    requirement def MaintainAdequateHeartRate {
        doc /* The pacemaker shall maintain ventricular rate at or above the programmed lower rate limit when no intrinsic ventricular event is sensed. */
        attribute minimumRate : Frequency = 1.0 [Hz];

        require constraint {
            patient.implantedPacemaker.timingController.lowerRateLimit >= minimumRate
        }
    }

    requirement def SenseIntrinsicActivity {
        doc /* The pacemaker shall sense atrial and ventricular intracardiac signals above the programmed sensitivity thresholds. */
        attribute atrialSensitivityMaximum : ElectricPotentialDifference = 0.5 [mV];
        attribute ventricularSensitivityMaximum : ElectricPotentialDifference = 2.0 [mV];

        require constraint {
            patient.implantedPacemaker.senseAmplifier.atrialSensitivity <= atrialSensitivityMaximum and
            patient.implantedPacemaker.senseAmplifier.ventricularSensitivity <= ventricularSensitivityMaximum
        }
    }

    requirement def DeliverCapturePulse {
        doc /* Each pacing pulse shall provide programmable amplitude and pulse width sufficient to capture the selected chamber with diagnostic confirmation. */
        attribute ventricularOutputMinimum : ElectricPotentialDifference = 2.0 [V];
        attribute atrialOutputMinimum : ElectricPotentialDifference = 1.5 [V];

        require constraint {
            patient.implantedPacemaker.pulseGenerator.atrialOutputAmplitude >= atrialOutputMinimum and
            patient.implantedPacemaker.pulseGenerator.ventricularOutputAmplitude >= ventricularOutputMinimum
        }
    }

    requirement def ConserveBatteryLife {
        doc /* The implanted device shall support a target service life of at least ten years under nominal DDD pacing conditions. */
        attribute requiredLifetime : Duration = 10 [yr];

        require constraint {
            patient.implantedPacemaker.implantLifetimeTarget >= requiredLifetime
        }
    }

    requirement def DetectSafetyFaults {
        doc /* The pacemaker shall detect low battery, abnormal lead impedance, sensing noise, and loss of capture and transition to a safe pacing mode when therapy reliability is impaired. */
        attribute safeMode : PacingModeKind = PacingModeKind::safeVVI;

        require constraint {
            patient.implantedPacemaker.diagnostics.currentFault == FaultKind::none or
            patient.implantedPacemaker.timingController.mode == safeMode
        }
    }

    requirement def SecureProgramming {
        doc /* The pacemaker shall accept parameter changes only from an authenticated external programmer session. */

        require constraint {
            patient.implantedPacemaker.telemetryModule.authenticatedSession == true
        }
    }

    satisfy MaintainAdequateHeartRate by PacemakerTherapySystem::patient.implantedPacemaker;
    satisfy SenseIntrinsicActivity by PacemakerTherapySystem::patient.implantedPacemaker.senseAmplifier;
    satisfy DeliverCapturePulse by PacemakerTherapySystem::patient.implantedPacemaker.pulseGenerator;
    satisfy ConserveBatteryLife by PacemakerTherapySystem::patient.implantedPacemaker.battery;
    satisfy DetectSafetyFaults by PacemakerTherapySystem::patient.implantedPacemaker.diagnostics;
    satisfy SecureProgramming by PacemakerTherapySystem::patient.implantedPacemaker.telemetryModule;

    analysis def TherapyTimingAnalysis {
        subject pacemaker : Pacemaker;

        objective verifyLowerRateInterval {
            attribute lowerRateInterval : Duration;
            constraint {
                lowerRateInterval == 1 [s] / pacemaker.timingController.lowerRateLimit
            }
        }

        objective verifyAVDelay {
            constraint {
                pacemaker.timingController.atrioventricularDelay >= 80 [ms] and
                pacemaker.timingController.atrioventricularDelay <= 220 [ms]
            }
        }
    }

    verification def PacemakerSystemVerification {
        subject systemUnderTest : PacemakerTherapySystem;

        objective verifyPulseDelivery {
            requirement DeliverCapturePulse;
            action simulateAbsentIntrinsicBeat;
            action observeVentricularPulse;
        }

        objective verifyFaultResponse {
            requirement DetectSafetyFaults;
            action injectLeadImpedanceFault;
            action observeSafeModeTransition;
        }

        objective verifyTelemetrySecurity {
            requirement SecureProgramming;
            action sendUnauthenticatedProgrammingCommand;
            action confirmRejectedCommand;
        }
    }
}