package AlternatingElectricFieldTherapySystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Frequency :> Real { unit 'kHz'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Power :> Real { unit 'W'; }
    value def Duration :> Real { unit 'h'; }
    value def TimeInterval :> Real { unit 's'; }
    value def FieldStrength :> Real { unit 'V/m'; }

    // ---- Enums ----
    enum def SystemState {
        off = 0,
        selfTest = 1,
        loadingParameters = 2,
        treating = 3,
        paused = 4,
        fault = 5
    }

    enum def FieldDirection {
        anteriorPosterior = 0,
        leftRight = 1
    }

    enum def ArrayPosition {
        anterior = 0,
        posterior = 1,
        left = 2,
        right = 3
    }

    enum def PowerSource {
        acMains = 0,
        battery = 1
    }

    // ---- Item Definitions ----
    item def ACPower {
        attribute voltage : Voltage = 230;
        attribute frequency : Frequency = 50;
    }

    item def DCPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def TherapyParameters {
        attribute frequency : Frequency = 200;
        attribute fieldStrength : FieldStrength = 1.5;
        attribute sessionDuration : Duration = 18;
        attribute rotationInterval : TimeInterval = 1;
        attribute maxSkinTemp : Temperature = 41;
    }

    item def FieldCommand {
        attribute direction : FieldDirection;
        attribute frequency : Frequency;
        attribute amplitude : Voltage;
    }

    item def TemperatureReading {
        attribute position : ArrayPosition;
        attribute value : Temperature;
    }

    item def StatusReport {
        attribute state : SystemState;
        attribute activeDirection : FieldDirection;
        attribute elapsedTime : Duration;
        attribute source : PowerSource;
    }

    // ---- Requirements ----
    requirement def ShallProvideTherapy {
        doc /* The system shall apply low-intensity, intermediate-frequency electric fields to disrupt cancer cell mitosis. */
        attribute targetFrequency : Frequency = 200;
        attribute targetFieldStrength : FieldStrength = 1.5;
    }

    requirement def ShallRotateFieldOrientation {
        doc /* The system shall continuously rotate the electric field orientation during treatment. */
        attribute rotationInterval : TimeInterval = 1;
    }

    requirement def ShallProvideBackupPower {
        doc /* The system shall include battery backup to ensure uninterrupted therapy. */
    }

    requirement def ShallMonitorTemperature {
        doc /* The system shall monitor skin temperature at each transducer array and halt therapy if a safe threshold is exceeded. */
        attribute maxSkinTemp : Temperature = 41;
    }

    requirement def ShallRunSelfTest {
        doc /* The system shall run a self-test before beginning therapy. */
    }

    // ---- Parts ----

    part def PowerModule {
        port in acInput : ACPower;
        port out dcOutput : DCPower;
        port out powerStatus : PowerSource;

        attribute outputVoltage : Voltage = 24;
        attribute batteryCapacity : Power = 50;
        attribute activeSource : PowerSource = PowerSource::acMains;

        part battery {
            attribute chargeLevel : Real = 1.0;
            attribute maxOutput : Power = 50;
        }

        part acConverter {
            attribute efficiency : Real = 0.92;
        }

        action def convertPower {
            in ac : ACPower;
            out dc : DCPower;
        }

        perform convertPower {
            in ac = acInput;
            out dc = dcOutput;
        }
    }

    part def ControlProcessor {
        port in dcInput : DCPower;
        port in tempReadings : TemperatureReading[4];
        port out fieldCmd : FieldCommand;
        port out status : StatusReport;

        attribute therapyParams : TherapyParameters;
        attribute currentState : SystemState = SystemState::off;
        attribute activeDirection : FieldDirection = FieldDirection::anteriorPosterior;
        attribute elapsedTime : Duration = 0;
        attribute maxSkinTemp : Temperature = 41;

        state machine TherapyControl {
            entry; then Off;

            state Off;
            transition off_to_selfTest
                first Off
                if (dcInput.voltage > 0)
                then SelfTest;

            state SelfTest {
                entry { /* run diagnostics */ }
            }
            transition selfTest_to_load
                first SelfTest
                if (true)
                then LoadingParameters;

            state LoadingParameters {
                entry { /* load therapyParams */ }
            }
            transition load_to_treat
                first LoadingParameters
                if (true)
                then Treating;

            state Treating {
                entry { activeDirection = FieldDirection::anteriorPosterior; }
                do { send fieldCmd; }

                state AnteriorPosteriorActive {
                    entry { activeDirection = FieldDirection::anteriorPosterior; }
                }
                state LeftRightActive {
                    entry { activeDirection = FieldDirection::leftRight; }
                }

                transition ap_to_lr
                    first AnteriorPosteriorActive
                    after therapyParams.rotationInterval
                    then LeftRightActive;

                transition lr_to_ap
                    first LeftRightActive
                    after therapyParams.rotationInterval
                    then AnteriorPosteriorActive;
            }

            transition treat_to_fault
                first Treating
                if (any tempReadings.value > maxSkinTemp)
                then Fault;

            state Fault {
                entry { currentState = SystemState::fault; }
            }

            transition fault_to_off
                first Fault
                if (true)
                then Off;
        }
    }

    part def FieldGenerator {
        port in dcInput : DCPower;
        port in command : FieldCommand;
        port out waveformAnterior : DCPower;
        port out waveformPosterior : DCPower;
        port out waveformLeft : DCPower;
        port out waveformRight : DCPower;

        attribute carrierFrequency : Frequency = 200;
        attribute outputAmplitude : Voltage = 20;

        action def generateWaveform {
            in cmd : FieldCommand;
            out ant : DCPower;
            out post : DCPower;
            out left : DCPower;
            out right : DCPower;
        }

        perform generateWaveform {
            in cmd = command;
            out ant = waveformAnterior;
            out post = waveformPosterior;
            out left = waveformLeft;
            out right = waveformRight;
        }
    }

    part def CeramicDiskElement {
        port in energize : DCPower;
        attribute diameter : Real = 20;
        attribute capacitance : Real = 10e-9;
    }

    part def TemperatureSensor {
        port out reading : TemperatureReading;
        attribute position : ArrayPosition;
        attribute measuredTemp : Temperature = 37;

        action def measureTemperature {
            out r : TemperatureReading;
        }

        perform measureTemperature {
            out r = reading;
        }
    }

    part def TransducerArray {
        port in waveform : DCPower;
        port out tempReading : TemperatureReading;
        attribute position : ArrayPosition;

        part elements : CeramicDiskElement[9];

        part sensor : TemperatureSensor {
            attribute position = position;
        }

        connection energizeElements : DCPower connect waveform to elements.energize;
        connection tempOut : TemperatureReading connect sensor.reading to tempReading;
    }

    // ---- Top-level System ----
    part def AlternatingElectricFieldTherapyDevice {

        satisfy ShallProvideTherapy;
        satisfy ShallRotateFieldOrientation;
        satisfy ShallProvideBackupPower;
        satisfy ShallMonitorTemperature;
        satisfy ShallRunSelfTest;

        port in acMains : ACPower;

        part powerModule : PowerModule {
            port in acInput : ACPower;
            port out dcOutput : DCPower;
            port out powerStatus : PowerSource;
        }

        part controlProcessor : ControlProcessor {
            port in dcInput : DCPower;
            port in tempReadings : TemperatureReading[4];
            port out fieldCmd : FieldCommand;
            port out status : StatusReport;
        }

        part fieldGenerator : FieldGenerator {
            port in dcInput : DCPower;
            port in command : FieldCommand;
            port out waveformAnterior : DCPower;
            port out waveformPosterior : DCPower;
            port out waveformLeft : DCPower;
            port out waveformRight : DCPower;
        }

        part anteriorArray : TransducerArray {
            attribute position = ArrayPosition::anterior;
        }
        part posteriorArray : TransducerArray {
            attribute position = ArrayPosition::posterior;
        }
        part leftArray : TransducerArray {
            attribute position = ArrayPosition::left;
        }
        part rightArray : TransducerArray {
            attribute position = ArrayPosition::right;
        }

        // Connections
        connection mainsToPower : ACPower connect acMains to powerModule.acInput;
        connection powerToProcessor : DCPower connect powerModule.dcOutput to controlProcessor.dcInput;
        connection powerToGenerator : DCPower connect powerModule.dcOutput to fieldGenerator.dcInput;

        connection cmdToGenerator : FieldCommand connect controlProcessor.fieldCmd to fieldGenerator.command;

        connection waveToAnterior : DCPower connect fieldGenerator.waveformAnterior to anteriorArray.waveform;
        connection waveToPosterior : DCPower connect fieldGenerator.waveformPosterior to posteriorArray.waveform;
        connection waveToLeft : DCPower connect fieldGenerator.waveformLeft to leftArray.waveform;
        connection waveToRight : DCPower connect fieldGenerator.waveformRight to rightArray.waveform;

        connection tempAnteriorToProc : TemperatureReading connect anteriorArray.tempReading to controlProcessor.tempReadings[0];
        connection tempPosteriorToProc : TemperatureReading connect posteriorArray.tempReading to controlProcessor.tempReadings[1];
        connection tempLeftToProc : TemperatureReading connect leftArray.tempReading to controlProcessor.tempReadings[2];
        connection tempRightToProc : TemperatureReading connect rightArray.tempReading to controlProcessor.tempReadings[3];
    }

}
