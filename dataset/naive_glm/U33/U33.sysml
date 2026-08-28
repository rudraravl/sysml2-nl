package AdaptiveDBS {

    import ScalarValues::*;

    // ===== Units =====
    unit def milliampere;
    unit def microampere;
    unit def millivolt;
    unit def volt;
    unit def microvolt;
    unit def hertz;
    unit def megahertz;
    unit def millisecond;
    unit def microsecond;
    unit def second;
    unit def year;
    unit def watt;
    unit def percent;
    unit def ohm;
    unit def meter;

    // ===== Value Types =====
    value def ElectricCurrent :> Real { unit milliampere; }
    value def ElectricPotential :> Real { unit volt; }
    value def SignalPotential :> Real { unit microvolt; }
    value def PulseFrequency :> Real { unit hertz; }
    value def CarrierFrequency :> Real { unit megahertz; }
    value def PulseDuration :> Real { unit microsecond; }
    value def Power :> Real { unit watt; }
    value def TimeValue :> Real { unit second; }
    value def Latency :> Real { unit millisecond; }
    value def BatteryLevel :> Real { unit percent; }
    value def Impedance :> Real { unit ohm; }
    value def Distance :> Real { unit meter; }
    value def OperationalLife :> Real { unit year; }
    value def BiomarkerLevel :> Real;
    value def TherapeuticThreshold :> Real;
    value def Gain :> Real;
    value def ChargeDensity :> Real;

    // ===== Items =====
    item def NeuralSignal {
        attribute amplitude : SignalPotential;
        attribute sampleRate : PulseFrequency;
        attribute timestamp : TimeValue;
        attribute channel : Integer;
    }

    item def BiomarkerData {
        attribute betaBandPower : BiomarkerLevel;
        attribute thetaBandPower : BiomarkerLevel;
        attribute severityIndex : BiomarkerLevel;
        attribute confidence : BiomarkerLevel;
        attribute timestamp : TimeValue;
    }

    item def StimulationCommand {
        attribute current : ElectricCurrent;
        attribute frequency : PulseFrequency;
        attribute pulseWidth : PulseDuration;
        attribute active : Boolean;
        attribute rampDuration : Latency;
    }

    item def ElectricalPulse {
        attribute current : ElectricCurrent;
        attribute frequency : PulseFrequency;
        attribute pulseWidth : PulseDuration;
        attribute amplitude : ElectricPotential;
    }

    item def TherapyParameters {
        attribute detectionThreshold : TherapeuticThreshold;
        attribute suppressionThreshold : TherapeuticThreshold;
        attribute maxCurrent : ElectricCurrent;
        attribute minCurrent : ElectricCurrent;
        attribute baseFrequency : PulseFrequency;
        attribute pulseWidth : PulseDuration;
        attribute adaptationGain : Gain;
    }

    item def TelemetryData {
        attribute batteryLevel : BatteryLevel;
        attribute biomarkerHistory : BiomarkerData[0..*];
        attribute stimulationHistory : StimulationCommand[0..*];
        attribute deviceStatus : String;
        attribute timestamp : TimeValue;
    }

    item def ProgrammerCommand {
        attribute updatedParameters : TherapyParameters;
        attribute diagnosticRequest : Boolean;
        attribute suspendTherapy : Boolean;
        attribute requestDiagnostics : Boolean;
    }

    item def BatteryStatus {
        attribute chargeLevel : BatteryLevel;
        attribute voltage : ElectricPotential;
        attribute health : String;
        attribute charging : Boolean;
    }

    // ===== Ports =====
    port def NeuralSignalPort {
        out signal : NeuralSignal;
    }

    port def BiomarkerPort {
        out data : BiomarkerData;
    }

    port def CommandPort {
        out command : StimulationCommand;
    }

    port def PulsePort {
        out pulse : ElectricalPulse;
    }

    port def PowerPort {
        out supply : Power;
    }

    port def BatteryStatusPort {
        out status : BatteryStatus;
    }

    port def TelemetryPort {
        out downlink : TelemetryData;
        in uplink : ProgrammerCommand;
    }

    // ===== Component Definitions =====

    part def SensingElectrode {
        port neuralOut : NeuralSignalPort;
        port powerIn : ~PowerPort;

        attribute targetRegion : String;
        attribute channelCount : Integer;
        attribute contactGeometry : String;
        attribute electrodeImpedance : Impedance;

        action def AcquireNeuralSignal {
            in region : String;
            in channelCount : Integer;
            out signal : NeuralSignal;
        }

        perform AcquireNeuralSignal;
    }

    part def BiomarkerExtractor {
        port neuralIn : ~NeuralSignalPort;
        port biomarkerOut : BiomarkerPort;
        port powerIn : ~PowerPort;

        attribute samplingRate : PulseFrequency = 1000 [hertz];
        attribute betaLowCutoff : PulseFrequency = 13 [hertz];
        attribute betaHighCutoff : PulseFrequency = 30 [hertz];
        attribute thetaLowCutoff : PulseFrequency = 4 [hertz];
        attribute thetaHighCutoff : PulseFrequency = 8 [hertz];
        attribute processingLatency : Latency;

        action def BandpassFilter {
            in rawSignal : NeuralSignal;
            in lowCutoff : PulseFrequency;
            in highCutoff : PulseFrequency;
            out filteredSignal : NeuralSignal;
        }

        action def ComputePowerSpectralDensity {
            in signal : NeuralSignal;
            out power : BiomarkerLevel;
        }

        action def ProcessSignal {
            in rawSignal : NeuralSignal;
            out biomarkers : BiomarkerData;

            action filterBeta : BandpassFilter {
                in rawSignal = rawSignal;
                in lowCutoff = betaLowCutoff;
                in highCutoff = betaHighCutoff;
                out filteredSignal;
            }

            action filterTheta : BandpassFilter {
                in rawSignal = rawSignal;
                in lowCutoff = thetaLowCutoff;
                in highCutoff = thetaHighCutoff;
                out filteredSignal;
            }

            action computeBetaPower : ComputePowerSpectralDensity {
                in signal from filterBeta.filteredSignal;
                out power;
            }

            action computeThetaPower : ComputePowerSpectralDensity {
                in signal from filterTheta.filteredSignal;
                out power;
            }

            action assembleBiomarkers {
                in betaPower from computeBetaPower.power;
                in thetaPower from computeThetaPower.power;
                out biomarkers;
            }

            flow from assembleBiomarkers.biomarkers to biomarkers;
        }

        perform ProcessSignal;
    }

    part def ClosedLoopController {
        port biomarkerIn : ~BiomarkerPort;
        port commandOut : CommandPort;
        port telemetry : TelemetryPort;
        port batteryStatusIn : ~BatteryStatusPort;
        port powerIn : ~PowerPort;

        attribute therapyParameters : TherapyParameters;
        attribute currentCommand : StimulationCommand;
        attribute adaptationEnabled : Boolean = true;
        attribute evaluationLatency : Latency;

        action def EvaluateBiomarkers {
            in biomarkers : BiomarkerData;
            in detectionThreshold : TherapeuticThreshold;
            in suppressionThreshold : TherapeuticThreshold;
            out pathologyDetected : Boolean;
            out severity : BiomarkerLevel;
        }

        action def ComputeStimulation {
            in severity : BiomarkerLevel;
            in parameters : TherapyParameters;
            out command : StimulationCommand;
        }

        action def AssembleTelemetry {
            in biomarkers : BiomarkerData;
            in command : StimulationCommand;
            in batteryStatus : BatteryStatus;
            out telemetryData : TelemetryData;
        }

        state def ControlLoop {
            entry; then Idle;

            state Idle {
                doc /* Therapy suspended; monitoring only. */
                entry;
            }

            transition from Idle to Monitoring
                when telemetry.uplink.suspendTherapy == false;

            state Monitoring {
                doc /* Continuously receiving and evaluating biomarker data. */
                entry;
            }

            transition from Monitoring to Evaluating
                when biomarkerIn.data.severityIndex > therapyParameters.detectionThreshold;

            state Evaluating {
                doc /* Assessing pathology severity against therapeutic thresholds. */
                entry;
            }

            transition from Evaluating to Stimulating
                when biomarkerIn.data.severityIndex >= therapyParameters.suppressionThreshold;

            transition from Evaluating to Monitoring
                when biomarkerIn.data.severityIndex < therapyParameters.suppressionThreshold;

            state Stimulating {
                doc /* Generating and issuing stimulation commands. */
                entry;
            }

            transition from Stimulating to Monitoring
                when biomarkerIn.data.severityIndex < therapyParameters.detectionThreshold;

            transition from Monitoring to Idle
                when telemetry.uplink.suspendTherapy == true;

            transition from Stimulating to Idle
                when telemetry.uplink.suspendTherapy == true;

            transition from Evaluating to Idle
                when telemetry.uplink.suspendTherapy == true;
        }

        perform ControlLoop;
    }

    part def PulseGenerator {
        port commandIn : ~CommandPort;
        port pulseOut : PulsePort;
        port powerIn : ~PowerPort;

        attribute outputImpedance : Impedance;
        attribute maxOutputCurrent : ElectricCurrent;
        attribute complianceVoltage : ElectricPotential;
        attribute pulseGenerationLatency : Latency;

        action def GeneratePulse {
            in command : StimulationCommand;
            in complianceVoltage : ElectricPotential;
            out pulse : ElectricalPulse;
        }

        action def RampCurrent {
            in targetCurrent : ElectricCurrent;
            in rampDuration : Latency;
            out rampedCurrent : ElectricCurrent;
        }

        perform GeneratePulse;
    }

    part def StimulationElectrode {
        port pulseIn : ~PulsePort;
        port powerIn : ~PowerPort;

        attribute targetRegion : String;
        attribute contactCount : Integer;
        attribute contactConfiguration : String;
        attribute electrodeImpedance : Impedance;
        attribute surfaceArea : Real;
    }

    part def ImplantableBattery {
        port powerOut : PowerPort;
        port statusOut : BatteryStatusPort;
        port telemetry : TelemetryPort;

        attribute chargeLevel : BatteryLevel;
        attribute capacity : ElectricCurrent;
        attribute rechargeable : Boolean = true;
        attribute chargeCycles : Integer;
        attribute nominalVoltage : ElectricPotential;
        attribute maxChargeCycles : Integer;

        action def SupplyPower {
            out supply : Power;
        }

        action def MonitorCharge {
            out level : BatteryLevel;
            out voltage : ElectricPotential;
        }

        state def BatteryStateMachine {
            entry; then FullyCharged;

            state FullyCharged {
                entry;
            }

            transition from FullyCharged to Normal
                when chargeLevel < 90;

            state Normal {
                entry;
            }

            transition from Normal to Low
                when chargeLevel < 20;

            state Low {
                doc /* Low battery alert transmitted via telemetry. */
                entry;
            }

            transition from Low to Critical
                when chargeLevel < 5;

            state Critical {
                doc /* Reduce or suspend stimulation to preserve safety margin. */
                entry;
            }

            transition from Critical to Charging
                when telemetry.uplink.diagnosticRequest == true;

            transition from Low to Charging
                when telemetry.uplink.diagnosticRequest == true;

            transition from Normal to Charging
                when telemetry.uplink.diagnosticRequest == true;

            state Charging {
                doc /* Inductive charging from external charger. */
                entry;
            }

            transition from Charging to FullyCharged
                when chargeLevel >= 100;
        }

        perform BatteryStateMachine;
    }

    part def WirelessTelemetry {
        port controllerLink : ~TelemetryPort;
        port powerIn : ~PowerPort;

        attribute carrierFrequency : CarrierFrequency;
        attribute communicationRange : Distance;
        attribute protocol : String;
        attribute encryptionEnabled : Boolean = true;
        attribute dataRate : PulseFrequency;

        action def TransmitData {
            in data : TelemetryData;
            in carrierFrequency : CarrierFrequency;
        }

        action def ReceiveCommand {
            out command : ProgrammerCommand;
        }

        action def EncryptPayload {
            in plaintext : TelemetryData;
            out ciphertext : TelemetryData;
        }

        perform TransmitData;
        perform ReceiveCommand;
    }

    // ===== Requirements =====

    requirement def AdaptiveTherapyRequirement {
        doc /* The system shall continuously monitor neural activity and adaptively adjust stimulation parameters in real-time to suppress pathological biomarkers. */
        subject system : AdaptiveDBSSystem;
        attribute maxResponseLatency : Latency = 50 [millisecond];
        attribute adaptationEnabled : Boolean = true;
    }

    requirement def BiomarkerDetectionRequirement {
        doc /* The biomarker extractor shall isolate and quantify pathological neural biomarkers within the specified latency and sensitivity. */
        subject extractor : BiomarkerExtractor;
        attribute maxDetectionLatency : Latency = 10 [millisecond];
        attribute minDetectionSensitivity : BiomarkerLevel = 0.85;
        attribute betaBandRange : String = "13-30 Hz";
    }

    requirement def BatteryLifeRequirement {
        doc /* The implantable battery shall support adaptive stimulation operation for at least the minimum operational life before requiring recharge. */
        subject battery : ImplantableBattery;
        attribute minOperationalLife : OperationalLife = 5 [year];
        attribute minCapacity : ElectricCurrent = 500 [milliampere];
        attribute rechargeable : Boolean = true;
    }

    requirement def SafetyRequirement {
        doc /* Stimulation current and charge density shall not exceed maximum safe limits to prevent tissue damage. */
        subject system : AdaptiveDBSSystem;
        attribute maxSafeCurrent : ElectricCurrent = 25 [milliampere];
        attribute maxChargeDensity : ChargeDensity = 30;
    }

    requirement def TelemetryRequirement {
        doc /* The wireless telemetry unit shall support secure two-way communication with an external programmer for monitoring and parameter adjustment. */
        subject telemetry : WirelessTelemetry;
        attribute minRange : Distance = 2 [meter];
        attribute encryptionRequired : Boolean = true;
        attribute carrierBand : String = "MICS 402-405 MHz";
    }

    requirement def ClosedLoopRequirement {
        doc /* The system shall operate in a continuous sense-analyze-treat cycle, delivering therapy only when and to the degree pathological activity is detected. */
        subject system : AdaptiveDBSSystem;
    }

    requirement def PersonalizationRequirement {
        doc /* The system shall allow clinicians to non-invasively fine-tune therapeutic thresholds and stimulation parameters via the external programmer. */
        subject system : AdaptiveDBSSystem;
        attribute programmableParameters : Boolean = true;
    }

    // ===== System Definition =====

    part def AdaptiveDBSSystem {
        doc /* Adaptive Deep Brain Stimulation system: an intelligent, implantable closed-loop medical device for treating neurological and neuropsychiatric conditions. */

        part sensingElectrode : SensingElectrode {
            attribute targetRegion = "STN";
            attribute channelCount = 8;
            attribute contactGeometry = "laminar";
            attribute electrodeImpedance = 1000 [ohm];
        }

        part biomarkerExtractor : BiomarkerExtractor {
            attribute processingLatency = 8 [millisecond];
        }

        part controller : ClosedLoopController {
            attribute therapyParameters : TherapyParameters = {
                attribute detectionThreshold = 0.4;
                attribute suppressionThreshold = 0.6;
                attribute maxCurrent = 10 [milliampere];
                attribute minCurrent = 0 [milliampere];
                attribute baseFrequency = 130 [hertz];
                attribute pulseWidth = 60 [microsecond];
                attribute adaptationGain = 0.5;
            };
            attribute evaluationLatency = 5 [millisecond];
        }

        part pulseGenerator : PulseGenerator {
            attribute outputImpedance = 500 [ohm];
            attribute maxOutputCurrent = 25 [milliampere];
            attribute complianceVoltage = 10 [volt];
            attribute pulseGenerationLatency = 2 [millisecond];
        }

        part stimulationElectrode : StimulationElectrode {
            attribute targetRegion = "STN";
            attribute contactCount = 4;
            attribute contactConfiguration = "bipolar";
            attribute electrodeImpedance = 800 [ohm];
        }

        part battery : ImplantableBattery {
            attribute chargeLevel = 100 [percent];
            attribute capacity = 500 [milliampere];
            attribute nominalVoltage = 3.2 [volt];
            attribute chargeCycles = 0;
            attribute maxChargeCycles = 2000;
        }

        part telemetry : WirelessTelemetry {
            attribute carrierFrequency = 402 [megahertz];
            attribute communicationRange = 2 [meter];
            attribute protocol = "MICS";
            attribute dataRate = 500 [hertz];
        }

        // --- Signal flow connections ---
        connection neuralSignalFlow connect
            sensingElectrode.neuralOut to biomarkerExtractor.neuralIn;

        connection biomarkerFlow connect
            biomarkerExtractor.biomarkerOut to controller.biomarkerIn;

        connection commandFlow connect
            controller.commandOut to pulseGenerator.commandIn;

        connection pulseDelivery connect
            pulseGenerator.pulseOut to stimulationElectrode.pulseIn;

        // --- Telemetry connections ---
        connection controllerTelemetryLink connect
            controller.telemetry to telemetry.controllerLink;

        // --- Battery status connection ---
        connection batteryStatusFlow connect
            battery.statusOut to controller.batteryStatusIn;

        // --- Power distribution ---
        connection powerToSensing connect
            battery.powerOut to sensingElectrode.powerIn;

        connection powerToExtractor connect
            battery.powerOut to biomarkerExtractor.powerIn;

        connection powerToController connect
            battery.powerOut to controller.powerIn;

        connection powerToPulseGen connect
            battery.powerOut to pulseGenerator.powerIn;

        connection powerToStimElectrode connect
            battery.powerOut to stimulationElectrode.powerIn;

        connection powerToTelemetry connect
            battery.powerOut to telemetry.powerIn;

        // --- System-level behavior ---
        action def SenseAnalyzeTreatCycle {
            doc /* Continuous closed-loop cycle: sense neural activity, analyze biomarkers, decide therapy, generate pulse, repeat. */

            in neuralInput : NeuralSignal;
            out stimulationOutput : ElectricalPulse;

            action sense {
                doc /* Acquire raw neural signal from sensing electrode. */
                in region : String;
                out signal : NeuralSignal;
            }

            action analyze {
                doc /* Filter and extract biomarker features from neural signal. */
                in signal : NeuralSignal;
                out biomarkers : BiomarkerData;
            }

            action evaluate {
                doc /* Compare biomarkers against therapeutic thresholds. */
                in biomarkers : BiomarkerData;
                in detectionThreshold : TherapeuticThreshold;
                in suppressionThreshold : TherapeuticThreshold;
                out pathologyDetected : Boolean;
                out severity : BiomarkerLevel;
            }

            action compute {
                doc /* Calculate optimal stimulation parameters based on severity. */
                in severity : BiomarkerLevel;
                in pathologyDetected : Boolean;
                in parameters : TherapyParameters;
                out command : StimulationCommand;
            }

            action generate {
                doc /* Generate electrical pulse from stimulation command. */
                in command : StimulationCommand;
                out pulse : ElectricalPulse;
            }

            flow from sense.signal to analyze.signal;
            flow from analyze.biomarkers to evaluate.biomarkers;
            flow from evaluate.pathologyDetected to compute.pathologyDetected;
            flow from evaluate.severity to compute.severity;
            flow from compute.command to generate.command;
            flow from generate.pulse to stimulationOutput;

            then sense;
        }

        perform SenseAnalyzeTreatCycle;

        // --- Requirement satisfactions ---
        requirement adaptiveTherapyReq : AdaptiveTherapyRequirement {
            subject system = self;
        }

        requirement closedLoopReq : ClosedLoopRequirement {
            subject system = self;
        }

        requirement safetyReq : SafetyRequirement {
            subject system = self;
        }

        requirement personalizationReq : PersonalizationRequirement {
            subject system = self;
        }

        requirement biomarkerReq : BiomarkerDetectionRequirement {
            subject extractor = biomarkerExtractor;
        }

        requirement batteryReq : BatteryLifeRequirement {
            subject battery = battery;
        }

        requirement telemetryReq : TelemetryRequirement {
            subject telemetry = telemetry;
        }

        satisfy adaptiveTherapyReq by self;
        satisfy closedLoopReq by self;
        satisfy safetyReq by self;
        satisfy personalizationReq by self;
        satisfy biomarkerReq by biomarkerExtractor;
        satisfy batteryReq by battery;
        satisfy telemetryReq by telemetry;
    }

}
