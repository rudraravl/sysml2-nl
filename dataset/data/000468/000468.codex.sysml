package MatibabuSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent : Real;
    attribute def ConfidenceScore : Real;
    attribute def ParasiteDensityEstimate : Real {
        unit = "parasites/uL";
    }
    attribute def Wavelength_nm : Real {
        unit = "nm";
    }
    attribute def OpticalIntensity_mW : Real {
        unit = "mW";
    }
    attribute def BatteryCharge : Real {
        unit = "%";
    }
    attribute def SampleDuration : Real {
        unit = "s";
    }
    attribute def SkinContactPressure : Real {
        unit = "kPa";
    }

    enum def DiagnosticResultKind {
        enum negative;
        enum positive;
        enum inconclusive;
        enum invalidMeasurement;
    }

    enum def MeasurementQualityKind {
        enum adequate;
        enum weakSignal;
        enum motionArtifact;
        enum poorContact;
        enum overTemperature;
    }

    item def FingerTissue {
        attribute perfusionIndex : Percent;
        attribute melaninCompensationFactor : Real;
        attribute contactPressure : SkinContactPressure;
    }

    item def OpticalPulse {
        attribute wavelength : Wavelength_nm;
        attribute emittedPower : OpticalIntensity_mW;
        attribute pulseWidth : SampleDuration;
    }

    item def ReflectedOpticalSignal {
        attribute wavelength : Wavelength_nm;
        attribute receivedPower : OpticalIntensity_mW;
        attribute noiseRatio : Percent;
        attribute sampleTime : SampleDuration;
    }

    item def SpectralMeasurement {
        attribute redAbsorption : Real;
        attribute nearInfraredAbsorption : Real;
        attribute greenAbsorption : Real;
        attribute signalQuality : MeasurementQualityKind;
        attribute acquisitionDuration : SampleDuration;
    }

    item def DiagnosticAssessment {
        attribute result : DiagnosticResultKind;
        attribute confidence : ConfidenceScore;
        attribute estimatedParasiteDensity : ParasiteDensityEstimate;
        attribute recommendationCode : String;
        attribute generatedAtSeconds : Real;
    }

    item def UserCommand {
        attribute startScan : Boolean;
        attribute cancelScan : Boolean;
        attribute requestHistory : Boolean;
    }

    item def DisplayMessage {
        attribute title : String;
        attribute body : String;
        attribute result : DiagnosticResultKind;
        attribute confidence : ConfidenceScore;
    }

    item def EncryptedReport {
        attribute patientAlias : String;
        attribute result : DiagnosticResultKind;
        attribute confidence : ConfidenceScore;
        attribute checksum : String;
    }

    item def ChargingPower {
        attribute voltage : Real {
            unit = "V";
        }
        attribute current : Real {
            unit = "A";
        }
    }

    port def FingerContactPort {
        in item finger : FingerTissue;
        out item contactStatus : MeasurementQualityKind;
    }

    port def OpticalEmitterPort {
        out item pulse : OpticalPulse;
    }

    port def OpticalReceiverPort {
        in item reflection : ReflectedOpticalSignal;
    }

    port def DiagnosticDataPort {
        out item assessment : DiagnosticAssessment;
    }

    port def CommandPort {
        in item command : UserCommand;
    }

    port def UserDisplayPort {
        out item message : DisplayMessage;
    }

    port def ReportPort {
        out item report : EncryptedReport;
    }

    port def PowerPort {
        in item chargingPower : ChargingPower;
    }

    action def AcquireOpticalSample {
        in item finger : FingerTissue;
        out item measurement : SpectralMeasurement;

        first start;
        then validateContact;
        then emitMultiWavelengthPulses;
        then captureReflectedSignal;
        then filterMotionArtifact;
        then produceMeasurement;
        then done;

        action validateContact {
            in item finger : FingerTissue;
            out attribute quality : MeasurementQualityKind;
        }

        action emitMultiWavelengthPulses {
            out item redPulse : OpticalPulse;
            out item nearInfraredPulse : OpticalPulse;
            out item greenPulse : OpticalPulse;
        }

        action captureReflectedSignal {
            in item redPulse : OpticalPulse;
            in item nearInfraredPulse : OpticalPulse;
            in item greenPulse : OpticalPulse;
            out item reflectedSignal : ReflectedOpticalSignal;
        }

        action filterMotionArtifact {
            in item reflectedSignal : ReflectedOpticalSignal;
            out item cleanedMeasurement : SpectralMeasurement;
        }

        action produceMeasurement {
            in item cleanedMeasurement : SpectralMeasurement;
            out item measurement : SpectralMeasurement;
        }
    }

    action def AnalyzeForMalaria {
        in item measurement : SpectralMeasurement;
        out item assessment : DiagnosticAssessment;

        first start;
        then normalizeForSkinToneAndPerfusion;
        then extractHemozoinRelatedFeatures;
        then classifyMalariaLikelihood;
        then estimateParasiteDensity;
        then composeAssessment;
        then done;

        action normalizeForSkinToneAndPerfusion {
            in item measurement : SpectralMeasurement;
            out item normalizedMeasurement : SpectralMeasurement;
        }

        action extractHemozoinRelatedFeatures {
            in item normalizedMeasurement : SpectralMeasurement;
            out attribute spectralFeatureVector : Real[8];
        }

        action classifyMalariaLikelihood {
            in attribute spectralFeatureVector : Real[8];
            out attribute result : DiagnosticResultKind;
            out attribute confidence : ConfidenceScore;
        }

        action estimateParasiteDensity {
            in attribute spectralFeatureVector : Real[8];
            out attribute density : ParasiteDensityEstimate;
        }

        action composeAssessment {
            in attribute result : DiagnosticResultKind;
            in attribute confidence : ConfidenceScore;
            in attribute density : ParasiteDensityEstimate;
            out item assessment : DiagnosticAssessment;
        }
    }

    action def PresentResult {
        in item assessment : DiagnosticAssessment;
        out item message : DisplayMessage;

        first start;
        then formatResultForUser;
        then showGuidance;
        then done;

        action formatResultForUser {
            in item assessment : DiagnosticAssessment;
            out item message : DisplayMessage;
        }

        action showGuidance {
            in item message : DisplayMessage;
        }
    }

    state def MatibabuOperationalStates {
        entry action initializeHardware;
        state Off;
        state Standby;
        state ReadyForFinger;
        state Measuring;
        state Analyzing;
        state Reporting;
        state Fault;
        state Charging;

        initial then Off;

        transition powerOn
            first Off
            accept UserCommand
            if command.startScan == true
            then Standby;

        transition ready
            first Standby
            then ReadyForFinger;

        transition beginMeasurement
            first ReadyForFinger
            accept FingerTissue
            if finger.contactPressure >= 2.0 and finger.contactPressure <= 12.0
            then Measuring;

        transition completeMeasurement
            first Measuring
            then Analyzing;

        transition completeAnalysis
            first Analyzing
            then Reporting;

        transition returnToStandby
            first Reporting
            then Standby;

        transition contactFault
            first ReadyForFinger
            accept FingerTissue
            if finger.contactPressure < 2.0 or finger.contactPressure > 12.0
            then Fault;

        transition resetFault
            first Fault
            accept UserCommand
            if command.cancelScan == true
            then Standby;

        transition startCharging
            first Off
            accept ChargingPower
            then Charging;

        transition finishCharging
            first Charging
            then Off;
    }

    part def OpticalProbe {
        port contact : FingerContactPort;
        port emitter : OpticalEmitterPort;
        port receiver : OpticalReceiverPort;

        attribute redWavelength : Wavelength_nm = 660.0;
        attribute nearInfraredWavelength : Wavelength_nm = 940.0;
        attribute greenWavelength : Wavelength_nm = 525.0;
        attribute maximumOpticalPower : OpticalIntensity_mW = 5.0;
        attribute nominalContactPressure : SkinContactPressure = 6.0;

        perform action AcquireOpticalSample;
    }

    part def SignalProcessor {
        in port rawSignal : OpticalReceiverPort;
        out port diagnosticData : DiagnosticDataPort;

        attribute samplingRateHz : Real = 200.0;
        attribute minimumSignalQuality : Percent = 85.0;
        attribute measurementWindow : SampleDuration = 45.0;

        perform action AnalyzeForMalaria;
    }

    part def UserInterface {
        port commands : CommandPort;
        port display : UserDisplayPort;

        attribute displayBrightness : Percent = 80.0;
        attribute audibleAlertEnabled : Boolean = true;

        perform action PresentResult;
    }

    part def SecureHealthRecordModule {
        port diagnosticInput : DiagnosticDataPort;
        port reportOutput : ReportPort;

        attribute localRecordCapacity : Integer = 250;
        attribute encryptionEnabled : Boolean = true;
        attribute transmissionEnabled : Boolean = true;
    }

    part def BatterySubsystem {
        port chargeInput : PowerPort;

        attribute chargeRemaining : BatteryCharge = 100.0;
        attribute nominalVoltage : Real {
            unit = "V";
        } = 3.7;
        attribute capacityMilliampHours : Real {
            unit = "mA*h";
        } = 2200.0;
        attribute lowBatteryThreshold : BatteryCharge = 15.0;
    }

    part def Matibabu {
        doc
        /*
         * Matibabu is modeled as a portable, non-invasive malaria screening system.
         * Its primary high-level function is to examine optical characteristics of
         * perfused finger tissue, infer whether malaria-associated blood changes
         * are present, and present a timely diagnostic assessment to the user.
         */

        port fingerContact : FingerContactPort;
        port userCommands : CommandPort;
        port userDisplay : UserDisplayPort;
        port healthReport : ReportPort;
        port charging : PowerPort;

        part probe : OpticalProbe;
        part processor : SignalProcessor;
        part interface : UserInterface;
        part records : SecureHealthRecordModule;
        part battery : BatterySubsystem;

        attribute deviceMass : Real {
            unit = "g";
        } = 180.0;

        attribute scanDuration : SampleDuration = 60.0;
        attribute minimumBatteryForScan : BatteryCharge = 10.0;
        attribute operatingTemperatureMin : Real {
            unit = "degC";
        } = 10.0;
        attribute operatingTemperatureMax : Real {
            unit = "degC";
        } = 40.0;

        connection fingerToProbe connect fingerContact to probe.contact;
        connection commandsToInterface connect userCommands to interface.commands;
        connection probeSignalToProcessor connect probe.receiver to processor.rawSignal;
        connection processorToRecords connect processor.diagnosticData to records.diagnosticInput;
        connection processorToDisplay connect processor.diagnosticData to interface.display;
        connection recordsToExternalReport connect records.reportOutput to healthReport;
        connection interfaceToUserDisplay connect interface.display to userDisplay;
        connection externalChargingToBattery connect charging to battery.chargeInput;

        exhibit state MatibabuOperationalStates;

        perform action screeningWorkflow {
            in item finger : FingerTissue;
            in item command : UserCommand;
            out item assessment : DiagnosticAssessment;
            out item message : DisplayMessage;
            out item report : EncryptedReport;

            first receiveStartCommand;
            then acquireSample;
            then analyzeSample;
            then presentAssessment;
            then storeAndEncryptReport;
            then done;

            action receiveStartCommand {
                in item command : UserCommand;
            }

            action acquireSample : AcquireOpticalSample {
                in item finger = screeningWorkflow::finger;
                out item measurement;
            }

            action analyzeSample : AnalyzeForMalaria {
                in item measurement = acquireSample::measurement;
                out item assessment = screeningWorkflow::assessment;
            }

            action presentAssessment : PresentResult {
                in item assessment = analyzeSample::assessment;
                out item message = screeningWorkflow::message;
            }

            action storeAndEncryptReport {
                in item assessment = analyzeSample::assessment;
                out item report = screeningWorkflow::report;
            }
        }
    }

    requirement def NonInvasiveScreeningRequirement {
        subject matibabu : Matibabu;

        require constraint {
            matibabu.scanDuration <= 60.0
        }

        doc
        /*
         * The system shall complete a non-invasive malaria screening workflow
         * without requiring blood draw or consumable test strips.
         */
    }

    requirement def DiagnosticConfidenceRequirement {
        subject assessment : DiagnosticAssessment;

        require constraint {
            assessment.confidence >= 0.90
        }

        doc
        /*
         * The generated assessment shall include a confidence score suitable
         * for screening-level decision support.
         */
    }

    requirement def UserResultRequirement {
        subject message : DisplayMessage;

        require constraint {
            message.title != "" and message.body != ""
        }

        doc
        /*
         * The system shall present the malaria screening result and next-step
         * guidance in a form understandable to a trained community health worker.
         */
    }

    requirement def BatteryOperationRequirement {
        subject battery : BatterySubsystem;

        require constraint {
            battery.chargeRemaining >= battery.lowBatteryThreshold
        }

        doc
        /*
         * The system shall prevent scan initiation when battery charge is below
         * the minimum level needed to complete measurement, analysis, and reporting.
         */
    }

    requirement def OpticalSafetyRequirement {
        subject probe : OpticalProbe;

        require constraint {
            probe.maximumOpticalPower <= 5.0
        }

        doc
        /*
         * The optical probe shall limit emitted optical power to a safe level
         * for repeated contact measurements on a fingertip.
         */
    }

    requirement def DataProtectionRequirement {
        subject records : SecureHealthRecordModule;

        require constraint {
            records.encryptionEnabled == true
        }

        doc
        /*
         * Diagnostic records exported by the device shall be encrypted before
         * transmission or long-term storage.
         */
    }

    satisfy NonInvasiveScreeningRequirement by Matibabu;
    satisfy BatteryOperationRequirement by Matibabu::battery;
    satisfy OpticalSafetyRequirement by Matibabu::probe;
    satisfy DataProtectionRequirement by Matibabu::records;
}