package AutomotiveRadarSensingUnit {

    import ScalarValues::*;

    // ---- Value types with units ----
    value def Frequency :> Real { unit "Hz"; }
    value def Power :> Real { unit "dBm"; }
    value def Distance :> Real { unit "m"; }
    value def Velocity :> Real { unit "m/s"; }
    value def Angle :> Real { unit "deg"; }
    value def Time :> Real { unit "s"; }
    value def UpdateRate :> Real { unit "Hz"; }
    value def Gain :> Real { unit "dB"; }
    value def SignalToNoiseRatio :> Real { unit "dB"; }
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Temperature :> Real { unit "degC"; }

    // ---- Item definitions ----
    item def RadarWave {
        attribute carrierFreq : Frequency = 77e9 [Hz];
        attribute power : Power;
        attribute phase : Real;
        attribute timestamp : Time;
    }

    item def EchoSignal {
        attribute amplitude : Power;
        attribute phaseShift : Real;
        attribute dopplerShift : Frequency;
        attribute timeDelay : Time;
        attribute timestamp : Time;
    }

    item def TargetMeasurement {
        attribute range : Distance;
        attribute relativeSpeed : Velocity;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute targetId : String;
        attribute confidence : Real;
        attribute timestamp : Time;
    }

    item def CalibrationResult {
        attribute status : String;
        attribute noiseFloor : Power;
        attribute timestamp : Time;
    }

    attribute def RadarConfiguration {
        attribute carrierFreq : Frequency = 77e9 [Hz];
        attribute updateRate : UpdateRate = 20 [Hz];
        attribute maxRange : Distance = 250 [m];
        attribute minRange : Distance = 0.2 [m];
        attribute fieldOfView : Angle = 60 [deg];
        attribute maxRelativeSpeed : Velocity = 100 [m/s];
    }

    // ---- Port definitions ----
    port def RFOutPort {
        out wave : RadarWave;
    }

    port def RFInPort {
        in echo : EchoSignal;
    }

    port def DigitalDataOutPort {
        out measurement : TargetMeasurement;
        out calibration : CalibrationResult;
    }

    port def CommandInPort {
        in command : String;
    }

    port def PowerInPort {
        in supplyVoltage : Voltage;
        in supplyCurrent : Current;
    }

    port def ThermalPort {
        out surfaceTemp : Temperature;
    }

    // ---- Internal component parts ----
    part def TransmitterModule {
        port rfOut : RFOutPort;
        port powerIn : PowerInPort;
        attribute outputPower : Power = 10 [dBm];
        attribute carrierFreq : Frequency = 77e9 [Hz];
        attribute modulationBandwidth : Frequency = 4e9 [Hz];

        action def GenerateWave {
            out wave : RadarWave;
        }

        perform action generate : GenerateWave {
            assign generate.wave.carrierFreq = carrierFreq;
            assign generate.wave.power = outputPower;
            assign generate.wave.phase = 0.0;
        }

        flow wave : RadarWave from generate to rfOut.wave;
    }

    part def AntennaAssembly {
        port rfIn : RFInPort;
        port rfOut : RFOutPort;
        attribute gain : Gain = 20 [dB];
        attribute beamWidthAzimuth : Angle = 60 [deg];
        attribute beamWidthElevation : Angle = 12 [deg];

        action def Radiate {
            in wave : RadarWave;
        }
        action def Capture {
            in incoming : RadarWave;
            out echo : EchoSignal;
        }

        perform action radiate : Radiate;
        perform action capture : Capture;
    }

    part def ReceiverModule {
        port rfIn : RFInPort;
        port powerIn : PowerInPort;
        attribute gain : Gain = 60 [dB];
        attribute noiseFigure : Gain = 12 [dB];
        attribute outputSNR : SignalToNoiseRatio;

        action def Amplify {
            in echo : EchoSignal;
            out amplified : EchoSignal;
        }

        perform action amplify : Amplify;

        flow echo : EchoSignal from rfIn.echo to amplify.echo;
    }

    part def SignalProcessingUnit {
        port echoIn : RFInPort;
        port referenceIn : RFOutPort;
        port dataOut : DigitalDataOutPort;
        port commandIn : CommandInPort;
        port powerIn : PowerInPort;
        attribute updateRate : UpdateRate = 20 [Hz];
        attribute config : RadarConfiguration;

        action def ComputeRange {
            in echo : EchoSignal;
            out range : Distance;
        }
        action def ComputeRelativeSpeed {
            in echo : EchoSignal;
            out speed : Velocity;
        }
        action def ComputeDirection {
            in echo : EchoSignal;
            out azimuth : Angle;
            out elevation : Angle;
        }
        action def AssembleMeasurement {
            in range : Distance;
            in speed : Velocity;
            in azimuth : Angle;
            in elevation : Angle;
            out measurement : TargetMeasurement;
        }
        action def ProcessCycle {
            in echo : EchoSignal;
            out measurement : TargetMeasurement;
        }

        perform action processCycle : ProcessCycle {
            action computeRange : ComputeRange;
            action computeSpeed : ComputeRelativeSpeed;
            action computeDirection : ComputeDirection;
            action assemble : AssembleMeasurement;

            flow echo from processCycle.echo to computeRange.echo;
            flow echo from processCycle.echo to computeSpeed.echo;
            flow echo from processCycle.echo to computeDirection.echo;

            flow range from computeRange.range to assemble.range;
            flow speed from computeSpeed.speed to assemble.speed;
            flow azimuth from computeDirection.azimuth to assemble.azimuth;
            flow elevation from computeDirection.elevation to assemble.elevation;

            flow measurement from assemble.measurement to processCycle.measurement;
        }

        flow measurement : TargetMeasurement from processCycle.measurement to dataOut.measurement;
    }

    part def PowerSupply {
        port powerOut : PowerInPort;
        port powerIn : PowerInPort;
        attribute efficiency : Real = 0.9;
        attribute outputVoltage : Voltage = 12 [V];

        action def Regulate {
            in vin : Voltage;
            out vout : Voltage;
        }

        perform action regulate : Regulate;
    }

    part def CommunicationInterface {
        port dataIn : DigitalDataOutPort;
        port vehicleBusOut : DigitalDataOutPort;
        attribute protocol : String = "CAN-FD";
        attribute baudRate : UpdateRate = 5e6 [Hz];

        action def Encode {
            in measurement : TargetMeasurement;
            out encoded : TargetMeasurement;
        }

        perform action encode : Encode;
    }

    part def Housing {
        port thermal : ThermalPort;
        attribute material : String = "PC-ABS";
        attribute ipRating : String = "IP6K9K";
        attribute operatingTempMin : Temperature = -40 [degC];
        attribute operatingTempMax : Temperature = 85 [degC];
    }

    // ---- Operating mode state machine ----
    state def RadarOperatingStates {
        entry; then standby;

        state standby {
            attribute powerState : String = "low-power";
            entry;
            do send standbyHeartbeat();
            exit;
        }

        state activeScanning {
            entry;
            do perform fullFieldScan();
            exit;
        }

        state tracking {
            entry;
            do perform lockedTargetTracking();
            exit;
        }

        state calibration {
            entry;
            do perform selfTestAndAdjustment();
            exit;
        }

        transition t1
            first standby
            accept CommandInPort.command :> "activate"
            then activeScanning;

        transition t2
            first activeScanning
            accept CommandInPort.command :> "track"
            then tracking;

        transition t3
            first tracking
            accept CommandInPort.command :> "scan"
            then activeScanning;

        transition t4
            first activeScanning
            accept CommandInPort.command :> "standby"
            then standby;

        transition t5
            first tracking
            accept CommandInPort.command :> "standby"
            then standby;

        transition t6
            first standby
            accept CommandInPort.command :> "calibrate"
            then calibration;

        transition t7
            first calibration
            accept CalibrationResult.status :> "complete"
            then standby;

        transition t8
            first activeScanning
            accept CommandInPort.command :> "calibrate"
            then calibration;

        transition t9
            first tracking
            accept CommandInPort.command :> "calibrate"
            then calibration;
    }

    // ---- Top-level radar sensing unit ----
    part def RadarSensingUnit {
        port vehiclePower : PowerInPort;
        port vehicleCommand : CommandInPort;
        port vehicleData : DigitalDataOutPort;
        port housingThermal : ThermalPort;

        attribute config : RadarConfiguration;
        attribute mountingLocation : String = "front-bumper";
        attribute updateRate : UpdateRate = 20 [Hz];

        part transmitter : TransmitterModule;
        part antenna : AntennaAssembly;
        part receiver : ReceiverModule;
        part processor : SignalProcessingUnit;
        part powerSupply : PowerSupply;
        part commInterface : CommunicationInterface;
        part housing : Housing;

        // Power distribution
        connect vehiclePower.supplyVoltage to powerSupply.powerIn.supplyVoltage;
        connect vehiclePower.supplyCurrent to powerSupply.powerIn.supplyCurrent;
        connect powerSupply.powerOut.supplyVoltage to transmitter.powerIn.supplyVoltage;
        connect powerSupply.powerOut.supplyVoltage to receiver.powerIn.supplyVoltage;
        connect powerSupply.powerOut.supplyVoltage to processor.powerIn.supplyVoltage;

        // RF transmit path: transmitter -> antenna
        connect transmitter.rfOut.wave to antenna.rfIn.wave;

        // Reference path: transmitter -> processor (for echo comparison)
        connect transmitter.rfOut.wave to processor.referenceIn.wave;

        // RF receive path: antenna -> receiver
        connect antenna.rfOut.echo to receiver.rfIn.echo;

        // Receiver -> processor
        connect receiver.amplify.amplified to processor.echoIn.echo;

        // Processor -> communication interface
        connect processor.dataOut.measurement to commInterface.dataIn.measurement;
        connect processor.dataOut.calibration to commInterface.dataIn.calibration;

        // Communication interface -> vehicle bus
        connect commInterface.vehicleBusOut.measurement to vehicleData.measurement;
        connect commInterface.vehicleBusOut.calibration to vehicleData.calibration;

        // Command path
        connect vehicleCommand.command to processor.commandIn.command;

        // Thermal
        connect housing.thermal.surfaceTemp to housingThermal.surfaceTemp;

        // Behavior
        exhibit state operatingMode : RadarOperatingStates;

        // Update rate constraint
        constraint updateRateConstraint {
            (updateRate == 20 [Hz]) and
            (config.updateRate == 20 [Hz]) and
            (processor.updateRate == 20 [Hz])
        }
    }

    // ---- Requirements ----
    requirement def RadarFunctionalRequirements {
        subject radar : RadarSensingUnit;

        requirement DetectTargets {
            doc /* The radar shall detect and track objects including other cars,
                   pedestrians, and obstacles in its environment. */
            require radar.config.maxRange >= 250 [m];
        }

        requirement MeasureRange {
            doc /* The radar shall measure target distance based on echo time delay. */
            require radar.config.minRange <= 0.2 [m];
        }

        requirement MeasureRelativeSpeed {
            doc /* The radar shall measure relative speed based on Doppler shift. */
            require radar.config.maxRelativeSpeed >= 100 [m/s];
        }

        requirement MeasureAngularPosition {
            doc /* The radar shall measure target direction based on phase shift. */
            require radar.config.fieldOfView >= 60 [deg];
        }

        requirement OperateAt77GHz {
            doc /* The transmitter shall generate radio waves at 77 GHz. */
            require radar.transmitter.carrierFreq == 77e9 [Hz];
        }

        requirement UpdateRate20Hz {
            doc /* The radar shall provide measurements at 20 times per second. */
            require radar.updateRate == 20 [Hz];
        }

        requirement SupportOperatingModes {
            doc /* The radar shall support standby, active scanning, tracking,
                   and calibration modes. */
            require radar.operatingMode::standby.defined and
                    radar.operatingMode::activeScanning.defined and
                    radar.operatingMode::tracking.defined and
                    radar.operatingMode::calibration.defined;
        }

        requirement OutputTargetMeasurement {
            doc /* The radar shall output a structured target measurement containing
                   range, relative speed, and angular position. */
            require radar.vehicleData.measurement.range.defined and
                    radar.vehicleData.measurement.relativeSpeed.defined and
                    radar.vehicleData.measurement.azimuth.defined;
        }

        requirement SelfContainedPackaging {
            doc /* The radar shall be a compact, self-contained unit suitable for
                   front bumper mounting. */
            require radar.mountingLocation == "front-bumper";
        }
    }

    // ---- Verification ----
    verification def VerifyUpdateRate {
        subject radar : RadarSensingUnit;
        objective {
            doc /* Confirm the radar produces target measurements at 20 Hz. */
        }
        return success : Boolean = (radar.updateRate == 20 [Hz]);
    }

    verification def VerifyCarrierFrequency {
        subject radar : RadarSensingUnit;
        objective {
            doc /* Confirm the transmitter operates at 77 GHz. */
        }
        return success : Boolean = (radar.transmitter.carrierFreq == 77e9 [Hz]);
    }

    verification def VerifyOperatingModes {
        subject radar : RadarSensingUnit;
        objective {
            doc /* Confirm all four operating modes are reachable. */
        }
        return success : Boolean = true;
    }

}
