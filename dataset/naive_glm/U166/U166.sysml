package BiothesiometerSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    package Units {
        value def VibrationAmplitude :> Real { unit }
        unit def micrometer of VibrationAmplitude = 1 [um];
        unit def um = micrometer;

        value def VibrationFrequency :> Real { unit }
        unit def hertz of VibrationFrequency = 1 [Hz];
        unit def Hz = hertz;

        value def Voltage :> Real { unit }
        unit def volt of Voltage = 1 [V];
        unit def V = volt;

        value def Current :> Real { unit }
        unit def ampere of Current = 1 [A];
        unit def A = ampere;

        value def Duration :> Real {> TimeValue}
        unit def second of Duration = 1 [s];
        unit def s = second;

        value def NeuropathyScore :> Integer { unit }
        unit def score of NeuropathyScore = 1 [pt];
        unit def pt = score;

        value def AgeYears :> Integer { unit }
        unit def year of AgeYears = 1 [yr];
        unit def yr = year;

        value def TrialNumber :> Integer;
    }

    // ===== Item Types =====
    item def VibrationSignal {
        attribute amplitude : VibrationAmplitude[1] default 0 [um];
        attribute frequency : VibrationFrequency[1] default 120 [Hz];
    }

    item def ResponseSignal {
        attribute pressed : Boolean[1] default false;
        attribute timestamp : Duration[1];
    }

    item def TestResult {
        attribute threshold : VibrationAmplitude[1];
        attribute score : NeuropathyScore[1];
        attribute testLocation : String[1];
        attribute patientAge : AgeYears[1];
        attribute timestamp : String[1];
    }

    item def DisplayMessage {
        attribute text : String[1];
        attribute messageType : DisplayMessageType[1];
    }

    enum def DisplayMessageType {
        status
        result
        warning
        error
    }

    item def PowerStatus {
        attribute voltage : Voltage[1];
        attribute current : Current[1];
        attribute batteryLevel : Real[1] default 1.0;
    }

    // ===== Requirements =====
    requirement def FunctionalRequirement {
        doc << "Top-level functional requirement for the Biothesiometer system.">>
    }

    requirement def ThresholdMeasurementRequirement :> FunctionalRequirement {
        doc << "The system shall measure the vibration perception threshold by systematically increasing vibration amplitude until the patient responds.">>
        attribute fixedFrequency : VibrationFrequency[1] default 120 [Hz];
        attribute maxAmplitude : VibrationAmplitude[1] default 200 [um];
        attribute stepSize : VibrationAmplitude[1] default 5 [um];
        attribute trialDuration : Duration[1] default 3 [s];
        constraint { fixedFrequency == 120 [Hz] }
        constraint { maxAmplitude <= 200 [um] }
    }

    requirement def SafetyRequirement :> FunctionalRequirement {
        doc << "The system shall never exceed the maximum vibration amplitude of 200 micrometers.">>
        attribute maxSafeAmplitude : VibrationAmplitude[1] default 200 [um];
        constraint { maxSafeAmplitude == 200 [um] }
    }

    requirement def NeuropathyScoringRequirement :> FunctionalRequirement {
        doc << "The system shall calculate a neuropathy score based on the measured threshold compared against age-normal values.">>
        attribute minScore : NeuropathyScore[1] default 0 [pt];
        attribute maxScore : NeuropathyScore[1] default 100 [pt];
        constraint { minScore >= 0 [pt] and maxScore <= 100 [pt] }
    }

    requirement def DisplayRequirement :> FunctionalRequirement {
        doc << "The system shall display current test status and final results on the display panel.">>
    }

    requirement def ResponseButtonRequirement :> FunctionalRequirement {
        doc << "The system shall monitor the patient response button during each trial and register the first response.">>
        attribute responseTimeout : Duration[1] default 3 [s];
    }

    requirement BiothesiometerRequirements :> FunctionalRequirement {
        satisfy ThresholdMeasurementRequirement;
        satisfy SafetyRequirement;
        satisfy NeuropathyScoringRequirement;
        satisfy DisplayRequirement;
        satisfy ResponseButtonRequirement;
    }

    // ===== Port Definitions =====
    port def VibrationOutputPort {
        out vibration : VibrationSignal;
    }

    port def VibrationControlPort {
        in amplitudeCommand : VibrationAmplitude;
        in frequencyCommand : VibrationFrequency;
        out actualAmplitude : VibrationAmplitude;
        out actualFrequency : VibrationFrequency;
    }

    port def ResponseInputPort {
        in response : ResponseSignal;
    }

    port def DisplayPort {
        in message : DisplayMessage;
        in result : TestResult;
    }

    port def PowerPort {
        out power : PowerStatus;
    }

    port def ControlCommandPort {
        out startCommand : Boolean;
        out stopCommand : Boolean;
        out amplitudeStep : VibrationAmplitude;
        out frequencySet : VibrationFrequency;
        in trialComplete : Boolean;
        in responseReceived : Boolean;
        in currentAmplitude : VibrationAmplitude;
    }

    // ===== Part Definitions =====
    part def Biothesiometer {
        port controlUnitPort : VibrationControlPort;
        port responsePort : ResponseInputPort;
        port displayPort : DisplayPort;
        port powerPort : PowerPort;

        part controlUnit : ControlUnit {
            port probeConnection : VibrationControlPort;
            port buttonConnection : ResponseInputPort;
            port displayConnection : DisplayPort;
            port powerConnection : PowerPort;
        }

        part probe : Probe {
            port controlLink : VibrationControlPort;
            port skinContact : VibrationOutputPort;
        }

        part responseButton : ResponseButton {
            port output : ResponseInputPort;
        }

        part displayPanel : DisplayPanel {
            port input : DisplayPort;
        }

        part powerSupply : PowerSupply {
            port output : PowerPort;
        }

        connection controlToProbe connect controlUnit.probeConnection to probe.controlLink;
        connection buttonToControl connect responseButton.output to controlUnit.buttonConnection;
        connection controlToDisplay connect controlUnit.displayConnection to displayPanel.input;
        connection powerToControl connect powerSupply.output to controlUnit.powerConnection;
    }

    part def ControlUnit {
        port probeConnection : VibrationControlPort;
        port buttonConnection : ResponseInputPort;
        port displayConnection : DisplayPort;
        port powerConnection : PowerPort;

        part controlModule : ControlModule {
            port vibrationControl : ControlCommandPort;
            port responseInput : ResponseInputPort;
            port displayOutput : DisplayPort;
            port powerInput : PowerPort;
        }

        part vibrationGenerator : VibrationGenerator {
            port controlInput : ControlCommandPort;
            port vibrationOutput : VibrationControlPort;
        }

        part signalProcessor : SignalProcessor {
            port responseIn : ResponseInputPort;
            port processedResponseOut : ResponseInputPort;
        }

        part powerRegulator : PowerRegulator {
            port powerIn : PowerPort;
            port powerOut : PowerPort;
        }

        connection controlToGenerator connect controlModule.vibrationControl to vibrationGenerator.controlInput;
        connection generatorToProbe connect vibrationGenerator.vibrationOutput to probeConnection;
        connection buttonToProcessor connect buttonConnection to signalProcessor.responseIn;
        connection processorToControl connect signalProcessor.processedResponseOut to controlModule.responseInput;
        connection powerToRegulator connect powerConnection to powerRegulator.powerIn;
        connection regulatorToControl connect powerRegulator.powerOut to controlModule.powerInput;
        connection controlToDisplayLink connect controlModule.displayOutput to displayConnection;
    }

    part def ControlModule {
        attribute maxAmplitude : VibrationAmplitude[1] default 200 [um];
        attribute stepSize : VibrationAmplitude[1] default 5 [um];
        attribute fixedFrequency : VibrationFrequency[1] default 120 [Hz];
        attribute trialDuration : Duration[1] default 3 [s];
        attribute currentTrial : TrialNumber[1] default 0;
        attribute currentAmplitude : VibrationAmplitude[1] default 0 [um];
        attribute measuredThreshold : VibrationAmplitude[1] default 0 [um];
        attribute patientAge : AgeYears[1] default 50 [yr];
        attribute testLocation : String[1] default "big_toe";
        attribute responseDetected : Boolean[1] default false;
        attribute testComplete : Boolean[1] default false;
        attribute calculatedScore : NeuropathyScore[1] default 0 [pt];

        port vibrationControl : ControlCommandPort;
        port responseInput : ResponseInputPort;
        port displayOutput : DisplayPort;
        port powerInput : PowerPort;

        // Normal threshold lookup table by age (simplified)
        item normalThresholds : VibrationAmplitude[*] ordered = (5 [um], 8 [um], 12 [um], 18 [um], 25 [um], 35 [um]);

        action def RunThresholdTest {
            in maxAmp : VibrationAmplitude[1];
            in step : VibrationAmplitude[1];
            in freq : VibrationFrequency[1];
            in trialDur : Duration[1];
            out threshold : VibrationAmplitude[1];
            out score : NeuropathyScore[1];

            action initializeTest {
                assign threshold = 0 [um];
            }

            action executeTrials {
                while (threshold == 0 [um] and currentAmplitude < maxAmp) {
                    action startTrial {
                        // Send amplitude command to vibration generator
                        send amplitudeStep(currentAmplitude) via vibrationControl;
                        send frequencySet(freq) via vibrationControl;
                        send startCommand(true) via vibrationControl;
                    }

                    action waitForResponse {
                        // Wait for trial duration or response
                        if (responseInput.response.pressed == true) {
                            assign threshold = currentAmplitude;
                            assign responseDetected = true;
                        }
                    }

                    action endTrial {
                        send stopCommand(true) via vibrationControl;
                        assign currentTrial = currentTrial + 1;
                        assign currentAmplitude = currentAmplitude + step;
                    }
                }
            }

            action calculateScore {
                // Compare threshold against age-normal values
                // Higher threshold = worse neuropathy = higher score
                attribute normalThreshold : VibrationAmplitude[1];
                attribute ratio : Real[1];

                if (patientAge < 30 [yr]) {
                    assign normalThreshold = normalThresholds[1];
                } else if (patientAge < 40 [yr]) {
                    assign normalThreshold = normalThresholds[2];
                } else if (patientAge < 50 [yr]) {
                    assign normalThreshold = normalThresholds[3];
                } else if (patientAge < 60 [yr]) {
                    assign normalThreshold = normalThresholds[4];
                } else if (patientAge < 70 [yr]) {
                    assign normalThreshold = normalThresholds[5];
                } else {
                    assign normalThreshold = normalThresholds[6];
                }

                if (threshold == 0 [um]) {
                    // No response at max amplitude - severe neuropathy
                    assign score = 100 [pt];
                } else {
                    assign ratio = threshold / normalThreshold;
                    if (ratio <= 1.0) {
                        assign score = 0 [pt];
                    } else if (ratio <= 2.0) {
                        assign score = 25 [pt];
                    } else if (ratio <= 3.0) {
                        assign score = 50 [pt];
                    } else if (ratio <= 4.0) {
                        assign score = 75 [pt];
                    } else {
                        assign score = 100 [pt];
                    }
                }
            }

            action displayResults {
                attribute result : TestResult;
                assign result.threshold = threshold;
                assign result.score = score;
                assign result.testLocation = testLocation;
                assign result.patientAge = patientAge;
                send result(result) via displayOutput;
            }

            flow from initializeTest to executeTrials;
            flow from executeTrials to calculateScore;
            flow from calculateScore to displayResults;
        }

        state def ControlModuleStateMachine {
            entry action { send message(DisplayMessage{text="System Ready", messageType=status}) via displayOutput; }

            state idle {
                entry action { assign currentAmplitude = 0 [um]; assign currentTrial = 0; assign responseDetected = false; assign testComplete = false; }
                transition to running when (powerInput.power.batteryLevel > 0.1);
            }

            state running {
                entry action {
                    assign currentAmplitude = stepSize;
                    assign currentTrial = 1;
                    assign responseDetected = false;
                    assign testComplete = false;
                    send message(DisplayMessage{text="Test Started", messageType=status}) via displayOutput;
                }

                do action RunThresholdTest {
                    in maxAmp = maxAmplitude;
                    in step = stepSize;
                    in freq = fixedFrequency;
                    in trialDur = trialDuration;
                    out threshold = measuredThreshold;
                    out score = calculatedScore;
                }

                transition to results when (testComplete == true);
            }

            state results {
                entry action {
                    send message(DisplayMessage{text="Threshold: " + measuredThreshold, messageType=result}) via displayOutput;
                    send message(DisplayMessage{text="Neuropathy Score: " + calculatedScore, messageType=result}) via displayOutput;
                }
                transition to idle when (true);
            }

            state errorState {
                entry action { send message(DisplayMessage{text="Error: Amplitude exceeded safe limit", messageType=error}) via displayOutput; }
                transition to idle when (true);
            }

            transition from idle to errorState when (currentAmplitude > maxAmplitude);
            transition from running to errorState when (currentAmplitude > maxAmplitude);
        }

        exhibit state ControlModuleStateMachine;

        satisfy ThresholdMeasurementRequirement;
        satisfy NeuropathyScoringRequirement;
        satisfy DisplayRequirement;
    }

    part def VibrationGenerator {
        attribute currentAmplitude : VibrationAmplitude[1] default 0 [um];
        attribute currentFrequency : VibrationFrequency[1] default 120 [Hz];
        attribute maxSafeAmplitude : VibrationAmplitude[1] default 200 [um];
        attribute isGenerating : Boolean[1] default false;

        port controlInput : ControlCommandPort;
        port vibrationOutput : VibrationControlPort;

        action def GenerateVibration {
            in targetAmplitude : VibrationAmplitude[1];
            in targetFrequency : VibrationFrequency[1];
            in generate : Boolean[1];

            action validateAmplitude {
                if (targetAmplitude > maxSafeAmplitude) {
                    // Safety limit enforcement
                    assign currentAmplitude = maxSafeAmplitude;
                } else {
                    assign currentAmplitude = targetAmplitude;
                }
            }

            action setFrequency {
                assign currentFrequency = targetFrequency;
            }

            action activate {
                if (generate == true) {
                    assign isGenerating = true;
                    send actualAmplitude(currentAmplitude) via vibrationOutput;
                    send actualFrequency(currentFrequency) via vibrationOutput;
                } else {
                    assign isGenerating = false;
                    assign currentAmplitude = 0 [um];
                    send actualAmplitude(0 [um]) via vibrationOutput;
                }
            }

            flow from validateAmplitude to setFrequency;
            flow from setFrequency to activate;
        }

        state def GeneratorStateMachine {
            state off {
                entry action { assign isGenerating = false; assign currentAmplitude = 0 [um]; }
                transition to on when (controlInput.startCommand == true);
            }

            state on {
                do action GenerateVibration {
                    in targetAmplitude = controlInput.amplitudeStep;
                    in targetFrequency = controlInput.frequencySet;
                    in generate = controlInput.startCommand;
                }
                transition to off when (controlInput.stopCommand == true);
            }

            transition from on to off when (currentAmplitude > maxSafeAmplitude);
        }

        exhibit state GeneratorStateMachine;

        satisfy SafetyRequirement;
    }

    part def SignalProcessor {
        attribute lastResponseTime : Duration[1] default 0 [s];
        attribute responseValid : Boolean[1] default false;

        port responseIn : ResponseInputPort;
        port processedResponseOut : ResponseInputPort;

        action def ProcessResponse {
            in rawResponse : ResponseSignal[1];
            out processedResponse : ResponseSignal[1];

            action validateResponse {
                if (rawResponse.pressed == true) {
                    assign responseValid = true;
                    assign lastResponseTime = rawResponse.timestamp;
                }
            }

            action forwardResponse {
                if (responseValid == true) {
                    send response(rawResponse) via processedResponseOut;
                }
            }

            flow from validateResponse to forwardResponse;
        }

        satisfy ResponseButtonRequirement;
    }

    part def PowerRegulator {
        attribute regulatedVoltage : Voltage[1] default 5 [V];
        attribute maxCurrent : Current[1] default 2 [A];
        attribute efficiency : Real[1] default 0.95;

        port powerIn : PowerPort;
        port powerOut : PowerPort;

        action def RegulatePower {
            in inputPower : PowerStatus[1];
            out outputPower : PowerStatus[1];

            action regulate {
                attribute adjustedVoltage : Voltage[1];
                assign adjustedVoltage = regulatedVoltage;
                assign outputPower.voltage = adjustedVoltage;
                assign outputPower.current = inputPower.current * efficiency;
                assign outputPower.batteryLevel = inputPower.batteryLevel;
            }
        }
    }

    part def Probe {
        attribute tipDiameter : VibrationAmplitude[1] default 13 [um];
        attribute isContactDetected : Boolean[1] default false;

        port controlLink : VibrationControlPort;
        port skinContact : VibrationOutputPort;

        part vibratingTip : VibratingTip {
            port vibrationIn : VibrationControlPort;
            port contactOut : VibrationOutputPort;
        }

        part probeBody : ProbeBody {
            attribute material : String[1] default "medical_grade_steel";
            attribute length : VibrationAmplitude[1] default 150000 [um];
        }

        part probeCable : ProbeCable {
            attribute cableLength : VibrationAmplitude[1] default 1000000 [um];
            attribute connectorType : String[1] default "shielded_BNC";
        }

        connection tipToBody connect vibratingTip to probeBody;
        connection bodyToCable connect probeBody to probeCable;
        connection cableToControl connect probeCable to controlLink;
        connection tipToContact connect vibratingTip.contactOut to skinContact;
    }

    part def VibratingTip {
        attribute currentVibration : VibrationSignal[1];

        port vibrationIn : VibrationControlPort;
        port contactOut : VibrationOutputPort;

        action def TransmitVibration {
            in amplitude : VibrationAmplitude[1];
            in frequency : VibrationFrequency[1];
            out vibration : VibrationSignal[1];

            action generateSignal {
                assign currentVibration.amplitude = amplitude;
                assign currentVibration.frequency = frequency;
            }

            action transmitToSkin {
                send vibration(currentVibration) via contactOut;
            }

            flow from generateSignal to transmitToSkin;
        }
    }

    part def ProbeBody {
        attribute material : String[1] default "medical_grade_steel";
        attribute length : VibrationAmplitude[1] default 150000 [um];
        attribute weight : Real[1] default 0.15;
    }

    part def ProbeCable {
        attribute cableLength : VibrationAmplitude[1] default 1000000 [um];
        attribute connectorType : String[1] default "shielded_BNC";
        attribute shielding : Boolean[1] default true;
    }

    part def ResponseButton {
        attribute isPressed : Boolean[1] default false;
        attribute debounceTime : Duration[1] default 0.05 [s];
        attribute pressCount : Integer[1] default 0;

        port output : ResponseInputPort;

        part buttonSwitch : ButtonSwitch {
            attribute contactState : Boolean[1] default false;
        }

        part debounceCircuit : DebounceCircuit {
            attribute delayTime : Duration[1] default 0.05 [s];
        }

        action def HandlePress {
            in physicalPress : Boolean[1];
            out responseSignal : ResponseSignal[1];

            action debounce {
                if (physicalPress == true) {
                    assign isPressed = true;
                    assign pressCount = pressCount + 1;
                }
            }

            action generateResponse {
                if (isPressed == true) {
                    attribute sig : ResponseSignal;
                    assign sig.pressed = true;
                    assign sig.timestamp = 0 [s];
                    send response(sig) via output;
                    assign isPressed = false;
                }
            }

            flow from debounce to generateResponse;
        }

        satisfy ResponseButtonRequirement;
    }

    part def ButtonSwitch {
        attribute contactState : Boolean[1] default false;
        attribute actuationForce : Real[1] default 2.0;
    }

    part def DebounceCircuit {
        attribute delayTime : Duration[1] default 0.05 [s];
        attribute stableState : Boolean[1] default false;
    }

    part def DisplayPanel {
        attribute width : VibrationAmplitude[1] default 80000 [um];
        attribute height : VibrationAmplitude[1] default 48000 [um];
        attribute backlightEnabled : Boolean[1] default true;
        attribute currentMessage : DisplayMessage[1];
        attribute currentResult : TestResult[1];

        port input : DisplayPort;

        part screen : Screen {
            attribute resolution : String[1] default "800x480";
            attribute type : String[1] default "LCD";
        }

        part displayController : DisplayController {
            attribute refreshRate : VibrationFrequency[1] default 60 [Hz];
        }

        action def UpdateDisplay {
            in message : DisplayMessage[1];
            in result : TestResult[0..1];

            action renderMessage {
                assign currentMessage = message;
            }

            action renderResult {
                if (result.size > 0) {
                    assign currentResult = result;
                }
            }

            action refreshScreen {
                // Drive the screen with current content
                assign backlightEnabled = true;
            }

            flow from renderMessage to renderResult;
            flow from renderResult to refreshScreen;
        }

        satisfy DisplayRequirement;
    }

    part def Screen {
        attribute resolution : String[1] default "800x480";
        attribute type : String[1] default "LCD";
        attribute brightness : Real[1] default 0.8;
    }

    part def DisplayController {
        attribute refreshRate : VibrationFrequency[1] default 60 [Hz];
        attribute buffer : DisplayMessage[*];
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage[1] default 12 [V];
        attribute capacity : Real[1] default 2.5;
        attribute batteryLevel : Real[1] default 1.0;
        attribute isCharging : Boolean[1] default false;

        port output : PowerPort;

        part battery : Battery {
            attribute chemistry : String[1] default "Li-ion";
            attribute cellCount : Integer[1] default 4;
            attribute nominalCellVoltage : Voltage[1] default 3.7 [V];
        }

        part chargingCircuit : ChargingCircuit {
            attribute inputVoltage : Voltage[1] default 5 [V];
            attribute chargeCurrent : Current[1] default 1.5 [A];
        }

        action def SupplyPower {
            out power : PowerStatus[1];

            action checkBattery {
                if (batteryLevel < 0.1) {
                    assign isCharging = true;
                }
            }

            action generateOutput {
                assign power.voltage = nominalVoltage;
                assign power.current = 1 [A];
                assign power.batteryLevel = batteryLevel;
                send power(power) via output;
            }

            flow from checkBattery to generateOutput;
        }
    }

    part def Battery {
        attribute chemistry : String[1] default "Li-ion";
        attribute cellCount : Integer[1] default 4;
        attribute nominalCellVoltage : Voltage[1] default 3.7 [V];
        attribute totalVoltage : Voltage[1] default 14.8 [V];
        attribute capacity : Real[1] default 2.5;
    }

    part def ChargingCircuit {
        attribute inputVoltage : Voltage[1] default 5 [V];
        attribute chargeCurrent : Current[1] default 1.5 [A];
        attribute overvoltageProtection : Boolean[1] default true;
    }

    // ===== Top-level System Instantiation =====
    part biothesiometerDevice : Biothesiometer {
        satisfy BiothesiometerRequirements;

        part controlUnit : ControlUnit {
            part controlModule : ControlModule {
                attribute patientAge : AgeYears[1] default 55 [yr];
                attribute testLocation : String[1] default "right_big_toe";
            }
        }

        part probe : Probe {
            part vibratingTip : VibratingTip;
        }

        part responseButton : ResponseButton;
        part displayPanel : DisplayPanel;
        part powerSupply : PowerSupply {
            attribute batteryLevel : Real[1] default 0.85;
        }
    }
}
