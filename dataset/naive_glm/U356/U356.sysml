package PlethysmographSystem {
    import ScalarValues::*;

    // Value Types
    value def Voltage :> Real { unit 'V'; }
    value def Volume :> Real { unit 'mL'; }
    value def FlowRate :> Real { unit 'mL/min'; }
    value def SignalQuality :> Real { unit '1'; }
    value def Time :> Real { unit 's'; }

    // Enumerations
    enum def SensingTechnique { strainGauge; impedance; photoelectric; }
    enum def ControlCommand { start; stop; calibrate; configure; }

    // Item Definitions
    item def RawSignal {
        attribute voltage : Voltage;
        attribute timestamp : Time;
    }

    item def ProcessedSignal {
        attribute volumeChange : Volume;
        attribute bloodFlowRate : FlowRate;
        attribute quality : SignalQuality;
    }

    item def DisplayData {
        attribute waveform : RawSignal[0..*];
        attribute totalVolumeChange : Volume;
        attribute bloodFlowRate : FlowRate;
        attribute isValid : Boolean;
    }

    item def OperatorInput {
        attribute command : ControlCommand;
        attribute technique : SensingTechnique;
    }

    // Port Definitions
    port def RawSignalOut {
        out rawSignal : RawSignal;
    }
    port def RawSignalIn {
        in rawSignal : RawSignal;
    }
    port def ProcessedSignalOut {
        out processedSignal : ProcessedSignal;
    }
    port def ProcessedSignalIn {
        in processedSignal : ProcessedSignal;
    }
    port def DisplayDataOut {
        out displayData : DisplayData;
    }
    port def DisplayDataIn {
        in displayData : DisplayData;
    }
    port def ControlOut {
        out controlCommand : ControlCommand;
    }
    port def ControlIn {
        in controlCommand : ControlCommand;
    }
    port def OperatorIn {
        in operatorInput : OperatorInput;
    }

    // Part Definitions
    part def TransducerAssembly {
        attribute technique : SensingTechnique = SensingTechnique::strainGauge;
        port rawOut : RawSignalOut;
        port controlIn : ControlIn;

        action def SenseVolumeChange {
            in sensingTechnique : SensingTechnique;
            out signal : RawSignal;
        }

        action sense : SenseVolumeChange {
            // Detects physical changes in volume and converts to electrical signals
        }
    }

    part def SignalProcessor {
        port rawIn : RawSignalIn;
        port processedOut : ProcessedSignalOut;
        port controlIn : ControlIn;

        action def ProcessSignal {
            in raw : RawSignal;
            out processed : ProcessedSignal;
        }

        action process : ProcessSignal {
            // Amplifies, filters noise, extracts physiological parameters, and assesses signal quality
        }
    }

    part def ControlUnit {
        port controlOut : ControlOut;
        port displayOut : DisplayDataOut;
        port operatorIn : OperatorIn;

        state def ControlBehavior {
            entry; then Off;

            state Off;
            state SelfTest;
            state Calibration;
            state Ready;
            state Measuring;
            state Error;

            transition off_to_test 
                first Off 
                then SelfTest 
                when operatorIn.operatorInput.command == ControlCommand::start;

            transition test_to_calib 
                first SelfTest 
                then Calibration 
                accept 'Test Passed';

            transition test_to_error 
                first SelfTest 
                then Error 
                accept 'Test Failed';

            transition calib_to_ready 
                first Calibration 
                then Ready 
                accept 'Calibration Complete';

            transition ready_to_measuring 
                first Ready 
                then Measuring 
                when operatorIn.operatorInput.command == ControlCommand::start;

            transition measuring_to_ready 
                first Measuring 
                then Ready 
                when operatorIn.operatorInput.command == ControlCommand::stop;

            transition any_to_error 
                first Off | SelfTest | Calibration | Ready | Measuring 
                then Error 
                accept 'Fault Detected';
        }

        behavior controlState : ControlBehavior;
    }

    part def DisplayInterface {
        port processedIn : ProcessedSignalIn;
        port controlIn : ControlIn;

        action def RenderDisplay {
            in data : ProcessedSignal;
        }

        action render : RenderDisplay {
            // Provides real-time visual representation of physiological signals and numeric readouts
        }
    }

    // Top-level System
    part def Plethysmograph {
        part transducer : TransducerAssembly;
        part processor : SignalProcessor;
        part controller : ControlUnit;
        part display : DisplayInterface;

        connection controlToTransducer connect controller.controlOut to transducer.controlIn;
        connection controlToProcessor connect controller.controlOut to processor.controlIn;
        connection controlToDisplay connect controller.controlOut to display.controlIn;

        connection rawToProcessor connect transducer.rawOut to processor.rawIn;
        connection processedToDisplay connect processor.processedOut to display.processedIn;
    }

    // Requirements
    requirement def MeasureVolumeChanges {
        doc /* The transducer assembly shall detect volume changes and output raw electrical signals. */
        subject transducer : TransducerAssembly;
    }

    requirement def ProcessRawSignals {
        doc /* The signal processor shall amplify, filter, and extract physiological parameters while assessing signal quality. */
        subject processor : SignalProcessor;
    }

    requirement def ManageOperationalStates {
        doc /* The control unit shall manage operational states including Off, SelfTest, Calibration, Ready, Measuring, and Error. */
        subject controller : ControlUnit;
    }

    requirement def DisplayResults {
        doc /* The display interface shall show real-time waveform and numeric readouts of measurements. */
        subject display : DisplayInterface;
    }

    requirement def PlethysmographRequirements {
        requirement m1 : MeasureVolumeChanges;
        requirement m2 : ProcessRawSignals;
        requirement m3 : ManageOperationalStates;
        requirement m4 : DisplayResults;
    }
}
