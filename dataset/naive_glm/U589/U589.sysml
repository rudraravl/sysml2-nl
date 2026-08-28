package APS_Sensing_Unit {
    import ScalarValues::*;
    import ISQ::*;

    value type ExposureTime :> Duration;
    value type Gain :> Real;
    value type FrameRate :> Frequency;
    value type LightIntensity :> Real;
    value type Charge :> ElectricCharge;
    value type Voltage :> ElectricPotential;
    value type DigitalValue :> Integer;
    value type PixelAddress :> Integer;

    item def Light;
    item def Scene :> Light;
    item def DigitalImage;
    item def ControlCommand;
    item def Power;

    port def OpticalPort {
        in item scene : Scene;
    }
    port def PowerPort {
        in item power : Power;
    }
    port def ControlPort {
        in item command : ControlCommand;
    }
    port def DataPort {
        out item image : DigitalImage;
    }

    requirement def CaptureLight {
        doc "The APS shall capture light from an optical scene.";
    }
    requirement def ConvertToDigitalImage {
        doc "The APS shall convert captured light into a structured digital image.";
    }
    requirement def ResolutionRequirement {
        doc "The APS shall have a resolution of 1920x1080 pixels.";
        attribute resolution : String = "1920x1080";
    }
    requirement def FrameRateRequirement {
        doc "The APS shall support a frame rate of 60 frames per second.";
        attribute frameRate : FrameRate = 60 [Hz];
    }
    requirement def ADCResolution {
        doc "The APS shall use a 12-bit Analog-to-Digital Converter.";
        attribute bits : Integer = 12;
    }

    part def Pixel {
        part photodiode {
            in item light : Light;
            out item charge : Charge;
        }
        part amplifier {
            in item charge : Charge;
            attribute gain : Gain = 1.0;
            out item signal : Voltage;
        }
        part selectTransistor {
            in item selectSignal : Boolean;
        }
        part resetTransistor {
            in item resetSignal : Boolean;
        }
        in item light : Light;
        out item signal : Voltage;
    }

    part def PixelArray {
        attribute rows : Integer = 1080;
        attribute cols : Integer = 1920;
        part pixels : Pixel[rows * cols];
        in item light : Light;
        out item signal : Voltage;
    }

    part def TimingGenerator {
        attribute frameRate : FrameRate = 60 [Hz];
        out item clockSignal : Time;
        out item rowSelect : Boolean;
        out item resetSignal : Boolean;
    }

    part def RowDecoder {
        in item clockSignal : Time;
        out item rowAddress : PixelAddress;
    }

    part def ColumnDecoder {
        in item clockSignal : Time;
        out item colAddress : PixelAddress;
    }

    part def ADC {
        attribute resolution : Integer = 12;
        in item analogSignal : Voltage;
        out item digitalValue : DigitalValue;
    }

    part def ImageProcessor {
        in item digitalValue : DigitalValue;
        out item image : DigitalImage;
    }

    part def APSSensingUnit {
        satisfy CaptureLight;
        satisfy ConvertToDigitalImage;
        satisfy ResolutionRequirement;
        satisfy FrameRateRequirement;
        satisfy ADCResolution;

        port opticalIn : OpticalPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        port dataOut : DataPort;

        part pixelArray : PixelArray;
        part timingGen : TimingGenerator;
        part rowDec : RowDecoder;
        part colDec : ColumnDecoder;
        part adc : ADC;
        part imgProc : ImageProcessor;

        attribute exposureTime : ExposureTime = 1/120 [s];
        attribute gain : Gain = 1.0;

        state def APSStateMachine {
            state off;
            state initializing;
            state ready;
            state capturing;
            transition off to initializing;
            transition initializing to ready after 100 [ms];
            transition ready to capturing;
            transition capturing to ready after exposureTime;
        }

        exhibit state : APSStateMachine;

        flow from opticalIn.scene to pixelArray.light;
        flow from pixelArray.signal to adc.analogSignal;
        flow from timingGen.clockSignal to rowDec.clockSignal;
        flow from timingGen.clockSignal to colDec.clockSignal;
        flow from adc.digitalValue to imgProc.digitalValue;
        flow from imgProc.image to dataOut.image;
    }
}
