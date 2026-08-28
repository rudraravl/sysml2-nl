package OsteomedBoneHealingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def AcousticIntensity :> Real { unit 'mW/cm^2'; }
    value def Duration :> Real { unit 'min'; }
    value def BoneDensity :> Real { unit 'mg/cm^3'; }
    value def Temperature :> Real {> Real { unit 'C'; }
    value def Percentage :> Real { unit '%'; }

    item def ElectricalSignal {
        attribute frequency : Frequency;
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def UltrasoundWave {
        attribute frequency : Frequency;
        attribute intensity : AcousticIntensity;
        attribute duration : Duration;
    }

    item def BoneTissueData {
        attribute density : BoneDensity;
        attribute healingRate : Percentage;
        attribute temperature : Temperature;
    }

    item def TreatmentProtocol {
        attribute patientId : String;
        attribute fractureSite : String;
        attribute sessionDuration : Duration;
        attribute targetIntensity : AcousticIntensity;
        attribute targetFrequency : Frequency;
        attribute totalSessions : Integer;
        attribute baselineDensity : BoneDensity;
    }

    item def SessionReport {
        attribute sessionId : String;
        attribute date : String;
        attribute deliveredDuration : Duration;
        attribute avgIntensity : AcousticIntensity;
        attribute preDensity : BoneDensity;
        attribute postDensity : BoneDensity;
        attribute healingProgress : Percentage;
        attribute recommendation : String;
    }

    // ===== Port Definitions =====

    port def ElectricalPowerPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def SignalPort {
        out signal : ElectricalSignal;
    }

    port def UltrasoundPort {
        out wave : UltrasoundWave;
    }

    port def SensorDataPort {
        out tissueData : BoneTissueData;
    }

    port def ProtocolPort {
        in protocol : TreatmentProtocol;
        out report : SessionReport;
    }

    // ===== Requirements =====

    requirement def AccelerateBoneHealing {
        doc "The system shall accelerate healing of bone fractures using LIPUS technology."
        attribute targetHealingImprovement : Percentage = 30;
        subject device : OsteomedSystem;
        require device.therapyEffectiveness >= targetHealingImprovement;
    }

    requirement def DeliverControlledUltrasound {
        doc "The system shall deliver low-intensity pulsed ultrasound at defined frequency and intensity."
        attribute requiredFrequency : Frequency = 1.5e6 [Hz];
        attribute requiredIntensity : AcousticIntensity = 30 [mW/cm^2];
        subject generator : UltrasoundGeneratorModule;
        require generator.outputFrequency == requiredFrequency
            and generator.outputIntensity == requiredIntensity;
    }

    requirement def MonitorBoneDensity {
        doc "The system shall continuously monitor bone density during therapy sessions."
        subject sensor : BoneDensitySensor;
        require sensor.measurementAccuracy <= 5 [%];
    }

    requirement def EnsurePatientSafety {
        doc "The system shall maintain safe operating conditions at the treatment site."
        attribute maxSkinTemperature : Temperature = 41 [C];
        subject system : OsteomedSystem;
        require system.patientInterface.skinTemperature <= maxSkinTemperature;
    }

    requirement def GenerateSessionReport {
        doc "The system shall generate a comprehensive report after each therapy session."
        subject control : TreatmentControlUnit;
        require control.reportGenerated == true;
    }

    // ===== Parts =====

    part def OsteomedSystem {
        requirement accBoneHealing : AccelerateBoneHealing;
        requirement delivUltrasound : DeliverControlledUltrasound;
        requirement monBoneDensity : MonitorBoneDensity;
        requirement ensureSafety : EnsurePatientSafety;
        requirement genReport : GenerateSessionReport;

        attribute therapyEffectiveness : Percentage;
        attribute patientInterface :> BoneDensitySensor;

        part controlUnit : TreatmentControlUnit;
        part powerUnit : PowerManagementUnit;
        part ultrasoundGenerator : UltrasoundGeneratorModule;
        part transducerAssembly : TransducerAssembly;
        part densitySensor : BoneDensitySensor;

        connection powerToControl : ElectricalPowerPort connect powerUnit.powerOut to controlUnit.powerIn;
        connection powerToGenerator : ElectricalPowerPort connect powerUnit.powerOut to ultrasoundGenerator.powerIn;
        connection powerToSensor : ElectricalPowerPort connect powerUnit.powerOut to densitySensor.powerIn;

        connection signalToTransducer : SignalPort connect ultrasoundGenerator.signalOut to transducerAssembly.signalIn;
        connection waveToPatient : UltrasoundPort connect transducerAssembly.waveOut to densitySensor.waveIn;
        connection sensorToControl : SensorDataPort connect densitySensor.dataOut to controlUnit.sensorDataIn;
        connection protocolToControl : ProtocolPort connect controlUnit.protocolPort to controlUnit.protocolPort;

        exhibit stateMachineBehavior : TherapyStateMachine;
    }

    part def TreatmentControlUnit {
        attribute reportGenerated : Boolean = false;
        attribute currentProtocol : TreatmentProtocol;
        attribute sessionCount : Integer = 0;
        attribute accumulatedReports : SessionReport[0..*];

        port powerIn : ElectricalPowerPort;
        port sensorDataIn : SensorDataPort;
        port protocolPort : ProtocolPort;

        exhibit therapyControl : TherapyControlAction;

        state def TherapyStateMachine {
            entry; then Initializing;

            state Initializing {
                entry action {
                    powerOn();
                    selfCheck();
                }
            }

            transition from Initializing to LoadingProtocol
                when powerIn.voltage >= 5 [V];

            state LoadingProtocol {
                entry action {
                    currentProtocol = loadPatientProtocol();
                }
            }

            transition from LoadingProtocol to ActiveTherapy
                when currentProtocol != null;

            state ActiveTherapy {
                entry action {
                    startTherapyCycle();
                }
                do action {
                    while (therapyActive) {
                        monitorTissueResponse();
                        checkSafetyConditions();
                    }
                }
            }

            transition from ActiveTherapy to RecordingData
                when sessionDurationElapsed;

            state RecordingData {
                entry action {
                    recordSessionData();
                    assessHealingProgress();
                }
            }

            transition from RecordingData to EvaluatingProgress;

            state EvaluatingProgress {
                entry action {
                    compareAgainstBaseline();
                    determineTreatmentContinuation();
                }
            }

            transition from EvaluatingProgress to GeneratingReport;

            state GeneratingReport {
                entry action {
                    generateComprehensiveReport();
                    reportGenerated = true;
                }
            }

            transition from GeneratingReport to Complete
                when reportGenerated == true;

            state Complete {
                entry action {
                    shutdownSequence();
                }
            }

            transition from Complete to LoadingProtocol
                when continueTreatmentPlan == true;
        }

        action def TherapyControlAction {
            in protocol : TreatmentProtocol;
            in tissueData : BoneTissueData;
            out report : SessionReport;

            action loadProtocol {
                out loadedProtocol : TreatmentProtocol;
            }

            action executeTherapy {
                in loadedProtocol;
                in tissueData;
                out therapyResult : BoneTissueData;
            }

            action evaluateProgress {
                in therapyResult;
                in loadedProtocol;
                out progressAssessment : Percentage;
            }

            action produceReport {
                in progressAssessment;
                in loadedProtocol;
                out report : SessionReport;
            }

            flow from loadProtocol.loadedProtocol to executeTherapy.loadedProtocol;
            flow from executeTherapy.therapyResult to evaluateProgress.therapyResult;
            flow from evaluateProgress.progressAssessment to produceReport.progressAssessment;
        }
    }

    part def PowerManagementUnit {
        attribute inputVoltage : Voltage;
        attribute regulatedVoltage : Voltage = 5 [V];
        attribute regulatedCurrent : Current = 2 [A];
        attribute totalPower : Power;

        port powerOut : ElectricalPowerPort;

        state def PowerStateMachine {
            entry; then Off;
            state Off;
            transition from Off to Starting when externalPowerConnected;
            state Starting {
                entry action {
                    regulateVoltage();
                    regulateCurrent();
                }
            }
            transition from Starting to Stable when regulatedVoltage == 5 [V];
            state Stable {
                do action {
                    monitorPowerQuality();
                }
            }
            transition from Stable to Fault when overcurrentDetected or overvoltageDetected;
            state Fault {
                entry action {
                    emergencyShutdown();
                }
            }
        }
    }

    part def UltrasoundGeneratorModule {
        attribute outputFrequency : Frequency = 1.5e6 [Hz];
        attribute outputIntensity : AcousticIntensity = 30 [mW/cm^2];
        attribute pulseDuration : Duration = 0.2 [ms];
        attribute dutyCycle : Percentage = 20 [%];

        port powerIn : ElectricalPowerPort;
        port signalOut : SignalPort;

        action def GenerateWaveform {
            in power : ElectricalPowerPort;
            out signal : ElectricalSignal;
            action modulatePulse {
                out modulatedSignal : ElectricalSignal;
            }
            action amplifySignal {
                in modulatedSignal;
                out amplifiedSignal : ElectricalSignal;
            }
            flow from modulatePulse.modulatedSignal to amplifySignal.modulatedSignal;
        }
    }

    part def TransducerAssembly {
        attribute couplingEfficiency : Percentage = 85 [%];
        attribute waveguideDiameter : Real = 25 [mm];
        attribute skinTemperature : Temperature;

        port signalIn : SignalPort;
        port waveOut : UltrasoundPort;

        action def ConvertSignalToWave {
            in electricalSignal : ElectricalSignal;
            out ultrasoundWave : UltrasoundWave;
            action piezoelectricConversion {
                in electricalSignal;
                out mechanicalVibration;
            }
            action focusWave {
                in mechanicalVibration;
                out focusedWave : UltrasoundWave;
            }
            flow from piezoelectricConversion.mechanicalVibration to focusWave.mechanicalVibration;
        }
    }

    part def BoneDensitySensor {
        attribute measurementAccuracy : Percentage = 3 [%];
        attribute samplingRate : Frequency = 1 [Hz];
        attribute currentDensity : BoneDensity;
        attribute healingRate : Percentage;
        attribute skinTemperature : Temperature;

        port powerIn : ElectricalPowerPort;
        port waveIn : UltrasoundPort;
        port dataOut : SensorDataPort;

        action def MeasureBoneDensity {
            in ultrasoundWave : UltrasoundWave;
            out tissueData : BoneTissueData;
            action emitProbePulse {
                out probeWave : UltrasoundWave;
            }
            action receiveEcho {
                in probeWave;
                out echoSignal;
            }
            action calculateDensity {
                in echoSignal;
                out densityValue : BoneDensity;
            }
            action assessHealing {
                in densityValue;
                out tissueData : BoneTissueData;
            }
            flow from emitProbePulse.probeWave to receiveEcho.probeWave;
            flow from receiveEcho.echoSignal to calculateDensity.echoSignal;
            flow from calculateDensity.densityValue to assessHealing.densityValue;
        }
    }

    // ===== Package-level requirement satisfaction =====

    satisfaction accBoneHealingSatisfaction : AccelerateBoneHealing {
        subject device : OsteomedSystem;
        satisfy device.therapyEffectiveness >= 30 [%];
    }

    satisfaction deliverUltrasoundSatisfaction : DeliverControlledUltrasound {
        subject generator : UltrasoundGeneratorModule;
        satisfy generator.outputFrequency == 1.5e6 [Hz]
            and generator.outputIntensity == 30 [mW/cm^2];
    }

    satisfaction monitorDensitySatisfaction : MonitorBoneDensity {
        subject sensor : BoneDensitySensor;
        satisfy sensor.measurementAccuracy <= 5 [%];
    }

    satisfaction safetySatisfaction : EnsurePatientSafety {
        subject system : OsteomedSystem;
        satisfy system.patientInterface.skinTemperature <= 41 [C];
    }

    satisfaction reportSatisfaction : GenerateSessionReport {
        subject control : TreatmentControlUnit;
        satisfy control.reportGenerated == true;
    }

}
