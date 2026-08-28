package ThermalImagingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types with Units ----------
    attribute def Temperature :> Real {
        unit 'K';
    }
    attribute def PixelResolution :> Integer {
        unit 'pixel';
    }
    attribute def FrameRate :> Real {
        unit 'fps';
    }
    attribute def Power :> Real {
        unit 'W';
    }
    attribute def Voltage :> Real {
        unit 'V';
    }
    attribute def Current :> Real {
        unit 'A';
    }
    attribute def Duration :> Real {
        unit 's';
    }
    attribute def SignalToNoiseRatio :> Real {
        unit 'dB';
    }

    // ---------- Item Types ----------
    item def InfraredRadiation {
        attribute wavelength : Real; // micrometers
        attribute intensity : Real; // W/m^2
    }
    item def FocusedIRBeam :> InfraredRadiation {
        attribute focalLength : Real;
    }
    item def RawThermalFrame {
        attribute width : PixelResolution = 640;
        attribute height : PixelResolution = 480;
        attribute pixelData : Real[0..*]; // raw counts
    }
    item def ProcessedImageFrame {
        attribute width : PixelResolution = 640;
        attribute height : PixelResolution = 480;
        attribute colorMap : String;
        attribute snr : SignalToNoiseRatio;
    }
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def CoolingSignal {
        attribute targetTemp : Temperature;
        attribute achieved : Boolean;
    }

    // ---------- Port Definitions ----------
    port def IRRadiationPort {
        out item radiation : InfraredRadiation;
    }
    port def FocusedIRPort {
        out item beam : FocusedIRBeam;
    }
    port def RawDataPort {
        out item frame : RawThermalFrame;
    }
    port def ProcessedDataPort {
        out item image : ProcessedImageFrame;
    }
    port def PowerPort {
        out item power : ElectricalPower;
    }
    port def CoolingPort {
        out item cooling : CoolingSignal;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ---------- Requirements ----------
    requirement def DetectHeatSignatures {
        subject thermalCamera : ThermalCamera;
        objective {
            doc /* The system shall detect infrared radiation in the 8-14 micrometer wavelength band. */
        }
        assume {
            doc /* The environment may contain obscurants such as smoke or fog. */
        }
    }

    requirement def SensorResolution {
        subject sensor : InfraredSensorArray;
        objective {
            doc /* The sensor array shall have a resolution of 640x480 pixels. */
        }
        constraint { sensor.width == 640 and sensor.height == 480 }
    }

    requirement def CryogenicOperatingTemp {
        subject cooler : CryogenicCooler;
        objective {
            doc /* The cooler shall maintain the sensor at 77 Kelvin. */
        }
        constraint { cooler.targetTemperature == 77.0 }
    }

    requirement def RealTimeProcessing {
        subject processor : ImageProcessor;
        objective {
            doc /* The processor shall enhance images in real-time at a minimum of 30 fps. */
        }
        constraint { processor.minFrameRate >= 30.0 }
    }

    requirement def PowerDistribution {
        subject psu : PowerSupplyUnit;
        objective {
            doc /* The PSU shall provide regulated power to all components. */
        }
        constraint { psu.totalOutput >= 50.0 }
    }

    // ---------- Part Definitions ----------
    part def OpticalAssembly {
        port irIn : IRRadiationPort;
        port irOut : FocusedIRPort;
        attribute aperture : Real; // mm
        attribute focalLength : Real; // mm
        attribute spectralRangeMin : Real = 8.0; // micrometers
        attribute spectralRangeMax : Real = 14.0; // micrometers

        action def FocusRadiation {
            in item incoming : InfraredRadiation;
            out item focused : FocusedIRBeam;
        }
    }

    part def InfraredSensorArray {
        port irIn : FocusedIRPort;
        port dataOut : RawDataPort;
        port coolingIn : CoolingPort;
        attribute width : PixelResolution = 640;
        attribute height : PixelResolution = 480;
        attribute operatingTemp : Temperature = 77.0;
        attribute pixelPitch : Real; // micrometers
        attribute noiseEquivalentTempDiff : Real; // mK
        attribute isCooled : Boolean = false;

        action def CaptureFrame {
            in item beam : FocusedIRBeam;
            out item frame : RawThermalFrame;
        }
    }

    part def CryogenicCooler {
        port powerIn : PowerPort;
        port coolingOut : CoolingPort;
        attribute targetTemperature : Temperature = 77.0;
        attribute cooldownTime : Duration;
        attribute currentTemp : Temperature;
        attribute isActive : Boolean = false;

        action def CoolDown {
            in attribute startTemp : Temperature;
            out attribute endTemp : Temperature;
        }
    }

    part def ImageProcessor {
        port dataIn : RawDataPort;
        port imageOut : ProcessedDataPort;
        port powerIn : PowerPort;
        attribute minFrameRate : FrameRate = 30.0;
        attribute noiseReductionLevel : Real;
        attribute contrastEnhancement : Boolean = true;

        action def ProcessFrame {
            in item raw : RawThermalFrame;
            out item processed : ProcessedImageFrame;
        }
    }

    part def DisplayUnit {
        port imageIn : ProcessedDataPort;
        port powerIn : PowerPort;
        attribute resolutionWidth : PixelResolution = 1920;
        attribute resolutionHeight : PixelResolution = 1080;
        attribute brightness : Real; // cd/m^2
        attribute refreshRate : FrameRate = 60.0;

        action def RenderImage {
            in item image : ProcessedImageFrame;
        }
    }

    part def PowerSupplyUnit {
        port powerOut : PowerPort;
        attribute inputVoltage : Voltage = 12.0;
        attribute outputVoltage : Voltage = 5.0;
        attribute totalOutput : Power = 50.0;
        attribute efficiency : Real; // percentage
        attribute batteryCapacity : Real; // Wh
    }

    // ---------- Top-level System ----------
    part def ThermalCamera {
        port control : ControlPort;
        port irInput : IRRadiationPort;

        part opticalAssembly : OpticalAssembly {
            port irIn : IRRadiationPort;
            port irOut : FocusedIRPort;
        }
        part sensorArray : InfraredSensorArray {
            port irIn : FocusedIRPort;
            port dataOut : RawDataPort;
            port coolingIn : CoolingPort;
        }
        part cooler : CryogenicCooler {
            port powerIn : PowerPort;
            port coolingOut : CoolingPort;
        }
        part processor : ImageProcessor {
            port dataIn : RawDataPort;
            port imageOut : ProcessedDataPort;
            port powerIn : PowerPort;
        }
        part display : DisplayUnit {
            port imageIn : ProcessedDataPort;
            port powerIn : PowerPort;
        }
        part powerSupply : PowerSupplyUnit {
            port powerOut : PowerPort;
        }

        // Internal connections
        connection irInputToOptical connect irInput to opticalAssembly.irIn;
        connection opticalToSensor connect opticalAssembly.irOut to sensorArray.irIn;
        connection coolerToSensor connect cooler.coolingOut to sensorArray.coolingIn;
        connection sensorToProcessor connect sensorArray.dataOut to processor.dataIn;
        connection processorToDisplay connect processor.imageOut to display.imageIn;

        // Power distribution
        connection powerToCooler connect powerSupply.powerOut to cooler.powerIn;
        connection powerToProcessor connect powerSupply.powerOut to processor.powerIn;
        connection powerToDisplay connect powerSupply.powerOut to display.powerIn;

        // Requirements satisfaction
        satisfy DetectHeatSignatures by thermalCamera;
        satisfy SensorResolution by sensorArray;
        satisfy CryogenicOperatingTemp by cooler;
        satisfy RealTimeProcessing by processor;
        satisfy PowerDistribution by powerSupply;

        // ---------- State Machine ----------
        state def OperatingStates {
            entry action {
                doc /* Thermal camera operational state machine. */
            }

            state Off {
                entry action {
                    powerSupply.isActive := false;
                    cooler.isActive := false;
                }
            }

            state Initializing {
                entry action {
                    powerSupply.isActive := true;
                    cooler.isActive := true;
                    cooler.CoolDown(startTemp := cooler.currentTemp, endTemp := cooler.targetTemperature);
                }
                transition to Ready
                    when cooler.currentTemp <= cooler.targetTemperature + 1.0
                    if cooler.isActive;
            }

            state Ready {
                entry action {
                    sensorArray.isCooled := true;
                }
                transition to Imaging
                    when control.command == "start";
            }

            state Imaging {
                do action {
                    // Continuous capture-process-display cycle
                    opticalAssembly.FocusRadiation(
                        incoming := irInput.radiation,
                        focused := opticalAssembly.irOut.beam
                    );
                    sensorArray.CaptureFrame(
                        beam := sensorArray.irIn.beam,
                        frame := sensorArray.dataOut.frame
                    );
                    processor.ProcessFrame(
                        raw := processor.dataIn.frame,
                        processed := processor.imageOut.image
                    );
                    display.RenderImage(
                        image := display.imageIn.image
                    );
                }
                transition to Standby
                    when control.command == "stop";
            }

            state Standby {
                entry action {
                    cooler.isActive := false;
                    sensorArray.isCooled := false;
                }
                transition to Ready
                    when control.command == "start";
                transition to Off
                    when control.command == "shutdown";
            }

            transition from Off to Initializing
                when control.command == "power_on";
        }

        // Operational behavior
        action def Operate {
            in attribute command : String;
            out attribute status : String;
            // Delegates to state machine
        }
    }

    // ---------- Instantiation ----------
    part def ThermalCameraInstance :> ThermalCamera {
        attribute modelNumber : String = "TC-640";
        attribute manufacturer : String = "ThermalVision Systems";
    }

}
