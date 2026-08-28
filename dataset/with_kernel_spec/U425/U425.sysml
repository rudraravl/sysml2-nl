package TruenatDiagnosticPlatform {
    private import ScalarValues::*;
    private import SI::*;

    attribute def Duration :> Real;
    attribute def TemperatureValue :> Real;
    attribute def FluorescenceLevel :> Real;
    attribute def MassValue :> Real;

    item def BiologicalSample;
    item def LysisBuffer;
    item def NucleicAcid;
    item def TruenatChip {
        attribute targetPathogen : String;
        attribute loadedNucleicAcid : NucleicAcid [0..*];
        attribute disposed : Boolean = false;
    }
    item def FluorescentSignal {
        attribute level : FluorescenceLevel;
    }
    enum def DiagnosticResult {
        Detected;
        NotDetected;
        Invalid;
    }
    item def ControlCommand;
    item def StartCommand;
    enum def Status {
        Idle;
        Busy;
        Completed;
        Error;
    }
    enum def UserCommand {
        StartTest;
        Abort;
        Reset;
    }

    item def StartTestSignal;
    item def PrepCompleteSignal;
    item def AmpCompleteSignal;
    item def ErrorSignal;
    item def AbortSignal;
    item def ResetSignal;
    item def ResultViewedSignal;

    part def Battery {
        attribute capacity : MassValue;
        attribute voltage : Real;
    }

    part def ControlAndProcessingUnit {
        port prepCmdPort { out cmd : ControlCommand; }
        port ampCmdPort { out cmd : ControlCommand; }
        port thermalCmdPort { out cmd : ControlCommand; }
        port opticalCmdPort { out cmd : ControlCommand; }
        port signalInPort { in signal : FluorescentSignal; }
        port statusInPort { in status : Status; }
        port resultOutPort { out result : DiagnosticResult; }
        port uiCmdInPort { in userCmd : UserCommand; }
        port progressOutPort { out progress : Real; }

        attribute threshold : FluorescenceLevel = 500;
        attribute maxTime : Duration = 60;
        attribute elapsedTime : Duration = 0;
        attribute result : DiagnosticResult;

        state def ControlStates;
        state controlStates : ControlStates {
            entry; then standby;
            state standby;
            accept StartTestSignal then selfTest;
            state selfTest {
                do action performSelfTest { /* internal diagnostics */ }
            }
            accept PrepCompleteSignal then ready;
            state ready;
            accept StartTestSignal then samplePreparation;
            state samplePreparation {
                entry action startWorkflow { /* send prep commands */ }
            }
            accept PrepCompleteSignal then amplification;
            accept ErrorSignal then error;
            state amplification {
                entry action startAmplification { /* send amp commands */ }
                do action monitorAmplification { /* monitor fluorescence */ }
            }
            accept AmpCompleteSignal then reporting;
            accept ErrorSignal then error;
            state reporting {
                entry action sendResult { /* send result to UI */ }
            }
            accept ResultViewedSignal then ready;
            state error {
                entry action handleError { /* handle error condition */ }
            }
            accept ResultViewedSignal then ready;
            accept AbortSignal then aborting;
            state aborting {
                entry action abortProcess { /* abort all modules */ }
            }
            accept ResetSignal then standby;
        }
    }

    part def SamplePreparationUnit {
        port sampleInPort { in sample : BiologicalSample; }
        port chipInPort { in chip : TruenatChip; }
        port chipOutPort { out chip : TruenatChip; }
        port wasteOutPort { out waste : BiologicalSample; }
        port cmdInPort { in cmd : ControlCommand; }
        port statusOutPort { out status : Status; }

        action extractNucleicAcid {
            in rawSample : BiologicalSample;
            in buffer : LysisBuffer;
            in chip : TruenatChip;
            out purifiedChip : TruenatChip;
            out waste : BiologicalSample;
        }
    }

    part def AmplificationUnit {
        port chipInPort { in chip : TruenatChip; }
        port chipMonitorPort { out chip : TruenatChip; }
        port tempInPort { in temp : TemperatureValue; }
        port cmdInPort { in cmd : ControlCommand; }
        port statusOutPort { out status : Status; }

        action performPCR {
            in chip : TruenatChip;
            in temp : TemperatureValue;
        }
    }

    part def ThermalManagementUnit {
        port cmdInPort { in cmd : ControlCommand; }
        port tempOutPort { out temp : TemperatureValue; }
        port statusOutPort { out status : Status; }

        action cycleTemperature {
            in cmd : ControlCommand;
            out temp : TemperatureValue;
        }
    }

    part def OpticalDetectionUnit {
        port chipInPort { in chip : TruenatChip; }
        port signalOutPort { out signal : FluorescentSignal; }
        port cmdInPort { in cmd : ControlCommand; }
        port statusOutPort { out status : Status; }

        action measureFluorescence {
            in chip : TruenatChip;
            out signal : FluorescentSignal;
        }
    }

    part def UserInterfaceModule {
        port resultInPort { in result : DiagnosticResult; }
        port resultOutPort { out result : DiagnosticResult; }
        port userCmdInPort { in userCmd : UserCommand; }
        port userCmdOutPort { out userCmd : UserCommand; }
        port progressInPort { in progress : Real; }

        action displayResult {
            in result : DiagnosticResult;
        }
        action displayProgress {
            in progress : Real;
        }
    }

    part def Operator {
        port samplePort { out sample : BiologicalSample; }
        port chipPort { out chip : TruenatChip; }
        port commandPort { out userCmd : UserCommand; }
    }

    part def TruenatSystem {
        attribute testDuration : Duration;
        attribute powerSource : String;
        attribute infrastructureDependency : String;
        attribute chipDisposal : String;
        attribute systemMass : MassValue;

        port sampleInputPort { in sample : BiologicalSample; }
        port chipInputPort { in chip : TruenatChip; }
        port displayPort { out result : DiagnosticResult; }
        port userCommandPort { in userCmd : UserCommand; }

        part battery : Battery;
        part controlUnit : ControlAndProcessingUnit;
        part samplePrepUnit : SamplePreparationUnit;
        part amplificationUnit : AmplificationUnit;
        part thermalUnit : ThermalManagementUnit;
        part opticalUnit : OpticalDetectionUnit;
        part uiModule : UserInterfaceModule;

        flow sampleFlow of BiologicalSample
            from sampleInputPort.sample to samplePrepUnit.sampleInPort.sample;
        flow chipFlow of TruenatChip
            from chipInputPort.chip to samplePrepUnit.chipInPort.chip;
        flow prepControlFlow of ControlCommand
            from controlUnit.prepCmdPort.cmd to samplePrepUnit.cmdInPort.cmd;
        flow prepStatusFlow of Status
            from samplePrepUnit.statusOutPort.status to controlUnit.statusInPort.status;
        flow preparedChipFlow of TruenatChip
            from samplePrepUnit.chipOutPort.chip to amplificationUnit.chipInPort.chip;
        flow ampControlFlow of ControlCommand
            from controlUnit.ampCmdPort.cmd to amplificationUnit.cmdInPort.cmd;
        flow thermalControlFlow of ControlCommand
            from controlUnit.thermalCmdPort.cmd to thermalUnit.cmdInPort.cmd;
        flow temperatureFlow of TemperatureValue
            from thermalUnit.tempOutPort.temp to amplificationUnit.tempInPort.temp;
        flow opticalMonitorFlow of TruenatChip
            from amplificationUnit.chipMonitorPort.chip to opticalUnit.chipInPort.chip;
        flow opticalControlFlow of ControlCommand
            from controlUnit.opticalCmdPort.cmd to opticalUnit.cmdInPort.cmd;
        flow opticalSignalFlow of FluorescentSignal
            from opticalUnit.signalOutPort.signal to controlUnit.signalInPort.signal;
        flow resultFlow of DiagnosticResult
            from controlUnit.resultOutPort.result to uiModule.resultInPort.result;
        flow displayResultFlow of DiagnosticResult
            from uiModule.resultOutPort.result to displayPort.result;
        flow userCommandFlow of UserCommand
            from userCommandPort.userCmd to controlUnit.uiCmdInPort.userCmd;
        flow progressFlow of Real
            from controlUnit.progressOutPort.progress to uiModule.progressInPort.progress;
    }

    requirement def RapidTestingRequirement {
        doc /* The system shall complete a diagnostic test in under 60 minutes. */
        subject system : TruenatSystem;
        constraint testTimeConstraint { system.testDuration <= 60 }
    }

    requirement def PortabilityRequirement {
        doc /* The system shall be portable, battery-operated, and weigh less than 5 kg. */
        subject system : TruenatSystem;
        constraint powerSourceConstraint { system.powerSource == "Battery" }
        constraint massConstraint { system.systemMass < 5 }
    }

    requirement def PointOfCareRequirement {
        doc /* The system shall be operable in settings with minimal laboratory infrastructure. */
        subject system : TruenatSystem;
        constraint infrastructureConstraint { system.infrastructureDependency == "Minimal" }
    }

    requirement def ContaminationPreventionRequirement {
        doc /* The system shall use single-use disposable chips to prevent contamination. */
        subject system : TruenatSystem;
        constraint disposalConstraint { system.chipDisposal == "SingleUse" }
    }

    requirement def EaseOfUseRequirement {
        doc /* The system shall be operable by personnel without specialized laboratory training. */
        subject system : TruenatSystem;
    }

    part truenatDevice : TruenatSystem {
        :>> testDuration = 45;
        :>> powerSource = "Battery";
        :>> infrastructureDependency = "Minimal";
        :>> chipDisposal = "SingleUse";
        :>> systemMass = 3.2;

        satisfy rapidTestReq : RapidTestingRequirement;
        satisfy portabilityReq : PortabilityRequirement;
        satisfy pointOfCareReq : PointOfCareRequirement;
        satisfy contaminationReq : ContaminationPreventionRequirement;
        satisfy easeOfUseReq : EaseOfUseRequirement;
    }
}
