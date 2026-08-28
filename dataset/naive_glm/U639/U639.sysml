package DocumentScannerSensingUnit {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value type ResolutionDpi :> Real { doc "Dots per inch" }
    value type LengthInches :> Real { doc "Length in inches" }
    value type VoltageMillivolts :> Real { doc "Voltage in millivolts" }
    value type VoltageVolts :> Real { doc "Voltage in volts" }
    value type CurrentMicroamps :> Real { doc "Current in microamperes" }
    value type FrequencyHz :> Real { doc "Frequency in hertz" }
    value type TimeMilliseconds :> Real { doc "Time in milliseconds" }
    value type PositionAccuracyMicrons :> Real { doc "Positioning accuracy in micrometers" }
    value type Lux :> Real { doc "Illuminance in lux" }
    value type BitDepth :> Integer { doc "ADC bit depth" }
    value type LineCount :> Integer { doc "Number of scanned lines" }
    value type PixelCount :> Integer { doc "Number of pixels per line" }

    // ---- Item Definitions ----
    item def PhysicalDocument {
        attribute width : LengthInches;
        attribute height : LengthInches;
    }

    item def ReflectedLight {
        attribute intensity : Lux;
        attribute lineNumber : LineCount;
    }

    item def AnalogLineSignal {
        attribute lineNumber : LineCount;
        attribute pixelCount : PixelCount;
        attribute voltageLevels : VoltageMillivolts[0..*];
    }

    item def DigitalLineData {
        attribute lineNumber : LineCount;
        attribute pixelCount : PixelCount;
        attribute bitDepth : BitDepth;
        attribute pixelValues : Integer[0..*];
    }

    item def ProcessedLineData {
        attribute lineNumber : LineCount;
        attribute pixelCount : PixelCount;
        attribute bitDepth : BitDepth;
        attribute correctedPixelValues : Integer[0..*];
    }

    item def DigitalImage {
        attribute widthPixels : PixelCount;
        attribute heightPixels : LineCount;
        attribute bitDepth : BitDepth;
        attribute pixelData : Integer[0..*];
    }

    item def IlluminationCommand {
        attribute enable : Boolean;
        attribute lineNumber : LineCount;
    }

    item def TransportCommand {
        attribute advanceLines : LineCount;
        attribute speed : FrequencyHz;
    }

    // ---- Port Definitions ----
    port def DocumentPort {
        out item document : PhysicalDocument;
    }

    port def LightOutputPort {
        out item reflected : ReflectedLight;
    }

    port def LightInputPort {
        in item reflected : ReflectedLight;
    }

    port def AnalogSignalPort {
        out item lineSignal : AnalogLineSignal;
    }

    port def AnalogInputPort {
        in item lineSignal : AnalogLineSignal;
    }

    port def DigitalLinePort {
        out item digitalLine : DigitalLineData;
    }

    port def DigitalLineInputPort {
        in item digitalLine : DigitalLineData;
    }

    port def ProcessedLinePort {
        out item processedLine : ProcessedLineData;
    }

    port def ProcessedLineInputPort {
        in item processedLine : ProcessedLineData;
    }

    port def ImageOutputPort {
        out item image : DigitalImage;
    }

    port def ControlPort {
        in item transportCmd : TransportCommand;
        in item illuminationCmd : IlluminationCommand;
    }

    // ---- Requirements ----
    requirement def MinResolutionRequirement {
        doc "The scanner must achieve at least the specified optical resolution."
        attribute minHorizontalDpi : ResolutionDpi = 600;
        attribute minVerticalDpi : ResolutionDpi = 600;
        require { (resolutionHorizontal >= minHorizontalDpi) and (resolutionVertical >= minVerticalDpi) }
        attribute resolutionHorizontal : ResolutionDpi;
        attribute resolutionVertical : ResolutionDpi;
    }

    requirement def OpticalQualityRequirement {
        doc "The Selfoc lens array and optical path must meet minimum quality standards."
        attribute minModulationTransfer : Real = 0.6;
        attribute maxDistortionPercent : Real = 2.0;
        require { (modulationTransfer >= minModulationTransfer) and (distortionPercent <= maxDistortionPercent) }
        attribute modulationTransfer : Real;
        attribute distortionPercent : Real;
    }

    requirement def MechanicalPositioningRequirement {
        doc "The transport mechanism must position paper with specified accuracy."
        attribute maxPositionError : PositionAccuracyMicrons = 20;
        require { positionError <= maxPositionError }
        attribute positionError : PositionAccuracyMicrons;
    }

    requirement def ADCPrecisionRequirement {
        doc "The ADC must convert analog signals with at least the specified bit depth."
        attribute minBitDepth : BitDepth = 12;
        require { adcBitDepth >= minBitDepth }
        attribute adcBitDepth : BitDepth;
    }

    requirement def ScanSpeedRequirement {
        doc "The scanner must complete a full page scan within the specified time."
        attribute maxScanTimePerPage : TimeMilliseconds = 5000;
        require { scanTimePerPage <= maxScanTimePerPage }
        attribute scanTimePerPage : TimeMilliseconds;
    }

    // ---- Part Definitions ----

    part def LEDArray {
        doc "Illumination source using LEDs to light a narrow strip of the document."
        attribute ledCount : Integer = 3;
        attribute colorTemperatureKelvin : Integer = 6500;
        attribute maxIlluminance : Lux = 5000;
        port out illumination : LightOutputPort;
        attribute currentIlluminance : Lux;
        exhibit state illuminationBehavior {
            entry; then off;
            state off;
            state on;
            transition off -> on when (enable == true);
            transition on -> off when (enable == false);
            attribute enable : Boolean;
        }
        action def IlluminateLine {
            in lineNumber : LineCount;
            out light : ReflectedLight;
        }
        perform IlluminateLine;
    }

    part def SelfocLensArray {
        doc "Gradient-index lens array focusing reflected light onto the photodiode array."
        attribute lensCount : Integer;
        attribute numericalAperture : Real = 0.45;
        port in lightInput : LightInputPort;
        port out focusedLight : LightOutputPort;
        action def FocusLight {
            in reflected : ReflectedLight;
            out focused : ReflectedLight;
        }
        perform FocusLight;
    }

    part def PhotodiodeArray {
        doc "Linear array of photodiodes converting light intensity to analog voltage."
        attribute pixelCount : PixelCount = 5100;
        attribute pixelPitchMicrons : Real = 42.3;
        attribute sensitivityAmpPerLux : Real = 0.35;
        port in incidentLight : LightInputPort;
        port out analogOut : AnalogSignalPort;
        action def ConvertLightToVoltage {
            in light : ReflectedLight;
            out signal : AnalogLineSignal;
        }
        perform ConvertLightToVoltage;
    }

    part def AnalogFrontEnd {
        doc "Amplifies and conditions weak analog signals from the photodiode array."
        attribute gain : Real = 10.0;
        attribute bandwidthHz : FrequencyHz = 200000;
        attribute noiseLevelMicrovolts : Real = 250;
        port in analogIn : AnalogInputPort;
        port out conditionedOut : AnalogSignalPort;
        action def AmplifyAndCondition {
            in rawSignal : AnalogLineSignal;
            out conditionedSignal : AnalogLineSignal;
        }
        perform AmplifyAndCondition;
    }

    part def AnalogToDigitalConverter {
        doc "Converts conditioned analog line signals into digital data."
        attribute bitDepth : BitDepth = 12;
        attribute samplingRateHz : FrequencyHz = 500000;
        attribute inputRangeVolts : VoltageVolts = 2.0;
        port in analogInput : AnalogInputPort;
        port out digitalOut : DigitalLinePort;
        action def ConvertToDigital {
            in analogSignal : AnalogLineSignal;
            out digitalData : DigitalLineData;
        }
        perform ConvertToDigital;
    }

    part def ImageProcessingUnit {
        doc "Applies corrections for sensor imperfections and uneven lighting."
        attribute darkReference : Integer[0..*];
        attribute whiteReference : Integer[0..*];
        attribute shadingCorrectionEnabled : Boolean = true;
        attribute defectPixelMap : Boolean[0..*];
        port in rawDigitalIn : DigitalLineInputPort;
        port out processedOut : ProcessedLinePort;
        action def CorrectLine {
            in rawLine : DigitalLineData;
            out correctedLine : ProcessedLineData;
        }
        action def AssembleImage {
            in lines : ProcessedLineData[0..*];
            out image : DigitalImage;
        }
        perform CorrectLine;
        perform AssembleImage;
    }

    part def CISModule {
        doc "Contact Image Sensor module containing illumination, lens, photodiodes, AFE, ADC, and image processing."
        part ledArray : LEDArray;
        part lensArray : SelfocLensArray;
        part photodiodeArray : PhotodiodeArray;
        part analogFrontEnd : AnalogFrontEnd;
        part adc : AnalogToDigitalConverter;
        part imageProcessor : ImageProcessingUnit;

        connect ledArray.illumination to lensArray.lightInput;
        connect lensArray.focusedLight to photodiodeArray.incidentLight;
        connect photodiodeArray.analogOut to analogFrontEnd.analogIn;
        connect analogFrontEnd.conditionedOut to adc.analogInput;
        connect adc.digitalOut to imageProcessor.rawDigitalIn;

        port out imageOutput : ImageOutputPort;
        connect imageProcessor.processedOut to imageOutput;

        exhibit state scanningState {
            entry; then idle;
            state idle;
            state illuminating;
            state capturing;
            state converting;
            state processing;
            state assembling;
            transition idle -> illuminating when (scanStarted == true);
            transition illuminating -> capturing when (illuminationComplete == true);
            transition capturing -> converting when (lineCaptured == true);
            transition converting -> processing when (conversionComplete == true);
            transition processing -> assembling when (allLinesProcessed == true);
            transition processing -> illuminating when (allLinesProcessed == false);
            transition assembling -> idle when (imageAssembled == true);
            attribute scanStarted : Boolean;
            attribute illuminationComplete : Boolean;
            attribute lineCaptured : Boolean;
            attribute conversionComplete : Boolean;
            attribute allLinesProcessed : Boolean;
            attribute imageAssembled : Boolean;
        }
    }

    part def TransportMechanism {
        doc "Mechanism that precisely advances the document past the stationary CIS module."
        attribute motorStepSizeMicrons : PositionAccuracyMicrons = 10;
        attribute maxSpeedLinesPerSec : FrequencyHz = 100;
        attribute currentPositionMicrons : PositionAccuracyMicrons;
        port in documentInput : DocumentPort;
        port out documentPosition : DocumentPort;
        exhibit state transportState {
            entry; then stopped;
            state stopped;
            state advancing;
            transition stopped -> advancing when (advanceCommand == true);
            transition advancing -> stopped when (advanceComplete == true);
            attribute advanceCommand : Boolean;
            attribute advanceComplete : Boolean;
        }
        action def AdvanceDocument {
            in lines : LineCount;
            out newPosition : PositionAccuracyMicrons;
        }
        perform AdvanceDocument;
    }

    part def ScannerSensingUnit {
        doc "Complete sensing unit for a document scanner using CIS technology."
        satisfy MinResolutionRequirement {
            attribute resolutionHorizontal = 600;
            attribute resolutionVertical = 600;
        }
        satisfy OpticalQualityRequirement {
            attribute modulationTransfer = 0.65;
            attribute distortionPercent = 1.5;
        }
        satisfy MechanicalPositioningRequirement {
            attribute positionError = 15;
        }
        satisfy ADCPrecisionRequirement {
            attribute adcBitDepth = 12;
        }
        satisfy ScanSpeedRequirement {
            attribute scanTimePerPage = 4500;
        }

        part cisModule : CISModule;
        part transport : TransportMechanism;

        connect transport.documentPosition to cisModule.imageOutput;

        port in documentIn : DocumentPort;
        connect documentIn to transport.documentInput;

        port out finalImage : ImageOutputPort;
        connect cisModule.imageOutput to finalImage;

        exhibit state overallScanProcess {
            entry; then ready;
            state ready;
            state feeding;
            state scanning;
            state ejecting;
            transition ready -> feeding when (documentDetected == true);
            transition feeding -> scanning when (documentLoaded == true);
            transition scanning -> ejecting when (scanComplete == true);
            transition ejecting -> ready when (documentEjected == true);
            attribute documentDetected : Boolean;
            attribute documentLoaded : Boolean;
            attribute scanComplete : Boolean;
            attribute documentEjected : Boolean;
        }

        action def ScanDocument {
            in document : PhysicalDocument;
            out image : DigitalImage;
        }
        perform ScanDocument;
    }
}
