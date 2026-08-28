package AED {
    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Energy :> Real {> Joule; }
    value def Resistance :> Real {> Ohm; }
    value def Frequency :> Real {> Hertz; }
    value def Duration :> Real {> Second; }
    value def Percent :> Real { unit '%'; }
    value def ChargeLevel :> Percent;

    // ---------- Item Types ----------
    item def ECGSignal {
        attribute amplitude : Voltage;
        attribute sampleRate : Frequency;
    }
    item def RhythmAnalysisResult {
        attribute shockAdvised : Boolean;
        attribute rhythmType : String;
        attribute confidence : Percent;
    }
    item def ShockCommand {
        attribute energyLevel : Energy;
        attribute waveformType : String;
    }
    item def BiphasicPulse {
        attribute phase1Energy : Energy;
        attribute phase2Energy : Energy;
        attribute phase1Duration : Duration;
        attribute phase2Duration : Duration;
        attribute peakCurrent : Current;
    }
    item def VoicePrompt {
        attribute message : String;
        attribute priority : Integer;
    }
    item def DisplayInstruction {
        attribute text : String;
        attribute flashingShockButton : Boolean;
    }
    item def SafetyStatus {
        attribute padsContactGood : Boolean;
        attribute impedanceSafe : Boolean;
        attribute capacitorCharged : Boolean;
        attribute operatorConfirmed : Boolean;
        attribute allClear : Boolean;
    }
    item def BatteryStatus {
        attribute chargeLevel : Percent;
        attribute voltage : Voltage;
        attribute sufficient : Boolean;
    }

    // ---------- Port Definitions ----------
    port def ECGSignalOut {
        out signal : ECGSignal;
    }
    port def ECGSignalIn {
        in signal : ECGSignal;
    }
    port def AnalysisResultOut {
        out result : RhythmAnalysisResult;
    }
    port def AnalysisResultIn {
        in result : RhythmAnalysisResult;
    }
    port def ShockCmdOut {
        out cmd : ShockCommand;
    }
    port def ShockCmdIn {
        in cmd : ShockCommand;
    }
    port def PulseOut {
        out pulse : BiphasicPulse;
    }
    port def PulseIn {
        in pulse : BiphasicPulse;
    }
    port def PowerOut {
        out voltage : Voltage;
        out current : Current;
    }
    port def PowerIn {
        in voltage : Voltage;
        in current : Current;
    }
    port def ChargeCmdOut {
        out targetEnergy : Energy;
    }
    port def ChargeCmdIn {
        in targetEnergy : Energy;
    }
    port def ChargeStatusOut {
        out level : ChargeLevel;
        out charged : Boolean;
    }
    port def ChargeStatusIn {
        in level : ChargeLevel;
        in charged : Boolean;
    }
    port def SafetyStatusOut {
        out status : SafetyStatus;
    }
    port def SafetyStatusIn {
        in status : SafetyStatus;
    }
    port def BatteryStatusOut {
        out status : BatteryStatus;
    }
    port def BatteryStatusIn {
        in status : BatteryStatus;
    }
    port def VoicePromptOut {
        out prompt : VoicePrompt;
    }
    port def DisplayOut {
        out instruction : DisplayInstruction;
    }
    port def OperatorInputIn {
        in shockButtonPressed : Boolean;
        in powerOn : Boolean;
    }
    port def OperatorInputOut {
        out shockButtonPressed : Boolean;
        out powerOn : Boolean;
    }
    port def ImpedanceSenseOut {
        out impedance : Resistance;
    }
    port def ImpedanceSenseIn {
        in impedance : Resistance;
    }
    port def PadContactOut {
        out contactGood : Boolean;
    }
    port def PadContactIn {
        in contactGood : Boolean;
    }

    // ---------- Control Processor ----------
    part def ControlProcessor {
        port ecgResultIn : AnalysisResultIn;
        port safetyIn : SafetyStatusIn;
        port batteryIn : BatteryStatusIn;
        port chargeStatusIn : ChargeStatusIn;
        port operatorIn : OperatorInputIn;
        port chargeCmdOut : ChargeCmdOut;
        port shockCmdOut : ShockCmdOut;
        port voiceOut : VoicePromptOut;
        port displayOut : DisplayOut;

        attribute targetEnergy : Energy = 150 [J];
        attribute maxEnergy : Energy = 360 [J];
        attribute minEnergy : Energy = 120 [J];

        state machine behavior :> StateMachine {
            entry; then idle;

            state idle;
            transition idle_to_monitor
                first idle
                accept OperatorInputIn::powerOn
                then monitoring;

            state monitoring {
                entry { send voiceOut.prompt(VoicePrompt{message="Apply pads to patient's bare chest.", priority=1}); }
            }
            transition monitor_to_analyze
                first monitoring
                accept SafetyStatusOut::status[s.padsContactGood == true]
                then analyzing;

            state analyzing {
                entry { send voiceOut.prompt(VoicePrompt{message="Analyzing heart rhythm, do not touch the patient.", priority=1}); }
            }
            transition analyze_to_shockAdvised
                first analyzing
                accept AnalysisResultOut::result[r.shockAdvised == true]
                then shockAdvised;
            transition analyze_to_noShock
                first analyzing
                accept AnalysisResultOut::result[r.shockAdvised == false]
                then noShockAdvised;

            state shockAdvised {
                entry {
                    send voiceOut.prompt(VoicePrompt{message="Shock advised, press the flashing shock button.", priority=1});
                    send displayOut.instruction(DisplayInstruction{text="SHOCK ADVISED", flashingShockButton=true});
                    send chargeCmdOut.targetEnergy(targetEnergy);
                }
            }
            transition shockAdvised_to_charging
                first shockAdvised
                accept ChargeStatusOut::charged[c == true]
                then charging;

            state charging {
                entry { send voiceOut.prompt(VoicePrompt{message="Charging, stand clear.", priority=2}); }
            }
            transition charging_to_ready
                first charging
                accept ChargeStatusOut::level[l >= 100 '%']
                then readyToShock;

            state readyToShock {
                entry { send displayOut.instruction(DisplayInstruction{text="PRESS SHOCK BUTTON", flashingShockButton=true}); }
            }
            transition ready_to_deliver
                first readyToShock
                accept OperatorInputIn::shockButtonPressed[p == true]
                guard safetyIn.status.allClear == true
                then delivering;

            state delivering {
                entry { send shockCmdOut.cmd(ShockCommand{energyLevel=targetEnergy, waveformType="biphasic"}); }
            }
            transition deliver_to_postShock
                first delivering
                accept PulseOut::pulse
                then postShock;

            state postShock {
                entry { send voiceOut.prompt(VoicePrompt{message="Shock delivered. Beginning re-analysis.", priority=1}); }
            }
            transition postShock_to_analyze
                first postShock
                accept Time::Timer[t >= 5 's']
                then analyzing;

            state noShockAdvised {
                entry {
                    send voiceOut.prompt(VoicePrompt{message="No shock advised. Continue CPR.", priority=1});
                    send displayOut.instruction(DisplayInstruction{text="NO SHOCK ADVISED", flashingShockButton=false});
                }
            }
            transition noShock_to_analyze
                first noShockAdvised
                accept Time::Timer[t >= 30 's']
                then analyzing;

            transition any_to_lowBattery
                first monitoring | analyzing | shockAdvised | charging | readyToShock | noShockAdvised
                accept BatteryStatusOut::status[s.sufficient == false]
                then lowBattery;

            state lowBattery {
                entry { send voiceOut.prompt(VoicePrompt{message="Low battery. Replace battery.", priority=3}); }
            }
        }
    }

    // ---------- Electrode Pads ----------
    part def ElectrodePads {
        port ecgOut : ECGSignalOut;
        port pulseIn : PulseIn;
        port contactOut : PadContactOut;
        port impedanceOut : ImpedanceSenseOut;

        attribute contactThreshold : Resistance = 50 [Ohm];
        attribute measuredImpedance : Resistance;

        action def senseECG {
            in patientSignal : Voltage;
            out ecg : ECGSignal;
        }
        action def measureImpedance {
            out impedance : Resistance;
            out contactGood : Boolean;
        }
        action def deliverShock {
            in pulse : BiphasicPulse;
        }
    }

    // ---------- ECG Analysis Module ----------
    part def ECGAnalysisModule {
        port ecgIn : ECGSignalIn;
        port resultOut : AnalysisResultOut;
        port impedanceIn : ImpedanceSenseIn;

        attribute sampleWindow : Duration = 5 [s];
        attribute vfThreshold : Frequency = 4 [Hz];
        attribute minConfidence : Percent = 75 '%';

        action def analyzeRhythm {
            in signal : ECGSignal;
            in impedance : Resistance;
            out result : RhythmAnalysisResult;

            // Decision logic encapsulated as a behavior
            if signal.amplitude < 0.1 [mV] and impedance > 150 [Ohm] {
                result.rhythmType = "asystole";
                result.shockAdvised = false;
            } else if signal.sampleRate components indicate ventricularFibrillation {
                result.rhythmType = "ventricularFibrillation";
                result.shockAdvised = true;
            } else if rhythmPattern == "ventricularTachycardia" {
                result.rhythmType = "ventricularTachycardia";
                result.shockAdvised = true;
            } else {
                result.rhythmType = "normalSinusRhythm";
                result.shockAdvised = false;
            }
        }
    }

    // ---------- Battery Pack ----------
    part def BatteryPack {
        port powerOut : PowerOut;
        port statusOut : BatteryStatusOut;

        attribute nominalVoltage : Voltage = 12 [V];
        attribute capacity : Energy = 50000 [J];
        attribute currentCharge : Energy;
        attribute lowThreshold : Percent = 15 '%';

        action def supplyPower {
            out voltage : Voltage;
            out current : Current;
        }
        action def reportStatus {
            out status : BatteryStatus;
        }
    }

    // ---------- Energy Storage Unit ----------
    part def EnergyStorageUnit {
        port powerIn : PowerIn;
        port chargeCmdIn : ChargeCmdIn;
        port chargeStatusOut : ChargeStatusOut;
        port energyOut : PowerOut;

        attribute capacitance : Real = 200 [uF];
        attribute maxVoltage : Voltage = 2300 [V];
        attribute storedEnergy : Energy;
        attribute chargeTime : Duration = 8 [s];

        action def charge {
            in targetEnergy : Energy;
            out level : ChargeLevel;
            out charged : Boolean;
        }
        action def discharge {
            out voltage : Voltage;
            out current : Current;
        }
    }

    // ---------- Shock Delivery Circuit ----------
    part def ShockDeliveryCircuit {
        port energyIn : PowerIn;
        port cmdIn : ShockCmdIn;
        port impedanceIn : ImpedanceSenseIn;
        port pulseOut : PulseOut;

        attribute phase1Duration : Duration = 4 [ms];
        attribute phase2Duration : Duration = 4 [ms];
        attribute impedanceCompensation : Boolean = true;

        action def generateBiphasicPulse {
            in energy : Energy;
            in impedance : Resistance;
            out pulse : BiphasicPulse;

            // Compensate for patient impedance
            attribute adjustedPhase1Energy : Energy = energy * 0.6;
            attribute adjustedPhase2Energy : Energy = energy * 0.4;
            attribute peakCurrent : Current = (energy / impedance) ^ 0.5;
        }
    }

    // ---------- Safety Interlock System ----------
    part def SafetyInterlockSystem {
        port padContactIn : PadContactIn;
        port impedanceIn : ImpedanceSenseIn;
        port chargeStatusIn : ChargeStatusIn;
        port operatorIn : OperatorInputIn;
        port statusOut : SafetyStatusOut;

        attribute minSafeImpedance : Resistance = 25 [Ohm];
        attribute maxSafeImpedance : Resistance = 180 [Ohm];

        action def evaluateSafety {
            in padsContactGood : Boolean;
            in impedance : Resistance;
            in capacitorCharged : Boolean;
            in operatorConfirmed : Boolean;
            out status : SafetyStatus;

            status.padsContactGood = padsContactGood;
            status.impedanceSafe = (impedance >= minSafeImpedance and impedance <= maxSafeImpedance);
            status.capacitorCharged = capacitorCharged;
            status.operatorConfirmed = operatorConfirmed;
            status.allClear = status.padsContactGood and status.impedanceSafe and status.capacitorCharged and status.operatorConfirmed;
        }
    }

    // ---------- Operator Interface ----------
    part def OperatorInterface {
        port voiceIn : VoicePromptOut;
        port displayIn : DisplayOut;
        port operatorOut : OperatorInputOut;

        attribute supportedLanguage : String = "en";
        attribute volume : Real = 0.8;

        action def playVoicePrompt {
            in prompt : VoicePrompt;
        }
        action def updateDisplay {
            in instruction : DisplayInstruction;
        }
        action def captureOperatorInput {
            out shockButtonPressed : Boolean;
            out powerOn : Boolean;
        }
    }

    // ---------- Top-level AED ----------
    part def AutomatedExternalDefibrillator {
        part controlProcessor : ControlProcessor;
        part electrodePads : ElectrodePads;
        part ecgAnalysis : ECGAnalysisModule;
        part batteryPack : BatteryPack;
        part energyStorage : EnergyStorageUnit;
        part shockCircuit : ShockDeliveryCircuit;
        part safetyInterlock : SafetyInterlockSystem;
        part operatorInterface : OperatorInterface;

        // Power distribution
        connection def PowerFlow {
            end source : PowerOut;
            end target : PowerIn;
        }
        connection powerBatteryToStorage : PowerFlow connect batteryPack.powerOut to energyStorage.powerIn;
        connection powerBatteryToShock : PowerFlow connect batteryPack.powerOut to shockCircuit.energyIn;

        // ECG signal path
        connection def ECGFlow {
            end source : ECGSignalOut;
            end target : ECGSignalIn;
        }
        connection ecgPadsToAnalysis : ECGFlow connect electrodePads.ecgOut to ecgAnalysis.ecgIn;

        // Analysis result to control processor
        connection def ResultFlow {
            end source : AnalysisResultOut;
            end target : AnalysisResultIn;
        }
        connection analysisToControl : ResultFlow connect ecgAnalysis.resultOut to controlProcessor.ecgResultIn;

        // Impedance sensing
        connection def ImpedanceFlow {
            end source : ImpedanceSenseOut;
            end target : ImpedanceSenseIn;
        }
        connection impedancePadsToAnalysis : ImpedanceFlow connect electrodePads.impedanceOut to ecgAnalysis.impedanceIn;
        connection impedancePadsToSafety : ImpedanceFlow connect electrodePads.impedanceOut to safetyInterlock.impedanceIn;
        connection impedancePadsToShock : ImpedanceFlow connect electrodePads.impedanceOut to shockCircuit.impedanceIn;

        // Pad contact
        connection def ContactFlow {
            end source : PadContactOut;
            end target : PadContactIn;
        }
        connection contactPadsToSafety : ContactFlow connect electrodePads.contactOut to safetyInterlock.padContactIn;

        // Charge command and status
        connection def ChargeCmdFlow {
            end source : ChargeCmdOut;
            end target : ChargeCmdIn;
        }
        connection chargeCmdControlToStorage : ChargeCmdFlow connect controlProcessor.chargeCmdOut to energyStorage.chargeCmdIn;

        connection def ChargeStatusFlow {
            end source : ChargeStatusOut;
            end target : ChargeStatusIn;
        }
        connection chargeStatusStorageToControl : ChargeStatusFlow connect energyStorage.chargeStatusOut to controlProcessor.chargeStatusIn;
        connection chargeStatusStorageToSafety : ChargeStatusFlow connect energyStorage.chargeStatusOut to safetyInterlock.chargeStatusIn;

        // Shock command and pulse delivery
        connection def ShockCmdFlow {
            end source : ShockCmdOut;
            end target : ShockCmdIn;
        }
        connection shockCmdControlToCircuit : ShockCmdFlow connect controlProcessor.shockCmdOut to shockCircuit.cmdIn;

        connection def PulseFlow {
            end source : PulseOut;
            end target : PulseIn;
        }
        connection pulseCircuitToPads : PulseFlow connect shockCircuit.pulseOut to electrodePads.pulseIn;

        // Safety status to control processor
        connection def SafetyFlow {
            end source : SafetyStatusOut;
            end target : SafetyStatusIn;
        }
        connection safetyToControl : SafetyFlow connect safetyInterlock.statusOut to controlProcessor.safetyIn;

        // Battery status to control processor
        connection def BatteryStatusFlow {
            end source : BatteryStatusOut;
            end target : BatteryStatusIn;
        }
        connection batteryToControl : BatteryStatusFlow connect batteryPack.statusOut to controlProcessor.batteryIn;

        // Operator interface
        connection def VoiceFlow {
            end source : VoicePromptOut;
            end target : VoicePromptOut;
        }
        connection voiceControlToInterface : VoiceFlow connect controlProcessor.voiceOut to operatorInterface.voiceIn;

        connection def DisplayFlow {
            end source : DisplayOut;
            end target : DisplayOut;
        }
        connection displayControlToInterface : DisplayFlow connect controlProcessor.displayOut to operatorInterface.displayIn;

        connection def OperatorInputFlow {
            end source : OperatorInputOut;
            end target : OperatorInputIn;
        }
        connection operatorInterfaceToControl : OperatorInputFlow connect operatorInterface.operatorOut to controlProcessor.operatorIn;
        connection operatorInterfaceToSafety : OperatorInputFlow connect operatorInterface.operatorOut to safetyInterlock.operatorIn;
    }

    // ---------- Requirements ----------
    requirement def ShallDeliverControlledShock {
        subject aed : AutomatedExternalDefibrillator;
        requirement {
            the aed shall deliver a biphasic electrical shock of energy between 120 [J] and 360 [J] when a shockable rhythm is detected and all safety conditions are satisfied.
        }
    }
    requirement def ShallAnalyzeECG {
        subject module : ECGAnalysisModule;
        requirement {
            the module shall analyze the ECG signal within 10 [s] of pad application and provide a shockAdvised recommendation with confidence greater than 75 '%'.
        }
    }
    requirement def ShallPreventAccidentalShock {
        subject safety : SafetyInterlockSystem;
        requirement {
            the safety shall prevent shock delivery unless padsContactGood, impedanceSafe, capacitorCharged, and operatorConfirmed are all true.
        }
    }
    requirement def ShallChargeCapacitor {
        subject storage : EnergyStorageUnit;
        requirement {
            the storage shall charge the capacitor to the commanded energy level within 10 [s] of receiving the charge command.
        }
    }
    requirement def ShallCompensateForImpedance {
        subject circuit : ShockDeliveryCircuit;
        requirement {
            the circuit shall compensate for patient impedance between 25 [Ohm] and 180 [Ohm] to deliver the commanded energy within 10 '% tolerance.
        }
    }
    requirement def ShallProvideVoiceGuidance {
        subject iface : OperatorInterface;
        requirement {
            the iface shall provide clear voice prompts and visual instructions guiding the operator through pad application, analysis, charging, and shock delivery.
        }
    }
    requirement def ShallReanalyzeAfterShock {
        subject aed : AutomatedExternalDefibrillator;
        requirement {
            the aed shall re-analyze the heart rhythm within 5 [s] following shock delivery to determine the next protocol step.
        }
    }
    requirement def ShallReportBatteryStatus {
        subject battery : BatteryPack;
        requirement {
            the battery shall report charge level and voltage, and indicate insufficient charge when remaining capacity falls below 15 '%'.
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction def AEDShockSatisfaction :> ShallDeliverControlledShock {
        subject aed : AutomatedExternalDefibrillator;
        requirement { the aed satisfies ShallDeliverControlledShock via controlProcessor.targetEnergy and shockCircuit.generateBiphasicPulse. }
    }
    satisfaction def ECGAnalysisSatisfaction :> ShallAnalyzeECG {
        subject module : ECGAnalysisModule;
        requirement { the module satisfies ShallAnalyzeECG via analyzeRhythm action. }
    }
    satisfaction def SafetySatisfaction :> ShallPreventAccidentalShock {
        subject safety : SafetyInterlockSystem;
        requirement { the safety satisfies ShallPreventAccidentalShock via evaluateSafety action. }
    }
    satisfaction def ChargeSatisfaction :> ShallChargeCapacitor {
        subject storage : EnergyStorageUnit;
        requirement { the storage satisfies ShallChargeCapacitor via charge action. }
    }
    satisfaction def ImpedanceSatisfaction :> ShallCompensateForImpedance {
        subject circuit : ShockDeliveryCircuit;
        requirement { the circuit satisfies ShallCompensateForImpedance via generateBiphasicPulse action. }
    }
    satisfaction def VoiceSatisfaction :> ShallProvideVoiceGuidance {
        subject iface : OperatorInterface;
        requirement { the iface satisfies ShallProvideVoiceGuidance via playVoicePrompt and updateDisplay actions. }
    }
    satisfaction def ReanalyzeSatisfaction :> ShallReanalyzeAfterShock {
        subject aed : AutomatedExternalDefibrillator;
        requirement { the aed satisfies ShallReanalyzeAfterShock via controlProcessor.behavior postShock_to_analyze transition. }
    }
    satisfaction def BatterySatisfaction :> ShallReportBatteryStatus {
        subject battery : BatteryPack;
        requirement { the battery satisfies ShallReportBatteryStatus via reportStatus action. }
    }
}
