package 'Non-Contact Pyrometer System' {
    private import ScalarValues::*;

    attribute def TemperatureValue :> Real;
    attribute def IrradianceValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def EmissivityValue :> Real;
    attribute def WavelengthValue :> Real;
    attribute def FrequencyValue :> Real;

    item def ThermalRadiation {
        attribute spectralRadiance : IrradianceValue;
        attribute wavelength : WavelengthValue;
    }

    item def RawSignal {
        attribute voltage : VoltageValue;
        attribute noiseLevel : VoltageValue;
    }

    item def ProcessedSignal {
        attribute voltage : VoltageValue;
        attribute calibrated : Boolean;
    }

    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute valid : Boolean;
        attribute qualityFlag : String;
    }

    port def RadiationInputPort {
        in radiation : ThermalRadiation;
    }

    port def RadiationOutputPort {
        out radiation : ThermalRadiation;
    }

    port def RawSignalPort {
        out signal : RawSignal;
    }

    port def RawSignalInPort {
        in signal : RawSignal;
    }

    port def ProcessedSignalPort {
        out signal : ProcessedSignal;
    }

    port def ProcessedSignalInPort {
        in signal : ProcessedSignal;
    }

    port def TemperatureOutputPort {
        out reading : TemperatureReading;
    }

    port def TemperatureInputPort {
        in reading : TemperatureReading;
    }

    port def CommandPort {
        in startCmd : Boolean;
        in stopCmd : Boolean;
        in calibrateCmd : Boolean;
        in resetCmd : Boolean;
        in emissivitySetting : EmissivityValue;
    }

    action def CollectRadiation {
        in incoming : ThermalRadiation;
        out focused : ThermalRadiation;
    }

    action def ConvertRadiation {
        in radiation : ThermalRadiation;
        out signal : RawSignal;
    }

    action def ProcessSignal {
        in raw : RawSignal;
        out processed : ProcessedSignal;
    }

    action def CalculateTemperature {
        in signal : ProcessedSignal;
        in emissivity : EmissivityValue;
        out reading : TemperatureReading;
    }

    action def UpdateDisplay {
        in reading : TemperatureReading;
    }

    action def MeasureTemperature {
        in radiation : ThermalRadiation;
        in emissivity : EmissivityValue;
        out reading : TemperatureReading;
        action collect : CollectRadiation;
        action convert : ConvertRadiation;
        action process : ProcessSignal;
        action calculate : CalculateTemperature;
        action display : UpdateDisplay;
        then done;
    }

    action def PerformMeasurement;
    action def RunCalibration;
    action def LogFault;

    part def OpticalSystem {
        attribute focalLength : Real;
        attribute apertureDiameter : Real;
        port radiationIn : RadiationInputPort;
        port focusedRadiationOut : RadiationOutputPort;
        perform CollectRadiation {
            in incoming = radiationIn.radiation;
            out focused = focusedRadiationOut.radiation;
        }
    }

    part def InfraredDetector {
        attribute sensitivityRangeMin : WavelengthValue;
        attribute sensitivityRangeMax : WavelengthValue;
        attribute responsivity : Real;
        port radiationIn : RadiationInputPort;
        port signalOut : RawSignalPort;
        perform ConvertRadiation {
            in radiation = radiationIn.radiation;
            out signal = signalOut.signal;
        }
    }

    part def SignalProcessor {
        attribute gain : Real;
        attribute filterCutoff : FrequencyValue;
        attribute calibrationOffset : VoltageValue;
        port signalIn : RawSignalInPort;
        port signalOut : ProcessedSignalPort;
        perform ProcessSignal {
            in raw = signalIn.signal;
            out processed = signalOut.signal;
        }
    }

    part def TemperatureComputer {
        attribute emissivity : EmissivityValue = 0.95;
        attribute minValidSignal : VoltageValue;
        attribute maxValidSignal : VoltageValue;
        port signalIn : ProcessedSignalInPort;
        port tempOut : TemperatureOutputPort;
        port cmdPort : CommandPort;
        perform CalculateTemperature {
            in signal = signalIn.signal;
            in emissivity = cmdPort.emissivitySetting;
            out reading = tempOut.reading;
        }
    }

    part def DisplayController {
        attribute refreshRate : FrequencyValue = 10;
        port tempIn : TemperatureInputPort;
        perform UpdateDisplay {
            in reading = tempIn.reading;
        }
    }

    part def Pyrometer {
        attribute measurementError : TemperatureValue;
        attribute latency : Real;
        attribute measuredTemperature : TemperatureValue;

        port radiationInput : RadiationInputPort;
        port commandInput : CommandPort;
        port displayOutput : TemperatureOutputPort;

        part opticalSystem : OpticalSystem {
            port :>> radiationIn = radiationInput;
        }
        part infraredDetector : InfraredDetector {
            port :>> radiationIn;
        }
        part signalProcessor : SignalProcessor;
        part temperatureComputer : TemperatureComputer {
            port :>> cmdPort = commandInput;
        }
        part displayController : DisplayController;

        connect opticalSystem.focusedRadiationOut to infraredDetector.radiationIn;
        connect infraredDetector.signalOut to signalProcessor.signalIn;
        connect signalProcessor.signalOut to temperatureComputer.signalIn;
        connect temperatureComputer.tempOut to displayController.tempIn;
        connect temperatureComputer.tempOut to displayOutput;

        exhibit PyrometerStateMachine;
    }

    state def PyrometerStateMachine {
        entry; then Idle;

        state Idle;
        state Measuring {
            do action performMeasurement : PerformMeasurement;
        }
        state Calibrating {
            do action runCalibration : RunCalibration;
        }
        state Fault {
            do action logFault : LogFault;
        }

        transition
            first Idle
            accept startCmd : Boolean
            then Measuring;

        transition
            first Idle
            accept calibrateCmd : Boolean
            then Calibrating;

        transition
            first Measuring
            accept stopCmd : Boolean
            then Idle;

        transition
            first Measuring
            accept faultDetected : Boolean
            then Fault;

        transition
            first Calibrating
            accept calibrationComplete : Boolean
            then Idle;

        transition
            first Calibrating
            accept faultDetected : Boolean
            then Fault;

        transition
            first Fault
            accept resetCmd : Boolean
            then Idle;
    }

    requirement def TemperatureMeasurementRequirement {
        subject pyrometer : Pyrometer;
        attribute accuracy : TemperatureValue = 1;
        attribute responseTime : Real = 0.1;
        require {
            pyrometer.measurementError <= accuracy and
            pyrometer.latency <= responseTime
        }
    }

    requirement def OperatingRangeRequirement {
        subject pyrometer : Pyrometer;
        attribute minTemp : TemperatureValue = 273.15;
        attribute maxTemp : TemperatureValue = 2273.15;
        require {
            pyrometer.measuredTemperature >= minTemp and
            pyrometer.measuredTemperature <= maxTemp
        }
    }

    requirement def SignalQualityRequirement {
        subject computer : TemperatureComputer;
        require {
            computer.signalIn.signal.voltage >= computer.minValidSignal and
            computer.signalIn.signal.voltage <= computer.maxValidSignal
        }
    }

    part pyrometer : Pyrometer;

    part 'Pyrometer Analysis Context' {
        part 'Target Object' {
            attribute surfaceTemperature : TemperatureValue = 1273.15;
            attribute emissivity : EmissivityValue = 0.85;
            port radiationOut : RadiationOutputPort;
        }

        part 'Test Pyrometer' :> pyrometer;

        connect 'Target Object'.radiationOut to 'Test Pyrometer'.radiationInput;

        requirement 'Measurement Accuracy Check' :> TemperatureMeasurementRequirement {
            subject = 'Test Pyrometer';
            attribute :>> accuracy = 2;
            attribute :>> responseTime = 0.05;
        }
    }
}
