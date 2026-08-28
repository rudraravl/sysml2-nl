package 'HighPrecisionPositionSensingUnit' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def RawVoltage3D {
        attribute x : ElectricPotentialValue;
        attribute y : ElectricPotentialValue;
        attribute z : ElectricPotentialValue;
    }

    item def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def CalibrationParameters {
        attribute offsetX : LengthValue;
        attribute offsetY : LengthValue;
        attribute offsetZ : LengthValue;
        attribute scaleX : Real;
        attribute scaleY : Real;
        attribute scaleZ : Real;
        attribute rotX : Real;
        attribute rotY : Real;
        attribute rotZ : Real;
    }

    attribute def PowerOnSignal;
    attribute def InitCompleteSignal;
    attribute def CalibrationCompleteSignal;
    attribute def MeasurementCommand;
    attribute def StopCommand;
    attribute def RecalibrateCommand;
    attribute def ResetCommand;
    attribute def ErrorSignal;

    port def ExternalPowerPort {
        in voltage : ElectricPotentialValue;
    }
    port def RegulatedPowerPort {
        out voltage : ElectricPotentialValue;
    }
    port def RegulatedPowerInPort {
        in voltage : ElectricPotentialValue;
    }
    port def RawOutPort {
        out raw : RawVoltage3D;
    }
    port def RawInPort {
        in raw : RawVoltage3D;
    }
    port def CalibOutPort {
        out params : CalibrationParameters;
    }
    port def CalibInPort {
        in params : CalibrationParameters;
    }
    port def PositionOutPort {
        out position : Position3D;
    }
    port def PositionInPort {
        in position : Position3D;
    }
    port def ReferenceInPort {
        in reference : Position3D;
    }
    port def RS485Port {
        out position : Position3D;
    }

    action def InitializeHardware;
    action def ExecuteCalibration;
    action def ReportMeasurement;
    action def CaptureRawSignals {
        out raw : RawVoltage3D;
    }
    action def ProcessAndFilterSignals {
        in raw : RawVoltage3D;
        in calib : CalibrationParameters;
        out position : Position3D;
    }
    action def ComputeCalibrationParams {
        in reference : Position3D;
        in rawReading : RawVoltage3D;
        out params : CalibrationParameters;
    }
    action def ConvertPower {
        in input : ElectricPotentialValue;
        out output : ElectricPotentialValue;
    }

    part def SensingElement {
        doc /* Captures raw positional information as analog voltage signals corresponding to the X, Y, and Z axes. */
        port rawOut : RawOutPort;
        perform action capture : CaptureRawSignals;
    }

    part def SignalProcessor {
        doc /* Converts raw voltages into distance measurements, applies digital noise filtering, and corrects data using calibration parameters. */
        port rawIn : RawInPort;
        port calibIn : CalibInPort;
        port positionOut : PositionOutPort;
        perform action process : ProcessAndFilterSignals;
    }

    part def CalibrationModule {
        doc /* Calculates offsets, scaling factors, and rotational misalignment by comparing sensor readings to a known reference position. */
        port referenceIn : ReferenceInPort;
        port rawIn : RawInPort;
        port paramsOut : CalibOutPort;
        perform action compute : ComputeCalibrationParams;
    }

    part def PositionSensor {
        doc /* A sophisticated position sensor composed of a sensing element, a signal processor, and a calibration module. */
        part sensingElement : SensingElement;
        part signalProcessor : SignalProcessor;
        part calibrationModule : CalibrationModule;
        port powerIn : RegulatedPowerInPort;
        port referenceIn : ReferenceInPort;
        port positionOut : PositionOutPort;
        connect sensingElement.rawOut to signalProcessor.rawIn;
        connect sensingElement.rawOut to calibrationModule.rawIn;
        connect calibrationModule.paramsOut to signalProcessor.calibIn;
        connect referenceIn to calibrationModule.referenceIn;
        connect signalProcessor.positionOut to positionOut;
    }

    part def PowerSupply {
        doc /* Internal power supply that operates from an external 24V source and provides regulated power to the unit. */
        port extPower : ExternalPowerPort;
        port regulatedOut : RegulatedPowerPort;
        perform action convert : ConvertPower;
    }

    part def DataAcquisitionInterface {
        doc /* Communicates final high-accuracy position measurements to an external system using the RS485 protocol at 100 Hz. */
        port powerIn : RegulatedPowerInPort;
        port positionIn : PositionInPort;
        port dataOut : RS485Port;
        attribute frequency : FrequencyValue = 100 [Hz];
        perform action report : ReportMeasurement;
    }

    part def PositionSensingUnit {
        doc /* A self-contained high-precision position sensing unit integrating a position sensor, a dedicated power supply, and a data acquisition interface. */
        part powerSupply : PowerSupply;
        part positionSensor : PositionSensor;
        part dataInterface : DataAcquisitionInterface;
        port extPower : ExternalPowerPort;
        port dataPort : RS485Port;
        attribute accuracy : LengthValue = 1 [mm];
        attribute range : LengthValue = 10 [m];
        action initHardware : InitializeHardware;
        action executeCalibration : ExecuteCalibration;
        action reportMeasurement : ReportMeasurement;
        connect extPower to powerSupply.extPower;
        connect powerSupply.regulatedOut to positionSensor.powerIn;
        connect powerSupply.regulatedOut to dataInterface.powerIn;
        connect positionSensor.positionOut to dataInterface.positionIn;
        connect dataInterface.dataOut to dataPort;
        exhibit state unitStates {
            entry; then off;
            state off;
            accept PowerOnSignal
                then initializing;
            state initializing {
                entry initHardware;
            }
            accept InitCompleteSignal
                then calibrating;
            accept ErrorSignal
                then fault;
            state calibrating {
                entry executeCalibration;
            }
            accept CalibrationCompleteSignal
                then ready;
            accept ErrorSignal
                then fault;
            state ready;
            accept MeasurementCommand
                then active;
            accept RecalibrateCommand
                then calibrating;
            accept ErrorSignal
                then fault;
            state active {
                do reportMeasurement;
            }
            accept StopCommand
                then ready;
            accept RecalibrateCommand
                then calibrating;
            accept ErrorSignal
                then fault;
            state fault;
            accept ResetCommand
                then off;
        }
    }

    part positionSensingUnit : PositionSensingUnit;

    requirement def PositionAccuracyRequirement {
        doc /* The system shall provide position measurements with an accuracy of 1 millimeter or better. */
        subject sensingUnit : PositionSensingUnit;
        constraint { sensingUnit.accuracy <= 1 [mm] }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The system shall be able to measure positions over a range of at least 10 meters. */
        subject sensingUnit : PositionSensingUnit;
        constraint { sensingUnit.range >= 10 [m] }
    }

    requirement def DataRateRequirement {
        doc /* The data acquisition interface shall communicate using the RS485 protocol at a rate of at least 100 Hz. */
        subject iface : DataAcquisitionInterface;
        constraint { iface.frequency >= 100 [Hz] }
    }

    requirement def PowerSourceRequirement {
        doc /* The internal power supply shall operate from an external 24V source. */
        subject supply : PowerSupply;
        constraint { supply.extPower.voltage == 24 [V] }
    }

    requirement accuracyReq : PositionAccuracyRequirement {
        subject sensingUnit = positionSensingUnit;
    }

    requirement rangeReq : MeasurementRangeRequirement {
        subject sensingUnit = positionSensingUnit;
    }

    requirement dataRateReq : DataRateRequirement {
        subject iface = positionSensingUnit.dataInterface;
    }

    requirement powerReq : PowerSourceRequirement {
        subject supply = positionSensingUnit.powerSupply;
    }
}
