package RhinoscopeSystem {

    value type Illuminance :> Real { unit "lux"; }
    value type FlowRate :> Real { unit "mL/min"; }
    value type Pressure :> Real { unit "kPa"; }
    value type Resolution :> Integer { unit "pixel"; }
    value type FrameRate :> Real { unit "fps"; }
    value type Length :> Real { unit "mm"; }
    value type Diameter :> Real { unit "mm"; }
    value type Power :> Real { unit "W"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Volume :> Real { unit "mL"; }
    value type Temperature :> Real { unit "degC"; }
    value type Duration :> Real { unit "ms"; }

    item def IlluminationLight {
        attribute intensity : Illuminance;
        attribute colorTemp : Temperature;
    }

    item def VideoFrame {
        attribute resolution : Resolution;
        attribute frameRate : FrameRate;
        attribute latency : Duration;
    }

    item def IrrigationFluid {
        attribute volume : Volume;
        attribute temperature : Temperature;
    }

    item def SuctionedDebris {
        attribute volume : Volume;
    }

    item def ControlCommand {
        attribute command : String;
    }

    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    port def LightPort {
        inout item light : IlluminationLight;
    }

    port def VideoPort {
        inout item frame : VideoFrame;
    }

    port def FluidPort {
        inout item fluid : IrrigationFluid;
    }

    port def DebrisPort {
        inout item debris : SuctionedDebris;
    }

    port def PowerPort {
        inout item power : ElectricPower;
    }

    port def CommandPort {
        inout item command : ControlCommand;
    }

    connection def LightConnection {
        end source : LightPort;
        end target : LightPort;
        flow light : IlluminationLight;
    }

    connection def VideoConnection {
        end source : VideoPort;
        end target : VideoPort;
        flow frame : VideoFrame;
    }

    connection def FluidConnection {
        end source : FluidPort;
        end target : FluidPort;
        flow fluid : IrrigationFluid;
    }

    connection def DebrisConnection {
        end source : DebrisPort;
        end target : DebrisPort;
        flow debris : SuctionedDebris;
    }

    connection def PowerConnection {
        end source : PowerPort;
        end target : PowerPort;
        flow power : ElectricPower;
    }

    connection def CommandConnection {
        end source : CommandPort;
        end target : CommandPort;
        flow command : ControlCommand;
    }

    action def initializeSystem;
    action def powerOnLight;
    action def powerOnIrrigation;
    action def powerOffIrrigation;
    action def powerOnSuction;
    action def powerOffSuction;
    action def powerOffAll;

    part def LightSource {
        port powerIn : PowerPort;
        port lightOut : LightPort;
        attribute intensity : Illuminance = 120000 [lux];
        attribute colorTemp : Temperature = 5600 [degC];
        attribute maxPower : Power = 150 [W];
    }

    part def FiberOpticBundle {
        port lightIn : LightPort;
        port lightOut : LightPort;
        attribute length : Length = 300 [mm];
        attribute transmissionEfficiency : Real = 0.85;
    }

    part def LensAssembly {
        port lightIn : LightPort;
        port imageOut : VideoPort;
        attribute magnification : Real = 12.0;
        attribute focalLength : Length = 2.2 [mm];
    }

    part def ImageSensor {
        port imageIn : VideoPort;
        port videoOut : VideoPort;
        attribute resolution : Resolution = 1920 * 1080;
        attribute frameRate : FrameRate = 60 [fps];
        attribute powerConsumption : Power = 2.5 [W];
    }

    part def VideoProcessor {
        port videoIn : VideoPort;
        port videoOut : VideoPort;
        attribute processingLatency : Duration = 15 [ms];
        attribute enhancementEnabled : Boolean = true;
    }

    part def DisplayMonitor {
        port videoIn : VideoPort;
        attribute screenSize : Length = 270 [mm];
        attribute resolution : Resolution = 1920 * 1080;
        attribute refreshRate : FrameRate = 60 [fps];
    }

    part def IrrigationSystem {
        port powerIn : PowerPort;
        port fluidOut : FluidPort;
        attribute reservoirVolume : Volume = 500 [mL];
        attribute flowRate : FlowRate = 50 [mL/min];
        attribute fluidTemperature : Temperature = 37 [degC];
        attribute pumpPower : Power = 30 [W];
    }

    part def SuctionSystem {
        port powerIn : PowerPort;
        port debrisIn : DebrisPort;
        port debrisOut : DebrisPort;
        attribute vacuumPressure : Pressure = 80 [kPa];
        attribute containerVolume : Volume = 1000 [mL];
        attribute pumpPower : Power = 40 [W];
    }

    part def WasteContainer {
        port debrisIn : DebrisPort;
        attribute capacity : Volume = 1000 [mL];
        attribute currentFill : Volume = 0 [mL];
    }

    part def InsertionTube {
        port lightIn : LightPort;
        port imageOut : VideoPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port debrisIn : DebrisPort;
        port debrisOut : DebrisPort;
        attribute length : Length = 300 [mm];
        attribute diameter : Diameter = 4 [mm];
        attribute maxInsertionDepth : Length = 250 [mm];

        part fiberBundle : FiberOpticBundle;
        part lens : LensAssembly;
        part sensor : ImageSensor;

        connection lightInToFiber : LightConnection connect lightIn to fiberBundle.lightIn;
        connection fiberToLens : LightConnection connect fiberBundle.lightOut to lens.lightIn;
        connection lensToSensor : VideoConnection connect lens.imageOut to sensor.imageIn;
        connection sensorToImageOut : VideoConnection connect sensor.videoOut to imageOut;
        connection fluidChannel : FluidConnection connect fluidIn to fluidOut;
        connection debrisChannel : DebrisConnection connect debrisIn to debrisOut;
    }

    part def ControlUnit {
        port commandIn : CommandPort;
        port powerLight : PowerPort;
        port powerIrrigation : PowerPort;
        port powerSuction : PowerPort;
        attribute maxOutputPower : Power = 500 [W];
        attribute ready : Boolean = false;
        attribute examine : Boolean = false;
        attribute irrigate : Boolean = false;
        attribute suction : Boolean = false;
        attribute stop : Boolean = false;
        attribute stopIrrigation : Boolean = false;
        attribute stopSuction : Boolean = false;

        exhibit state {
            initial Initializing;
            state Initializing {
                entry initializeSystem;
            }
            transition Initializing -> Ready when ready;
            state Ready {
                entry powerOffAll;
            }
            transition Ready -> Examining when examine;
            state Examining {
                entry powerOnLight;
            }
            transition Examining -> Irrigating when irrigate;
            transition Examining -> Suctioning when suction;
            transition Examining -> Ready when stop;
            state Irrigating {
                entry powerOnIrrigation;
                exit powerOffIrrigation;
            }
            transition Irrigating -> Examining when stopIrrigation;
            state Suctioning {
                entry powerOnSuction;
                exit powerOffSuction;
            }
            transition Suctioning -> Examining when stopSuction;
        }
    }

    part def Operator {
        port commandOut : CommandPort;
    }

    part def Rhinoscope {
        part operator : Operator;
        part controlUnit : ControlUnit;
        part lightSource : LightSource;
        part insertionTube : InsertionTube;
        part videoProcessor : VideoProcessor;
        part displayMonitor : DisplayMonitor;
        part irrigationSystem : IrrigationSystem;
        part suctionSystem : SuctionSystem;
        part wasteContainer : WasteContainer;

        connection operatorToControl : CommandConnection connect operator.commandOut to controlUnit.commandIn;
        connection controlToLight : PowerConnection connect controlUnit.powerLight to lightSource.powerIn;
        connection lightToTube : LightConnection connect lightSource.lightOut to insertionTube.lightIn;
        connection tubeToProcessor : VideoConnection connect insertionTube.imageOut to videoProcessor.videoIn;
        connection processorToDisplay : VideoConnection connect videoProcessor.videoOut to displayMonitor.videoIn;
        connection controlToIrrigation : PowerConnection connect controlUnit.powerIrrigation to irrigationSystem.powerIn;
        connection irrigationToTube : FluidConnection connect irrigationSystem.fluidOut to insertionTube.fluidIn;
        connection controlToSuction : PowerConnection connect controlUnit.powerSuction to suctionSystem.powerIn;
        connection tubeToSuction : DebrisConnection connect insertionTube.debrisOut to suctionSystem.debrisIn;
        connection suctionToWaste : DebrisConnection connect suctionSystem.debrisOut to wasteContainer.debrisIn;
    }

    requirement def IlluminationRequirement {
        subject lightSource : LightSource;
        attribute minIntensity : Illuminance = 50000 [lux];
        attribute targetColorTemp : Temperature = 5600 [degC];
        constraint { lightSource.intensity >= minIntensity }
        constraint { lightSource.colorTemp >= 5000 [degC] and lightSource.colorTemp <= 6500 [degC] }
    }

    requirement def VisualizationRequirement {
        subject sensor : ImageSensor;
        attribute minResolution : Resolution = 1920 * 1080;
        attribute minFrameRate : FrameRate = 30 [fps];
        constraint { sensor.resolution >= minResolution }
        constraint { sensor.frameRate >= minFrameRate }
    }

    requirement def LatencyRequirement {
        subject processor : VideoProcessor;
        attribute maxLatency : Duration = 50 [ms];
        constraint { processor.processingLatency <= maxLatency }
    }

    requirement def IrrigationRequirement {
        subject irrigation : IrrigationSystem;
        attribute minFlowRate : FlowRate = 20 [mL/min];
        attribute maxFlowRate : FlowRate = 100 [mL/min];
        constraint { irrigation.flowRate >= minFlowRate and irrigation.flowRate <= maxFlowRate }
    }

    requirement def SuctionRequirement {
        subject suction : SuctionSystem;
        attribute minVacuum : Pressure = 50 [kPa];
        attribute maxVacuum : Pressure = 100 [kPa];
        constraint { suction.vacuumPressure >= minVacuum and suction.vacuumPressure <= maxVacuum }
    }

    requirement def InsertionTubeRequirement {
        subject tube : InsertionTube;
        attribute maxDiameter : Diameter = 5 [mm];
        attribute minLength : Length = 250 [mm];
        constraint { tube.diameter <= maxDiameter }
        constraint { tube.length >= minLength }
    }

    requirement def ControlUnitRequirement {
        subject control : ControlUnit;
        attribute requiredStates : String = "Initializing, Ready, Examining, Irrigating, Suctioning";
        constraint { control.maxOutputPower >= 200 [W] }
    }

}
