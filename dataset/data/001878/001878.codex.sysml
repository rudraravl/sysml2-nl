package ThunderboltSirenModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage {
        :> ISQ::electricPotential;
        unit = "V";
    }

    attribute def Current {
        :> ISQ::electricCurrent;
        unit = "A";
    }

    attribute def Power {
        :> ISQ::power;
        unit = "W";
    }

    attribute def Frequency {
        :> ISQ::frequency;
        unit = "Hz";
    }

    attribute def SoundPressureLevel {
        unit = "dB";
    }

    attribute def RotationSpeed {
        unit = "rpm";
    }

    attribute def Angle {
        unit = "deg";
    }

    attribute def Duration {
        :> ISQ::time;
        unit = "s";
    }

    attribute def AirPressure {
        unit = "kPa";
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = "degC";
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
        attribute frequency : Frequency;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute commandKind : CommandKind;
        attribute requestedSignal : SignalPatternKind;
        attribute requestedDuration : Duration;
    }

    enum def CommandKind {
        enum idle;
        enum arm;
        enum sound;
        enum stop;
        enum test;
        enum resetFault;
    }

    enum def SignalPatternKind {
        enum steady;
        enum attack;
        enum alert;
        enum hiLo;
        enum testGrowl;
    }

    item def StatusMessage {
        attribute operatingState : SirenStateKind;
        attribute activeSignal : SignalPatternKind;
        attribute motorSpeed : RotationSpeed;
        attribute airPressure : AirPressure;
        attribute hornAzimuth : Angle;
        attribute acousticOutput : SoundPressureLevel;
        attribute faultPresent : Boolean;
    }

    enum def SirenStateKind {
        enum off;
        enum standby;
        enum armed;
        enum starting;
        enum sounding;
        enum stopping;
        enum test;
        enum fault;
    }

    item def CompressedAirFlow {
        attribute pressure : AirPressure;
        attribute flowRate {
            unit = "m^3/s";
        }
        attribute temperature : Temperature;
    }

    item def AcousticWave {
        attribute dominantFrequency : Frequency;
        attribute soundLevelAtThirtyMeters : SoundPressureLevel;
        attribute pattern : SignalPatternKind;
    }

    item def MechanicalTorque {
        attribute speed : RotationSpeed;
        attribute torque {
            unit = "N*m";
        }
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def CommandInputPort {
        in item commandIn : ControlCommand;
    }

    port def StatusOutputPort {
        out item statusOut : StatusMessage;
    }

    port def AirPort {
        out item airOut : CompressedAirFlow;
        in item airIn : CompressedAirFlow;
    }

    port def AcousticOutputPort {
        out item soundOut : AcousticWave;
    }

    port def TorquePort {
        out item torqueOut : MechanicalTorque;
        in item torqueIn : MechanicalTorque;
    }

    part def ThunderboltSirenSystem {
        attribute primaryFunction : String = "Convert authorized warning commands and electrical energy into a high-intensity rotating outdoor acoustic warning signal.";
        attribute ratedInputVoltage : Voltage = 240 [V];
        attribute ratedInputPower : Power = 10000 [W];
        attribute maximumAcousticOutput : SoundPressureLevel = 127 [dB];
        attribute nominalSignalFrequency : Frequency = 500 [Hz];
        attribute nominalHornRotationSpeed : RotationSpeed = 3 [rpm];

        port acPower : PowerInputPort;
        port commandReceiver : CommandInputPort;
        port statusTransmitter : StatusOutputPort;
        port acousticEmitter : AcousticOutputPort;

        part controller : SirenController;
        part powerCabinet : PowerCabinet;
        part blowerMotor : BlowerMotor;
        part airCompressor : AirCompressor;
        part chopperAssembly : ChopperAssembly;
        part rotatingHorn : RotatingHorn;
        part rotatorDrive : RotatorDrive;
        part healthMonitor : HealthMonitor;
        part enclosure : WeatherResistantEnclosure;

        connect acPower.powerIn to powerCabinet.inputPower.powerIn;
        connect commandReceiver.commandIn to controller.commandPort.commandIn;
        connect controller.powerCommand.commandIn to powerCabinet.controlPort.commandIn;
        connect powerCabinet.motorPower.powerIn to blowerMotor.electricalInput.powerIn;
        connect blowerMotor.shaftTorque.torqueOut to airCompressor.driveTorque.torqueIn;
        connect airCompressor.compressedAir.airOut to chopperAssembly.airInput.airIn;
        connect chopperAssembly.pulsedAir.airOut to rotatingHorn.airInput.airIn;
        connect rotatorDrive.rotationTorque.torqueOut to rotatingHorn.rotationInput.torqueIn;
        connect rotatingHorn.acousticOutput.soundOut to acousticEmitter.soundOut;
        connect healthMonitor.statusPort.statusOut to statusTransmitter.statusOut;

        perform behavior sirenLifecycle;
    }

    part def PowerCabinet {
        attribute breakerClosed : Boolean;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute outputPower : Power;

        port inputPower : PowerInputPort;
        port controlPort : CommandInputPort;
        port motorPower : PowerInputPort;
    }

    part def SirenController {
        attribute armed : Boolean;
        attribute selectedPattern : SignalPatternKind;
        attribute commandedDuration : Duration;
        attribute watchdogHealthy : Boolean;

        port commandPort : CommandInputPort;
        port powerCommand : CommandInputPort;

        action def validateCommand {
            in item received : ControlCommand;
            out item accepted : Boolean;
        }

        action def selectSignalPattern {
            in item received : ControlCommand;
            out item pattern : SignalPatternKind;
        }
    }

    part def BlowerMotor {
        attribute ratedVoltage : Voltage = 240 [V];
        attribute ratedPower : Power = 7500 [W];
        attribute nominalSpeed : RotationSpeed = 3450 [rpm];
        attribute actualSpeed : RotationSpeed;
        attribute windingTemperature : Temperature;

        port electricalInput : PowerInputPort;
        port shaftTorque : TorquePort;
    }

    part def AirCompressor {
        attribute inletPressure : AirPressure = 101.3 [kPa];
        attribute dischargePressure : AirPressure;
        attribute nominalDischargePressure : AirPressure = 155 [kPa];

        port driveTorque : TorquePort;
        port compressedAir : AirPort;
    }

    part def ChopperAssembly {
        attribute chopperSlotCount : Integer = 10;
        attribute chopperSpeed : RotationSpeed;
        attribute generatedToneFrequency : Frequency;

        port airInput : AirPort;
        port pulsedAir : AirPort;

        action def modulateAirflow {
            in item continuousAir : CompressedAirFlow;
            out item pulsedAirflow : CompressedAirFlow;
        }
    }

    part def RotatingHorn {
        attribute hornAzimuth : Angle;
        attribute acousticGain : SoundPressureLevel;
        attribute outletDiameter {
            unit = "m";
        } = 0.56 [m];

        port airInput : AirPort;
        port rotationInput : TorquePort;
        port acousticOutput : AcousticOutputPort;

        action def projectSound {
            in item pulsedAirflow : CompressedAirFlow;
            out item warningTone : AcousticWave;
        }
    }

    part def RotatorDrive {
        attribute motorVoltage : Voltage = 120 [V];
        attribute rotationSpeed : RotationSpeed = 3 [rpm];
        attribute gearRatio : Real = 1200.0;

        port rotationTorque : TorquePort;
    }

    part def HealthMonitor {
        attribute lowPressureFault : Boolean;
        attribute overTemperatureFault : Boolean;
        attribute rotationFault : Boolean;
        attribute powerFault : Boolean;

        port statusPort : StatusOutputPort;

        action def evaluateFaults {
            in attribute motorTemperature : Temperature;
            in attribute compressorPressure : AirPressure;
            in attribute hornSpeed : RotationSpeed;
            out attribute faultPresent : Boolean;
        }
    }

    part def WeatherResistantEnclosure {
        attribute ingressProtectionRating : String = "NEMA 4";
        attribute minimumOperatingTemperature : Temperature = -30 [degC];
        attribute maximumOperatingTemperature : Temperature = 50 [degC];
        attribute corrosionResistantFinish : Boolean = true;
    }

    action def StartSiren {
        in item command : ControlCommand;
        out item initialStatus : StatusMessage;

        first start;
        then energizeBlower;
        then accelerateChopper;
        then enableHornRotation;
        then reportStarted;
    }

    action def SoundWarning {
        in item pattern : SignalPatternKind;
        in attribute duration : Duration;
        out item emittedWave : AcousticWave;

        first establishAirPressure;
        then modulateTone;
        then rotateHorn;
        then emitDirectionalWarning;
    }

    action def StopSiren {
        out item stoppedStatus : StatusMessage;

        first removeMotorPower;
        then ventAirPressure;
        then brakeRotation;
        then reportStandby;
    }

    state def SirenLifecycle {
        state off;
        state standby;
        state armed;
        state starting;
        state sounding;
        state stopping;
        state test;
        state fault;

        transition initial then off;
        transition off_to_standby
            first off
            accept PowerAvailable
            then standby;

        transition standby_to_armed
            first standby
            accept ArmCommand
            then armed;

        transition armed_to_starting
            first armed
            accept SoundCommand
            do StartSiren
            then starting;

        transition starting_to_sounding
            first starting
            accept NominalSpeedReached
            then sounding;

        transition sounding_to_stopping
            first sounding
            accept StopCommand
            do StopSiren
            then stopping;

        transition sounding_duration_complete
            first sounding
            accept SignalDurationElapsed
            do StopSiren
            then stopping;

        transition stopping_to_standby
            first stopping
            accept RotationStopped
            then standby;

        transition standby_to_test
            first standby
            accept TestCommand
            then test;

        transition test_to_standby
            first test
            accept TestComplete
            then standby;

        transition any_to_fault
            first off
            accept FaultDetected
            then fault;

        transition fault_reset
            first fault
            accept ResetFaultCommand
            then standby;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Thunderbolt siren system shall provide high-level outdoor public warning by converting a valid remote or local activation command into a loud, rotating acoustic signal. */
    }

    requirement def AcousticCoverageRequirement {
        attribute requiredLevelAtThirtyMeters : SoundPressureLevel = 120 [dB];
        doc /* The siren shall emit a warning tone of at least the required sound pressure level at 30 meters when operating in alert or attack signal modes. */
    }

    requirement def RotationRequirement {
        attribute requiredRotationSpeed : RotationSpeed = 3 [rpm];
        doc /* The horn shall rotate during normal warning operation to distribute the acoustic signal across a full 360 degree azimuth. */
    }

    requirement def CommandSafetyRequirement {
        doc /* The controller shall sound the siren only after receiving a valid arm or sound command and shall stop the siren on explicit stop, elapsed duration, or detected fault. */
    }

    requirement def FaultMonitoringRequirement {
        doc /* The system shall monitor electrical power, motor temperature, compressor pressure, and horn rotation and shall enter the fault state when monitored values are outside allowable limits. */
    }

    satisfy PrimaryFunctionRequirement by ThunderboltSirenSystem;
    satisfy AcousticCoverageRequirement by ThunderboltSirenSystem::rotatingHorn;
    satisfy RotationRequirement by ThunderboltSirenSystem::rotatorDrive;
    satisfy CommandSafetyRequirement by ThunderboltSirenSystem::controller;
    satisfy FaultMonitoringRequirement by ThunderboltSirenSystem::healthMonitor;
}