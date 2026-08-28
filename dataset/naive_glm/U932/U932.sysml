package UltrasonicThicknessGauge {

    import ScalarValues::*;
    import ISQ::Time;
    import ISQ::Length;
    import ISQ::Velocity;
    import ISQ::Frequency;
    import ISQ::ThermodynamicTemperature;
    import ISQ::ElectricPotential;
    import SI::s;
    import SI::m;

    // ===== UNITS =====
    unit us : Time = 0.000001 * s;
    unit mm : Length = 0.001 * m;
    unit m_per_s : Velocity = m / s;
    unit MHz : Frequency;
    unit degC : ThermodynamicTemperature;
    unit V : ElectricPotential;

    // ===== VALUE TYPES =====
    value type ThicknessValue :> Real {
        :>> unit = mm;
        :>> min = 0;
    }
    value type TimeOfFlight :> Real {
        :>> unit = us;
        :>> min = 0;
    }
    value type SoundVelocityValue :> Real {
        :>> unit = m_per_s;
        :>> min = 0;
    }
    value type FrequencyValue :> Real {
        :>> unit = MHz;
        :>> min = 0;
    }
    value type TemperatureValue :> Real {
        :>> unit = degC;
    }
    value type VoltageValue :> Real {
        :>> unit = V;
    }
    value type DelayValue :> Real {
        :>> unit = us;
    }

    // ===== ENUMERATIONS =====
    enum def MeasurementStatus {
        PENDING;
        VALID;
        ERROR;
    }
    enum def DeviceMode {
        OFF;
        IDLE;
        MEASURE;
        CALIBRATE;
        FAULT;
    }
    enum def MaterialKind {
        STEEL;
        ALUMINUM;
        PLASTIC;
        GLASS;
    }

    // ===== ITEMS =====
    item def ElectricalSignal {
        attribute amplitude : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute isPulse : Boolean;
    }
    item def AcousticPulse {
        attribute frequency : FrequencyValue;
        attribute intensity : Real;
        attribute isOutbound : Boolean;
    }
    item def Echo :> AcousticPulse {
        attribute amplitude : Real;
        attribute isNoise : Boolean;
    }
    item def MaterialProfile {
        attribute kind : MaterialKind;
        attribute velocity : SoundVelocityValue;
        attribute tempCoefficient : Real;
    }
    item def MeasurementResult {
        attribute thickness : ThicknessValue;
        attribute status : MeasurementStatus;
        attribute mode : DeviceMode;
    }

    // ===== PORTS =====
    port def ElectricalDriveOutPort {
        out signal : ElectricalSignal;
    }
    port def ElectricalDriveInPort {
        in signal : ElectricalSignal;
    }
    port def ElectricalEchoOutPort {
        out signal : ElectricalSignal;
    }
    port def ElectricalEchoInPort {
        in signal : ElectricalSignal;
    }
    port def AcousticPort {
        out pulse : AcousticPulse;
        in echo : Echo;
    }
    port def TofOutPort {
        out tof : TimeOfFlight;
    }
    port def TofInPort {
        in tof : TimeOfFlight;
    }
    port def CommandPort {
        in command : String;
    }
    port def DisplayInPort {
        in result : MeasurementResult;
    }
    port def DisplayOutPort {
        out result : MeasurementResult;
    }
    port def CalibDataInPort {
        in referenceThickness : ThicknessValue;
        in material : MaterialProfile;
    }
    port def MaterialOutPort {
        out material : MaterialProfile;
    }
    port def MaterialInPort {
        in material : MaterialProfile;
    }
    port def TemperatureOutPort {
        out temperature : TemperatureValue;
    }
    port def TemperatureInPort {
        in temperature : TemperatureValue;
    }
    port def TriggerOutPort {
        out trigger : Boolean;
    }
    port def TriggerInPort {
        in trigger : Boolean;
    }
    port def ModeOutPort {
        out mode : DeviceMode;
    }

    // ===== PARTS =====
    part def Transducer {
        attribute nominalFrequency : FrequencyValue = 5;
        attribute isCoupled : Boolean = false;
        attribute couplingEfficiency : Real = 0.85;
        attribute hasPulse : Boolean = false;
        attribute echoReceived : Boolean = false;
        port acoustic : AcousticPort;
        port driveIn : ElectricalDriveInPort;
        port echoOut : ElectricalEchoOutPort;

        action def ConvertElectricalToAcoustic {
            in signal : ElectricalSignal;
            out pulse : AcousticPulse;
        }
        action def ConvertAcousticToElectrical {
            in echo : Echo;
            out signal : ElectricalSignal;
        }
        action def TransmitPulse {
            in signal : ElectricalSignal;
            out pulse : AcousticPulse;
        }
        action def ReceiveEcho {
            in echo : Echo;
            out signal : ElectricalSignal;
        }

        state machine TransducerStateMachine {
            state Idle;
            state Transmitting;
            state Receiving;
            transition from Idle to Transmitting when hasPulse == true;
            transition from Transmitting to Receiving when true;
            transition from Receiving to Idle when echoReceived == true;
        }
    }

    part def PulseGenerator {
        attribute pulseVoltage : VoltageValue = 100;
        attribute pulseDuration : DelayValue = 0.1;
        attribute isTriggered : Boolean = false;
        port driveOut : ElectricalDriveOutPort;
        port triggerIn : TriggerInPort;

        action def GeneratePulse {
            in trigger : Boolean;
            out signal : ElectricalSignal;
        }
    }

    part def SignalProcessor {
        attribute gain : Real = 1000;
        attribute bandwidth : FrequencyValue = 10;
        attribute noiseThreshold : Real = 0.01;
        attribute detectedTof : TimeOfFlight;
        attribute isReceiving : Boolean = false;
        port signalIn : ElectricalEchoInPort;
        port tofOut : TofOutPort;

        action def AmplifySignal {
            in signal : ElectricalSignal;
            out amplified : ElectricalSignal;
        }
        action def FilterNoise {
            in signal : ElectricalSignal;
            out filtered : ElectricalSignal;
        }
        action def DetectTimeOfFlight {
            in signal : ElectricalSignal;
            out tof : TimeOfFlight;
        }

        state machine ProcessingStateMachine {
            state Idle;
            state Amplifying;
            state Filtering;
            state Detecting;
            transition from Idle to Amplifying when isReceiving == true;
            transition from Amplifying to Filtering when true;
            transition from Filtering to Detecting when true;
            transition from Detecting to Idle when detectedTof > 0;
        }
    }

    part def ThicknessCalculator {
        attribute soundVelocity : SoundVelocityValue = 5900;
        attribute currentTemperature : TemperatureValue = 20;
        attribute useTempCompensation : Boolean = true;
        attribute tempCoefficient : Real = 0.0001;
        attribute computedThickness : ThicknessValue;
        attribute lastResult : MeasurementResult;
        port tofIn : TofInPort;
        port materialIn : MaterialInPort;
        port tempIn : TemperatureInPort;
        port resultOut : DisplayOutPort;

        action def CalculateThickness {
            in tof : TimeOfFlight;
            in velocity : SoundVelocityValue;
            in temperature : TemperatureValue;
            in tempCompensation : Boolean;
            in tempCoef : Real;
            out thickness : ThicknessValue;
        }

        constraint def ThicknessEquation {
            in tof : TimeOfFlight;
            in velocity : SoundVelocityValue;
            in temperature : TemperatureValue;
            in tempCompensation : Boolean;
            in tempCoef : Real;
            out thickness : ThicknessValue;
            require {
                thickness == tof * velocity * 0.0005
                    * (1.0 + (if tempCompensation then tempCoef * (temperature - 20.0) else 0.0));
            }
        }
    }

    part def CalibrationModule {
        attribute offset : DelayValue = 0;
        attribute knownMaterials : MaterialProfile[0..3];
        attribute currentMaterial : MaterialProfile;
        attribute lastCommand : String = "";
        attribute referenceThickness : ThicknessValue;
        port calibData : CalibDataInPort;
        port materialOut : MaterialOutPort;
        port tempOut : TemperatureOutPort;

        action def CalibrateUsingStandard {
            in referenceThickness : ThicknessValue;
            in measuredTof : TimeOfFlight;
            in velocity : SoundVelocityValue;
            out calibrationOffset : DelayValue;
        }
        action def SelectMaterialProfile {
            in kind : MaterialKind;
            out profile : MaterialProfile;
        }
        action def MeasureTemperature {
            out temperature : TemperatureValue;
        }

        state machine CalibrationStateMachine {
            state Idle;
            state AwaitingInput;
            state MaterialLookup;
            state AdjustingOffset;
            state Complete;
            transition from Idle to AwaitingInput when lastCommand == "calibrate";
            transition from AwaitingInput to MaterialLookup when referenceThickness > 0;
            transition from MaterialLookup to AdjustingOffset when true;
            transition from AdjustingOffset to Complete when offset != 0;
            transition from Complete to Idle when lastCommand == "complete";
        }
    }

    part def DisplayUnit {
        attribute isBacklit : Boolean = true;
        attribute refreshRate : FrequencyValue = 0.06;
        attribute currentResult : MeasurementResult;
        port displayIn : DisplayInPort;

        action def RenderResult {
            in result : MeasurementResult;
        }
        action def ClearDisplay {
            in flag : Boolean;
        }
    }

    part def ControlUnit {
        attribute currentMode : DeviceMode = OFF;
        attribute lastStatus : MeasurementStatus = PENDING;
        attribute lastCommand : String = "";
        port commandIn : CommandPort;
        port modeOut : ModeOutPort;
        port triggerOut : TriggerOutPort;

        state machine ControlStateMachine {
            state Off;
            state Idle;
            state Measuring;
            state Calibrating;
            state Fault;
            transition from Off to Idle when lastCommand == "power on";
            transition from Idle to Measuring when lastCommand == "measure";
            transition from Idle to Calibrating when lastCommand == "calibrate";
            transition from Measuring to Idle when lastStatus == MeasurementStatus::VALID;
            transition from Measuring to Fault when lastStatus == MeasurementStatus::ERROR;
            transition from Calibrating to Idle when lastCommand == "complete";
            transition from Fault to Idle when lastCommand == "reset";
            transition from Idle to Off when lastCommand == "power off";
        }

        action def ProcessCommand {
            in command : String;
            out mode : DeviceMode;
            out trigger : Boolean;
        }
    }

    // ===== TOP-LEVEL GAUGE ASSEMBLY =====
    part def Gauge {
        attribute isHandheld : Boolean = true;
        attribute isNonDestructive : Boolean = true;
        attribute brand : String = "UTG-5000";
        attribute supportedMaterials : MaterialKind[1..*];
        port acousticProbe : AcousticPort;
        port userCommand : CommandPort;

        part controlUnit : ControlUnit;
        part pulseGen : PulseGenerator;
        part transducer : Transducer;
        part sigProc : SignalProcessor;
        part thicknessCalc : ThicknessCalculator;
        part calibModule : CalibrationModule;
        part display : DisplayUnit;

        connection userCmd from userCommand to controlUnit.commandIn;
        connection probeBinding from acousticProbe to transducer.acoustic;
        connection ctrlPulse from controlUnit.triggerOut to pulseGen.triggerIn;
        connection pulseTrans from pulseGen.driveOut to transducer.driveIn;
        connection transSigProc from transducer.echoOut to sigProc.signalIn;
        connection sigCalc from sigProc.tofOut to thicknessCalc.tofIn;
        connection calibCalcMat from calibModule.materialOut to thicknessCalc.materialIn;
        connection calibCalcTemp from calibModule.tempOut to thicknessCalc.tempIn;
        connection calcDisp from thicknessCalc.resultOut to display.displayIn;
    }

    // ===== REQUIREMENTS =====
    requirement def MeasuringNonDestructively {
        doc "The instrument shall measure material thickness without damaging the tested component.";
        subject instrument : Gauge;
        require {
            instrument.isNonDestructive == true;
        }
    }

    requirement def MeasuringHandheld {
        doc "The instrument shall be a handheld, portable device suitable for field use.";
        subject instrument : Gauge;
        require {
            instrument.isHandheld == true;
        }
    }

    requirement def PulseEmission {
        doc "The pulse generator shall emit a high-frequency ultrasonic pulse into the material under test.";
        subject generator : PulseGenerator;
        attribute minPulseVoltage : VoltageValue = 50;
        require {
            generator.pulseVoltage >= minPulseVoltage;
            generator.pulseDuration > 0;
        }
    }

    requirement def EchoDetection {
        doc "The transducer shall both transmit the ultrasonic pulse and receive the returning echo from the material's back wall.";
        subject transducer : Transducer;
        require {
            transducer.nominalFrequency > 0;
            transducer.couplingEfficiency > 0;
        }
    }

    requirement def TimeOfFlightIdentification {
        doc "The signal processor shall amplify, filter, and identify the time-of-flight of the returning echo.";
        subject processor : SignalProcessor;
        require {
            processor.gain > 0;
            processor.bandwidth > 0;
            processor.noiseThreshold >= 0;
        }
    }

    requirement def ThicknessCalculation {
        doc "The thickness calculator shall use the time-of-flight and pre-configured sound velocity to compute material thickness.";
        subject calculator : ThicknessCalculator;
        require {
            calculator.soundVelocity > 0;
        }
    }

    requirement def TemperatureCompensation {
        doc "The thickness calculation shall compensate for temperature changes when enabled by the user.";
        subject calculator : ThicknessCalculator;
        require {
            calculator.useTempCompensation implies calculator.tempCoefficient != 0;
        }
    }

    requirement def Calibration {
        doc "The calibration module shall allow the user to fine-tune the device using a reference standard of known thickness or by selecting a material from a pre-loaded library.";
        subject calibModule : CalibrationModule;
        require {
            calibModule.knownMaterials->size() > 0;
        }
    }

    requirement def DisplayResult {
        doc "The display unit shall show the calculated thickness value and the measurement status to the user.";
        subject displayUnit : DisplayUnit;
        require {
            displayUnit.isBacklit == true;
            displayUnit.refreshRate > 0;
        }
    }

    requirement def UserCommandControl {
        doc "The control unit shall manage overall device operation based on user commands such as initiating a measurement or running a calibration.";
        subject control : ControlUnit;
        require {
            control.currentMode in { DeviceMode::OFF, DeviceMode::IDLE, DeviceMode::MEASURE, DeviceMode::CALIBRATE, DeviceMode::FAULT };
        }
    }

    requirement def IndustrialInspectionSuitability {
        doc "The instrument shall be suitable for industrial inspection of pipes, storage tanks, and ship hulls to detect corrosion or erosion.";
        subject instrument : Gauge;
        require {
            instrument.supportedMaterials->size() >= 3;
            instrument.isNonDestructive == true;
            instrument.isHandheld == true;
        }
    }

    // ===== SATISFACTION =====
    part utgDevice : Gauge {
        satisfy r1 : MeasuringNonDestructively;
        satisfy r2 : MeasuringHandheld;
        satisfy r3 : PulseEmission on pulseGen;
        satisfy r4 : EchoDetection on transducer;
        satisfy r5 : TimeOfFlightIdentification on sigProc;
        satisfy r6 : ThicknessCalculation on thicknessCalc;
        satisfy r7 : TemperatureCompensation on thicknessCalc;
        satisfy r8 : Calibration on calibModule;
        satisfy r9 : DisplayResult on display;
        satisfy r10 : UserCommandControl on controlUnit;
        satisfy r11 : IndustrialInspectionSuitability;
    }
}
