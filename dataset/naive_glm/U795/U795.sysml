package OpticalPositionSensingUnitModel {
    import ScalarValues::*;

    value type LengthMM :> Real { unit "mm"; }
    value type FrequencyHz :> Real { unit "Hz"; }
    value type WavelengthNm :> Real { unit "nm"; }
    value type VoltageV :> Real { unit "V"; }
    value type CurrentmA :> Real { unit "mA"; }
    value type PowermW :> Real { unit "mW"; }
    value type TimeMs :> Real { unit "ms"; }
    value type PixelCount :> Integer;
    value type PixelIndex :> Integer;
    value type IntensityValue :> Real;

    item def LaserBeam {
        attribute wavelength : WavelengthNm = 650;
        attribute power : PowermW;
        attribute color : String = "red";
    }

    item def ReflectedLight {
        attribute intensity : IntensityValue;
        attribute spotPixel : PixelIndex;
    }

    item def PixelData {
        attribute values : Integer[2048];
        attribute frameIndex : Integer;
    }

    item def PositionMeasurement {
        attribute value : LengthMM;
        attribute timestamp : TimeMs;
        attribute confidence : Real;
        attribute sequenceId : Integer;
    }

    item def ElectricalPower {
        attribute voltage : VoltageV;
        attribute current : CurrentmA;
    }

    item def CommandSignal {
        attribute command : String;
        attribute parameter : Real = 0;
    }

    item def StatusReport {
        attribute currentState : String;
        attribute errorCode : Integer = 0;
        attribute uptime : TimeMs;
    }

    port def PowerPort {
        attribute in supplied : ElectricalPower;
    }

    port def CommandPort {
        attribute in command : CommandSignal;
        attribute out status : StatusReport;
    }

    port def MeasurementPort {
        attribute out measurement : PositionMeasurement;
    }

    port def OpticalEmissionPort {
        attribute out beam : LaserBeam;
    }

    port def OpticalReceptionPort {
        attribute in reflected : ReflectedLight;
    }

    port def PixelDataPort {
        attribute out pixels : PixelData;
    }

    port def InternalPowerPort {
        attribute out regulated : ElectricalPower;
    }

    part def LaserEmitter {
        port emissionPort : OpticalEmissionPort;
        port powerIn : InternalPowerPort;
        attribute wavelength : WavelengthNm = 650;
        attribute maxPower : PowermW = 5.0;
        attribute enabled : Boolean = false;

        action def EmitBeam {
            in voltage : VoltageV;
            out beam : LaserBeam;
        }

        perform action emitBeam : EmitBeam {
            when enabled;
        }
    }

    part def OpticalWindow {
        port inPort : OpticalEmissionPort;
        port outPort : OpticalEmissionPort;
        port returnInPort : OpticalReceptionPort;
        port returnOutPort : OpticalReceptionPort;
        attribute transmittance : Real = 0.95;
        attribute material : String = "reinforced glass";
        attribute thickness : LengthMM = 3.0;

        action def TransmitBeam {
            in incoming : LaserBeam;
            out outgoing : LaserBeam;
        }

        perform action transmit : TransmitBeam;
    }

    part def PhotodetectorArray {
        port receptionPort : OpticalReceptionPort;
        port dataPort : PixelDataPort;
        attribute pixelCount : PixelCount = 2048;
        attribute pixelWidth : LengthMM = 0.014;
        attribute integrationTime : TimeMs = 0.5;
        attribute saturationLevel : IntensityValue = 1000.0;

        action def CaptureImage {
            in reflected : ReflectedLight;
            out pixelData : PixelData;
        }

        perform action capture : CaptureImage;
    }

    part def PositionCalculator {
        port dataIn : PixelDataPort;
        port measurementPort : MeasurementPort;
        attribute algorithm : String = "Centroid";
        attribute updateRate : FrequencyHz = 1000;
        attribute resolution : LengthMM = 0.05;
        attribute range : LengthMM = 2000;
        attribute calibrationOffset : LengthMM = 0;

        action def ComputeCentroid {
            in pixelData : PixelData;
            out centroid : PixelIndex;
        }

        action def CalculatePosition {
            in centroid : PixelIndex;
            out position : PositionMeasurement;
        }

        perform action computeCentroid : ComputeCentroid;
        perform action calculatePosition : CalculatePosition;
    }

    part def MountingInterface {
        attribute holeCount : Integer = 4;
        attribute threadSize : String = "M6";
        attribute holeSpacing : LengthMM = 40;
        attribute torqueRating : Real = 8.0;
    }

    part def Housing {
        attribute material : String = "anodized aluminum";
        attribute protectionRating : String = "IP65";
        attribute length : LengthMM = 120;
        attribute width : LengthMM = 60;
        attribute height : LengthMM = 40;
        part mountingInterface : MountingInterface;
    }

    part def PowerSupply {
        port powerPort : PowerPort;
        port regulatedOut : InternalPowerPort;
        attribute inputVoltage : VoltageV = 24;
        attribute maxCurrent : CurrentmA = 500;
        attribute regulatedVoltage : VoltageV = 5;
        attribute efficiency : Real = 0.92;
    }

    part def ControlInterface {
        port commandPort : CommandPort;
        attribute protocol : String = "RS-485";
        attribute baudRate : Integer = 115200;
        attribute address : Integer = 1;
    }

    state def OperationalLifecycle {
        entry; then idle;

        state idle {
            entry action { /* initialize subsystems, disable laser */ }
        }

        state activeMeasuring {
            entry action { /* enable laser, begin continuous capture */ }
        }

        state calibration {
            entry action { /* run centroid offset calibration */ }
        }

        state faultMode {
            entry action { /* disable laser, report error code */ }
        }

        transition from idle to activeMeasuring
            when commandPort.command.command == "start";

        transition from activeMeasuring to idle
            when commandPort.command.command == "stop";

        transition from idle to calibration
            when commandPort.command.command == "calibrate";

        transition from calibration to idle
            when commandPort.command.command == "done";

        transition from activeMeasuring to faultMode
            when faultDetected;

        transition from idle to faultMode
            when faultDetected;

        transition from calibration to faultMode
            when faultDetected;

        transition from faultMode to idle
            when commandPort.command.command == "reset";
    }

    part def OpticalPositionSensingUnit {
        port powerPort : PowerPort;
        port commandPort : CommandPort;
        port measurementPort : MeasurementPort;

        attribute faultDetected : Boolean = false;
        attribute serialNumber : String;
        attribute firmwareVersion : String = "1.0.0";

        part laserEmitter : LaserEmitter;
        part opticalWindow : OpticalWindow;
        part photodetectorArray : PhotodetectorArray;
        part positionCalculator : PositionCalculator;
        part housing : Housing;
        part powerSupply : PowerSupply;
        part controlInterface : ControlInterface;

        exhibit state operationalState : OperationalLifecycle;

        connection powerInput connect powerPort to powerSupply.powerPort;
        connection commandInput connect commandPort to controlInterface.commandPort;
        connection regulatedPower connect powerSupply.regulatedOut to laserEmitter.powerIn;
        connection laserEmission connect laserEmitter.emissionPort to opticalWindow.inPort;
        connection windowReturn connect opticalWindow.returnOutPort to photodetectorArray.receptionPort;
        connection pixelStream connect photodetectorArray.dataPort to positionCalculator.dataIn;
        connection measurementOutput connect positionCalculator.measurementPort to measurementPort;
    }

    requirement def MeasurementPerformanceRequirement {
        subject sensor : OpticalPositionSensingUnit;
        attribute requiredUpdateRate : FrequencyHz = 1000;
        attribute requiredResolution : LengthMM = 0.05;
        attribute requiredRange : LengthMM = 2000;

        require constraint {
            sensor.positionCalculator.updateRate >= requiredUpdateRate and
            sensor.positionCalculator.resolution <= requiredResolution and
            sensor.positionCalculator.range >= requiredRange
        }
    }

    requirement def LaserSpecificationRequirement {
        subject emitter : LaserEmitter;
        attribute requiredWavelength : WavelengthNm = 650;
        attribute maxAllowedPower : PowermW = 5.0;

        require constraint {
            emitter.wavelength == requiredWavelength and
            emitter.maxPower <= maxAllowedPower
        }
    }

    requirement def DetectorSpecificationRequirement {
        subject detector : PhotodetectorArray;
        attribute requiredPixelCount : PixelCount = 2048;

        require constraint {
            detector.pixelCount == requiredPixelCount
        }
    }

    requirement def HousingRequirement {
        subject housing : Housing;
        attribute requiredHoleCount : Integer = 4;
        attribute requiredProtection : String = "IP65";

        require constraint {
            housing.mountingInterface.holeCount == requiredHoleCount and
            housing.protectionRating == requiredProtection
        }
    }

    requirement def OperationalStatesRequirement {
        subject sensor : OpticalPositionSensingUnit;
        attribute requiredStates : String = "idle, activeMeasuring, calibration, faultMode";

        require constraint {
            sensor.operationalState.idle.occurrence and
            sensor.operationalState.activeMeasuring.occurrence and
            sensor.operationalState.calibration.occurrence and
            sensor.operationalState.faultMode.occurrence
        }
    }

    requirement def PowerRequirement {
        subject sensor : OpticalPositionSensingUnit;
        attribute requiredVoltage : VoltageV = 24;

        require constraint {
            sensor.powerSupply.inputVoltage == requiredVoltage
        }
    }

    requirement def ContinuousDataStreamRequirement {
        subject sensor : OpticalPositionSensingUnit;
        attribute minUpdateRate : FrequencyHz = 1000;

        require constraint {
            sensor.positionCalculator.updateRate >= minUpdateRate
        }
    }
}
