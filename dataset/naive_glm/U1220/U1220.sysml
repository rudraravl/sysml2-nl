package SuperfluidHeliumSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type TemperatureValue :> Real { unit K; }
    value type PressureValue :> Real { unit Pa; }
    value type FlowRateValue :> Real { unit "m^3/s"; }
    value type PowerValue :> Real { unit W; }
    value type VolumeValue :> Real { unit "m^3"; }
    value type LengthValue :> Real { unit m; }
    value type DurationValue :> Real { unit s; }
    value type VortexCount :> Integer;

    // ---- Item types ----
    item def Helium4;
    item def LiquidHelium :> Helium4;
    item def SuperfluidHelium :> LiquidHelium;
    item def ThermalEnergy;
    item def ControlSignal;
    item def SensorData;
    item def TemperatureReading :> SensorData {
        attribute value : TemperatureValue;
    }
    item def VortexReading :> SensorData {
        attribute count : VortexCount;
    }

    // ---- Critical constants ----
    attribute criticalTemperature : TemperatureValue = 2.17 [K];
    attribute targetOperatingTemperature : TemperatureValue = 1.8 [K];
    attribute warmupThreshold : TemperatureValue = 5.0 [K];

    // ---- Port definitions ----
    port def FluidPort {
        out item heliumOut : LiquidHelium;
        in item heliumIn : LiquidHelium;
    }

    port def BidirectionalFluidPort {
        in out item helium : LiquidHelium;
    }

    port def ThermalPort {
        out item heat : ThermalEnergy;
    }

    port def SignalOutPort {
        out item data : SensorData;
    }

    port def SignalInPort {
        in item command : ControlSignal;
    }

    port def ControlPort {
        in item data : SensorData;
        out item command : ControlSignal;
    }

    // ---- Cryogenic Cooler ----
    part def CryogenicCooler {
        attribute coolingPower : PowerValue = 5.0 [W];
        attribute minimumTemperature : TemperatureValue = 1.5 [K];
        attribute active : Boolean = false;

        port thermalOut : ThermalPort;
        port fluidReturn : FluidPort;
        port fluidSupply : FluidPort;
        port control : ControlPort;

        action def Cool {
            in item heliumIn : LiquidHelium;
            in item heatExtracted : ThermalEnergy;
            out item heliumOut : LiquidHelium;
        }

        action performCooling : Cool {
            when active;
        }
    }

    // ---- Helium Reservoir ----
    part def HeliumReservoir {
        attribute capacity : VolumeValue = 0.01 [m^3];
        attribute fillLevel : VolumeValue = 0.008 [m^3];
        attribute currentTemperature : TemperatureValue = 4.2 [K];
        attribute pressure : PressureValue = 101325 [Pa];
        attribute isSuperfluid : Boolean = false;

        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port thermalIn : ThermalPort;
        port sensorPort : SignalOutPort;

        state def ReservoirPhase {
            entry; then GaseousLiquid;
            state GaseousLiquid;
            transition GaseousLiquid to NormalLiquid
                when currentTemperature < 4.2 [K];
            state NormalLiquid;
            transition NormalLiquid to Superfluid
                when currentTemperature < criticalTemperature;
            state Superfluid {
                entry { isSuperfluid = true; }
            }
            transition Superfluid to NormalLiquid
                when currentTemperature >= criticalTemperature;
            transition NormalLiquid to GaseousLiquid
                when currentTemperature > 4.2 [K];
        }

        state phase : ReservoirPhase;

        action def SenseTemperature {
            out item reading : TemperatureReading;
        }

        action sense : SenseTemperature;
    }

    // ---- Temperature Sensor ----
    part def TemperatureSensor {
        attribute accuracy : TemperatureValue = 0.001 [K];
        attribute samplingInterval : DurationValue = 0.1 [s];
        attribute lastReading : TemperatureValue;

        port measured : SignalOutPort;
        port thermalContact : ThermalPort;

        action def Measure {
            in item heat : ThermalEnergy;
            out item reading : TemperatureReading;
        }

        action measure : Measure;
    }

    // ---- Flow Controller ----
    part def FlowController {
        attribute maxFlowRate : FlowRateValue = 0.001 [m^3/s];
        attribute currentFlowRate : FlowRateValue = 0.0 [m^3/s];
        attribute enabled : Boolean = false;

        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : ControlPort;

        action def RegulateFlow {
            in item command : ControlSignal;
            in item heliumIn : LiquidHelium;
            out item heliumOut : SuperfluidHelium;
        }

        action regulate : RegulateFlow {
            when enabled;
        }
    }

    // ---- Persistent Current Loop ----
    part def PersistentCurrentLoop {
        attribute circumference : LengthValue = 0.5 [m];
        attribute channelDiameter : LengthValue = 0.002 [m];
        attribute circulationActive : Boolean = false;
        attribute circulationVelocity : FlowRateValue = 0.0001 [m^3/s];

        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port observation : SignalOutPort;

        action def InitializeCurrent {
            in item helium : SuperfluidHelium;
        }

        action def SustainCurrent {
            in item helium : SuperfluidHelium;
        }

        action initialize : InitializeCurrent;
        action sustain : SustainCurrent {
            when circulationActive;
        }
    }

    // ---- Quantum Vortex Detector ----
    part def QuantumVortexDetector {
        attribute detectionThreshold : VortexCount = 1;
        attribute observedCount : VortexCount = 0;
        attribute resolution : VortexCount = 1;

        port observation : SignalOutPort;
        port fluidContact : BidirectionalFluidPort;

        action def DetectVortices {
            in item helium : SuperfluidHelium;
            out item reading : VortexReading;
        }

        action detect : DetectVortices;
    }

    // ---- System Controller ----
    part def SystemController {
        attribute measuredTemperature : TemperatureValue = 4.2 [K];
        attribute shutdownRequested : Boolean = false;
        attribute systemPhase : String = "Idle";

        port tempSensorPort : ControlPort;
        port coolerPort : ControlPort;
        port flowControllerPort : ControlPort;
        port vortexDetectorPort : ControlPort;

        state def Lifecycle {
            entry; then CoolingPhase;

            state CoolingPhase {
                entry { systemPhase = "Cooling"; }
                do { send ControlSignal to coolerPort; }
            }
            transition CoolingPhase to SuperfluidOperationPhase
                when measuredTemperature < criticalTemperature;

            state SuperfluidOperationPhase {
                entry { systemPhase = "SuperfluidOperation"; }
                do { send ControlSignal to flowControllerPort; }
            }
            transition SuperfluidOperationPhase to WarmupPhase
                when shutdownRequested;

            state WarmupPhase {
                entry { systemPhase = "Warmup"; }
                do { send ControlSignal to coolerPort; }
            }
            transition WarmupPhase to ShutdownPhase
                when measuredTemperature > warmupThreshold;

            state ShutdownPhase {
                entry { systemPhase = "Shutdown"; }
            }
            transition ShutdownPhase to CoolingPhase
                when !shutdownRequested;
        }

        state lifecycle : Lifecycle;

        action def ProcessSensorData {
            in item reading : TemperatureReading;
            out item command : ControlSignal;
        }

        action process : ProcessSensorData;
    }

    // ---- Top-level platform ----
    part def SuperfluidHeliumPlatform {
        attribute systemIdentifier : String = "SHS-001";
        attribute designPressure : PressureValue = 101325 [Pa];

        part cooler : CryogenicCooler;
        part reservoir : HeliumReservoir;
        part controller : SystemController;
        part tempSensor : TemperatureSensor;
        part flowController : FlowController;
        part currentLoop : PersistentCurrentLoop;
        part vortexDetector : QuantumVortexDetector;

        // Thermal path: cooler extracts heat from reservoir
        connection coolThermal connect cooler.thermalOut to reservoir.thermalIn;
        connection tempSensorThermal connect reservoir.thermalIn to tempSensor.thermalContact;

        // Closed-loop fluid circuit
        connection coolerToReservoir connect cooler.fluidSupply to reservoir.fluidIn;
        connection reservoirToCoolerReturn connect reservoir.fluidOut to cooler.fluidReturn;
        connection reservoirToFlow connect reservoir.fluidOut to flowController.fluidIn;
        connection flowToLoop connect flowController.fluidOut to currentLoop.fluidIn;
        connection loopReturnToReservoir connect currentLoop.fluidOut to reservoir.fluidIn;

        // Vortex detector taps the persistent current loop
        connection loopToVortexDetector connect currentLoop.fluidOut to vortexDetector.fluidContact;

        // Signal/control network
        connection tempSensorToController connect tempSensor.measured to controller.tempSensorPort;
        connection reservoirSensorToController connect reservoir.sensorPort to controller.tempSensorPort;
        connection controllerToCooler connect controller.coolerPort to cooler.control;
        connection controllerToFlowController connect controller.flowControllerPort to flowController.control;
        connection vortexDetectorToController connect vortexDetector.observation to controller.vortexDetectorPort;
        connection loopObservationToController connect currentLoop.observation to controller.vortexDetectorPort;
    }

    // ---- Requirements ----
    requirement def CoolBelowCriticalTemperature {
        subject platform : SuperfluidHeliumPlatform;
        requirement {
            platform.reservoir.currentTemperature < criticalTemperature
        }
        doc {
            The system shall cool liquid helium-4 below its critical
            transition temperature of approximately 2.17 K to establish
            the superfluid phase.
        }
    }

    requirement def MaintainSuperfluidState {
        subject platform : SuperfluidHeliumPlatform;
        requirement {
            platform.reservoir.currentTemperature <= targetOperatingTemperature
        }
        doc {
            Once the superfluid phase is established, the system shall
            maintain the helium below 2.0 K to preserve zero-viscosity
            behavior during operation.
        }
    }

    requirement def ClosedLoopFluidCircuit {
        subject platform : SuperfluidHeliumPlatform;
        requirement {
            platform.cooler.fluidSupply.connectedTo(platform.reservoir.fluidIn) and
            platform.reservoir.fluidOut.connectedTo(platform.flowController.fluidIn) and
            platform.flowController.fluidOut.connectedTo(platform.currentLoop.fluidIn) and
            platform.currentLoop.fluidOut.connectedTo(platform.reservoir.fluidIn)
        }
        doc {
            The system shall implement a closed-loop fluid circuit in
            which superfluid helium circulates without external fluid
            replenishment.
        }
    }

    requirement def PersistentCurrentIndefinite {
        subject loop : PersistentCurrentLoop;
        requirement {
            loop.circulationActive == true
        }
        doc {
            Once initialized, the persistent current loop shall sustain
            circulation of superfluid helium indefinitely without
            additional energy input.
        }
    }

    requirement def VortexDetectionCapability {
        subject detector : QuantumVortexDetector;
        requirement {
            detector.detectionThreshold >= 1 and
            detector.resolution == 1
        }
        doc {
            The quantum vortex detector shall observe and count
            individual quantized vortices within the superfluid flow.
        }
    }

    requirement def LifecycleManagement {
        subject controller : SystemController;
        requirement {
            controller.lifecycle.CoolingPhase.defined and
            controller.lifecycle.SuperfluidOperationPhase.defined and
            controller.lifecycle.WarmupPhase.defined and
            controller.lifecycle.ShutdownPhase.defined
        }
        doc {
            The system controller shall manage a lifecycle consisting of
            a cooling phase, a superfluid operation phase, a controlled
            warmup phase, and a shutdown phase.
        }
    }

    requirement def TemperatureMonitoringAccuracy {
        subject sensor : TemperatureSensor;
        requirement {
            sensor.accuracy <= 0.005 [K]
        }
        doc {
            Temperature sensors shall provide measurements with accuracy
            sufficient to reliably detect the lambda transition at
            2.17 K.
        }
    }

    requirement def CryogenicCoolerCapacity {
        subject cooler : CryogenicCooler;
        requirement {
            cooler.coolingPower >= 1.0 [W] and
            cooler.minimumTemperature <= 1.5 [K]
        }
        doc {
            The cryogenic cooler shall have sufficient cooling power and
            minimum temperature capability to establish and maintain the
            superfluid phase of helium-4.
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction CoolBelowCriticalTemperature satisfy by SuperfluidHeliumPlatform;
    satisfaction MaintainSuperfluidState satisfy by SuperfluidHeliumPlatform;
    satisfaction ClosedLoopFluidCircuit satisfy by SuperfluidHeliumPlatform;
    satisfaction PersistentCurrentIndefinite satisfy by PersistentCurrentLoop;
    satisfaction VortexDetectionCapability satisfy by QuantumVortexDetector;
    satisfaction LifecycleManagement satisfy by SystemController;
    satisfaction TemperatureMonitoringAccuracy satisfy by TemperatureSensor;
    satisfaction CryogenicCoolerCapacity satisfy by CryogenicCooler;
}
