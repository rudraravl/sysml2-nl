package ActivePixelSensorUnit {
    public import Definitions::*;
    public import Usages::*;
    
    package Definitions {
        private import SI::*;
        private import ISQ::*;
        
        alias Duration for ISQ::DurationValue;
        alias Frequency for ISQ::FrequencyValue;
        alias Current for ISQ::ElectricCurrentValue;
        alias Voltage for ISQ::ElectricPotentialValue;
        
        attribute def RowIndex :> ScalarValues::Integer;
        attribute def ColumnIndex :> ScalarValues::Integer;
        attribute def DigitalCode :> ScalarValues::Integer;
        attribute def GainValue :> ScalarValues::Real;
        attribute def IntensityLevel :> ScalarValues::Real;
        
        attribute def PowerOn;
        attribute def PowerOff;
        item def InitComplete;
        item def FrameComplete;
        
        item def OpticalScene {
            attribute averageIntensity: IntensityLevel;
        }
        
        item def LightSample {
            attribute row: RowIndex;
            attribute column: ColumnIndex;
            attribute intensity: IntensityLevel;
        }
        
        item def PixelCurrent {
            attribute row: RowIndex;
            attribute column: ColumnIndex;
            attribute current: Current;
        }
        
        item def AnalogSignal {
            attribute row: RowIndex;
            attribute column: ColumnIndex;
            attribute voltage: Voltage;
        }
        
        item def DigitalPixel {
            attribute row: RowIndex;
            attribute column: ColumnIndex;
            attribute code: DigitalCode;
        }
        
        item def DigitalImage {
            attribute width: ScalarValues::Integer = 1920;
            attribute height: ScalarValues::Integer = 1080;
            attribute bitDepth: ScalarValues::Integer = 12;
            part pixels: DigitalPixel[2073600];
        }
        
        item def ExposureCommand {
            attribute exposureTime: Duration;
            attribute gain: GainValue;
        }
        
        item def PowerSupply {
            attribute voltage: Voltage;
        }
        
        part def Photodiode {
            in item incidentLight: LightSample;
            out item currentOut: PixelCurrent;
            attribute conversionEfficiency: ScalarValues::Real;
        }
        
        part def PixelAmplifier {
            in item currentIn: PixelCurrent;
            in attribute gainSetting: GainValue;
            out item signalOut: AnalogSignal;
        }
        
        part def SelectTransistor {
            attribute enabled: ScalarValues::Boolean;
        }
        
        part def ResetTransistor {
            attribute enabled: ScalarValues::Boolean;
        }
        
        part def ActivePixel {
            attribute row: RowIndex;
            attribute column: ColumnIndex;
            part photodiode: Photodiode;
            part amplifier: PixelAmplifier;
            part selectSwitch: SelectTransistor;
            part resetSwitch: ResetTransistor;
            in item lightIn: LightSample;
            out item analogOut: AnalogSignal;
            in attribute gainIn: GainValue;
            
            connect lightIn to photodiode.incidentLight;
            connect photodiode.currentOut to amplifier.currentIn;
            connect gainIn to amplifier.gainSetting;
            connect amplifier.signalOut to analogOut;
        }
        
        part def PixelArray {
            attribute width: ScalarValues::Integer = 1920;
            attribute height: ScalarValues::Integer = 1080;
            attribute totalPixels: ScalarValues::Integer = 2073600;
            part pixels: ActivePixel[2073600];
            in item sceneLight: OpticalScene;
            in attribute selectedRow: RowIndex;
            in attribute selectedColumn: ColumnIndex;
            in attribute gain: GainValue;
            out item analogOut: AnalogSignal;
        }
        
        part def RowDecoder {
            attribute numRows: ScalarValues::Integer = 1080;
            in item frameTick;
            out attribute selectedRow: RowIndex;
        }
        
        part def ColumnDecoder {
            attribute numColumns: ScalarValues::Integer = 1920;
            in item frameTick;
            out attribute selectedColumn: ColumnIndex;
        }
        
        part def ADC12bit {
            attribute bitDepth: ScalarValues::Integer = 12;
            attribute minCode: DigitalCode = 0;
            attribute maxCode: DigitalCode = 4095;
            in item analogIn: AnalogSignal;
            out item digitalOut: DigitalPixel;
        }
        
        part def TimingGenerator {
            attribute frameRate: Frequency;
            attribute framePeriod: Duration;
            in item captureCmd: ExposureCommand;
            out item exposureTick;
            out item readoutTick;
            out item resetTick;
            out item frameComplete: FrameComplete;
        }
        
        part def ImageProcessor {
            in item pixelStream: DigitalPixel[2073600];
            out item imageOut: DigitalImage;
            attribute outputWidth: ScalarValues::Integer = 1920;
            attribute outputHeight: ScalarValues::Integer = 1080;
        }
        
        action def AccumulateCharge {
            in item light: OpticalScene;
            in exposureTime: Duration;
            out item currents: PixelCurrent[2073600];
        }
        
        action def AmplifySignals {
            in item currents: PixelCurrent[2073600];
            in gain: GainValue;
            out item analogSignals: AnalogSignal[2073600];
        }
        
        action def ConvertToDigital {
            in item analogSignals: AnalogSignal[2073600];
            out item digitalPixels: DigitalPixel[2073600];
        }
        
        action def AssembleImage {
            in item digitalPixels: DigitalPixel[2073600];
            out item image: DigitalImage;
        }
        
        action def CaptureFrame {
            in item scene: OpticalScene;
            in exposureTime: Duration;
            in gain: GainValue;
            out item image: DigitalImage;
        }
        
        action def Initialize {
            in item power: PowerSupply;
            out item initDone: InitComplete;
        }
        
        state def APSOperationalState {
            entry; then PoweredOff;
            
            state PoweredOff;
            
            transition 
                first PoweredOff 
                accept pwrOn: PowerOn 
                then Initializing;
            
            state Initializing {
                do action initAction: Initialize;
            }
            
            transition 
                first Initializing 
                accept initComplete: InitComplete 
                then Ready;
            
            state Ready;
            
            transition 
                first Ready 
                accept captureCmd: ExposureCommand 
                then Capturing;
            
            state Capturing {
                do action captureAction: CaptureFrame;
            }
            
            transition 
                first Capturing 
                accept frameComplete: FrameComplete 
                then Ready;
            
            transition 
                first Ready 
                accept shutdown: PowerOff 
                then PoweredOff;
            
            transition 
                first Capturing 
                accept shutdown: PowerOff 
                then PoweredOff;
            
            exit;
        }
        
        part def APSSensor {
            port powerPort;
            port controlPort;
            port dataPort;
            port opticalPort;
            
            in item powerIn: PowerSupply;
            in item sceneIn: OpticalScene;
            in item commandIn: ExposureCommand;
            out item imageOut: DigitalImage;
            
            part timingGen: TimingGenerator;
            part rowDecoder: RowDecoder;
            part columnDecoder: ColumnDecoder;
            part pixelArray: PixelArray;
            part adc: ADC12bit;
            part imageProcessor: ImageProcessor;
            
            state operationalState: APSOperationalState;
        }
    }
    
    package Usages {
        action captureFrame: CaptureFrame {
            in item scene: OpticalScene;
            in exposureTime: Duration;
            in gain: GainValue;
            out item image: DigitalImage;
            
            first start then exposeAction;
            
            action exposeAction: AccumulateCharge {
                in item light = scene;
                in exposureTime = captureFrame::exposureTime;
                out item currents: PixelCurrent[2073600];
            }
            
            flow from exposeAction.currents to amplifyAction.currents;
            
            then action amplifyAction: AmplifySignals {
                in item currents;
                in gain = captureFrame::gain;
                out item analogSignals: AnalogSignal[2073600];
            }
            
            flow from amplifyAction.analogSignals to convertAction.analogSignals;
            
            then action convertAction: ConvertToDigital {
                in item analogSignals;
                out item digitalPixels: DigitalPixel[2073600];
            }
            
            flow from convertAction.digitalPixels to assembleAction.digitalPixels;
            
            then action assembleAction: AssembleImage {
                in item digitalPixels;
                out item image: DigitalImage;
            }
            
            bind image = assembleAction.image;
        }
        
        part apsSensor: APSSensor {
            part :>> timingGen {
                attribute :>> frameRate {
                    :>> num = 60.0;
                }
                attribute :>> framePeriod {
                    :>> num = 0.0166667;
                }
            }
            
            connect sceneIn to pixelArray.sceneLight;
            connect commandIn to timingGen.captureCmd;
            connect timingGen.exposureTick to rowDecoder.frameTick;
            connect timingGen.readoutTick to columnDecoder.frameTick;
            connect rowDecoder.selectedRow to pixelArray.selectedRow;
            connect columnDecoder.selectedColumn to pixelArray.selectedColumn;
            connect pixelArray.analogOut to adc.analogIn;
            connect adc.digitalOut to imageProcessor.pixelStream;
            connect imageProcessor.imageOut to imageOut;
        }
    }
}
