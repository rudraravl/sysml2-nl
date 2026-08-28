package DocumentScannerSystem {
    private import ScalarValues::*;
    
    // --- Value Types ---
    attribute def Length :> Real { unit 'mm'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Resolution :> Integer { unit 'dpi'; }
    
    // --- Items ---
    item def Document;
    item def Light;
    item def ReflectedLight :> Light;
    item def FocusedLight :> Light;
    item def AnalogLineSignal;
    item def DigitalLine;
    item def ProcessedLine :> DigitalLine;
    item def DigitalImage;
    
    // --- Ports ---
    port def OpticalPort {
        out light : Light;
    }
    port def AnalogPort {
        out signal : AnalogLineSignal;
    }
    port def DigitalPort {
        out data : DigitalLine;
    }
    port def ImagePort {
        out image : DigitalImage;
    }
    port def DocumentPort {
        in doc : Document;
    }
    port def ControlPort {
        in command : Boolean;
        out status : Boolean;
    }
    
    // --- Requirements ---
    requirement def MinimumResolution {
        attribute minResolution : Resolution = 600;
    }
    requirement def OpticalQuality {
        attribute maxDistortion : Real = 1.0;
    }
    requirement def PositioningAccuracy {
        attribute maxStepError : Length = 0.05;
    }
    requirement def ConversionPrecision {
        attribute minBits : Integer = 10;
    }
    
    // --- Actions ---
    action def AdvanceDocument {
        in item document : Document;
        out item advancedDocument : Document;
    }
    action def IlluminateLine {
        in item document : Document;
        out item light : Light;
    }
    action def ReflectLight {
        in item document : Document;
        in item light : Light;
        out item reflectedLight : ReflectedLight;
    }
    action def FocusLight {
        in item reflectedLight : ReflectedLight;
        out item focusedLight : FocusedLight;
    }
    action def SenseLight {
        in item focusedLight : FocusedLight;
        out item analogSignal : AnalogLineSignal;
    }
    action def ConditionSignal {
        in item rawSignal : AnalogLineSignal;
        out item conditionedSignal : AnalogLineSignal;
    }
    action def Digitize {
        in item analogSignal : AnalogLineSignal;
        out item digitalData : DigitalLine;
    }
    action def CorrectImage {
        in item rawLine : DigitalLine;
        out item correctedLine : ProcessedLine;
    }
    action def AssembleImage {
        in item lines : ProcessedLine[*] ordered;
        out item image : DigitalImage;
    }
    
    action def ScanLine {
        in item document : Document;
        out item processedLine : ProcessedLine;
        
        action advance : AdvanceDocument {
            in item document = document;
            out item advancedDocument;
        }
        then action illuminate : IlluminateLine {
            in item document = advance.advancedDocument;
            out item light;
        }
        succession flow from illuminate.light to reflect.light;
        action reflect : ReflectLight {
            in item document = advance.advancedDocument;
            in item light;
            out item reflectedLight;
        }
        succession flow from reflect.reflectedLight to focus.reflectedLight;
        action focus : FocusLight {
            in item reflectedLight;
            out item focusedLight;
        }
        succession flow from focus.focusedLight to sense.focusedLight;
        action sense : SenseLight {
            in item focusedLight;
            out item analogSignal;
        }
        succession flow from sense.analogSignal to condition.rawSignal;
        action condition : ConditionSignal {
            in item rawSignal;
            out item conditionedSignal;
        }
        succession flow from condition.conditionedSignal to digitize.analogSignal;
        action digitize : Digitize {
            in item analogSignal;
            out item digitalData;
        }
        succession flow from digitize.digitalData to correct.rawLine;
        action correct : CorrectImage {
            in item rawLine;
            out item correctedLine;
        }
        bind correct.correctedLine = processedLine;
    }
    
    action def ScanDocument {
        in item document : Document;
        out item image : DigitalImage;
        
        action scanLines[*] ordered {
            action scanLine : ScanLine {
                in item document;
                out item processedLine;
            }
        }
        action assemble : AssembleImage {
            in item lines : ProcessedLine[*] ordered;
            out item image;
        }
        flow from scanLines.scanLine.processedLine to assemble.lines;
        bind assemble.image = image;
    }
    
    // --- Part Definitions ---
    part def TransportMechanism {
        attribute stepError : Length = 0.02;
        port documentPort : DocumentPort;
        port controlPort : ControlPort;
    }
    
    part def LEDArray {
        port lightOut : OpticalPort;
        port controlPort : ControlPort;
        attribute illuminationIntensity : Real = 1.0;
    }
    
    part def SelfocLensArray {
        port lightIn : ~OpticalPort;
        port lightOut : OpticalPort;
        attribute distortion : Real = 0.5;
    }
    
    part def PhotodiodeArray {
        port lightIn : ~OpticalPort;
        port analogOut : AnalogPort;
    }
    
    part def AnalogFrontEnd {
        port analogIn : ~AnalogPort;
        port analogOut : AnalogPort;
        attribute gain : Real = 10.0;
    }
    
    part def ADC {
        port analogIn : ~AnalogPort;
        port digitalOut : DigitalPort;
        attribute bits : Integer = 10;
    }
    
    part def ImageProcessingUnit {
        port digitalIn : ~DigitalPort;
        port digitalOut : DigitalPort;
    }
    
    part def CISModule {
        part ledArray : LEDArray;
        part lensArray : SelfocLensArray;
        part photodiodeArray : PhotodiodeArray;
        part afe : AnalogFrontEnd;
        part adc : ADC;
        part ipu : ImageProcessingUnit;
        
        flow ledArray.lightOut.light to lensArray.lightIn.light;
        flow lensArray.lightOut.light to photodiodeArray.lightIn.light;
        flow photodiodeArray.analogOut.signal to afe.analogIn.signal;
        flow afe.analogOut.signal to adc.analogIn.signal;
        flow adc.digitalOut.data to ipu.digitalIn.data;
    }
    
    part def Scanner {
        attribute resolution : Resolution = 1200;
        port documentPort : DocumentPort;
        port imagePort : ImagePort;
        port controlPort : ControlPort;
        
        state machine scannerSM {
            state idle;
            transition from idle to scanning when startScan;
            state scanning;
            transition from scanning to done when scanComplete;
            state done;
            transition from done to idle when reset;
        }
    }
    
    // --- Context ---
    part scannerSystem : Scanner {
        satisfy MinimumResolution by scannerSystem;
        satisfy OpticalQuality by cis.lensArray;
        satisfy PositioningAccuracy by transport;
        satisfy ConversionPrecision by cis.adc;
        
        perform scanDoc : ScanDocument {
            in item document = documentPort.doc;
            out item image = imagePort.image;
        }
        
        part transport : TransportMechanism {
            perform scanDoc.scanLines.scanLine.advance;
        }
        
        part cis : CISModule {
            part ledArray : LEDArray {
                perform scanDoc.scanLines.scanLine.illuminate;
            }
            part lensArray : SelfocLensArray {
                perform scanDoc.scanLines.scanLine.focus;
            }
            part photodiodeArray : PhotodiodeArray {
                perform scanDoc.scanLines.scanLine.sense;
            }
            part afe : AnalogFrontEnd {
                perform scanDoc.scanLines.scanLine.condition;
            }
            part adc : ADC {
                perform scanDoc.scanLines.scanLine.digitize;
            }
            part ipu : ImageProcessingUnit {
                perform scanDoc.scanLines.scanLine.correct;
            }
        }
    }
}
