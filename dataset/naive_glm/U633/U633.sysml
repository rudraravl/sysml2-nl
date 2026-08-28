package CooledCCDImagingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def Temperature :> Real {
        unit K;
    }

    value def Voltage :> Real {
        unit V;
    }

    value def Charge :> Real {
        unit C;
    }

    value def Frequency :> Real {
        unit Hz;
    }

    value def Time :> Real {
        unit s;
    }

    value def PixelCount :> Integer {
        unit "pixel";
    }

    value def DigitalValue :> Integer {
        unit "ADU";
    }

    value def QuantumEfficiency :> Real {
        unit "ratio";
    }

    value def BitDepth :> Integer {
        unit "bit";
    }

    // ===== Item Types =====

    item def Photon;

    item def ChargePacket {
        attribute amount : Charge;
    }

    item def AnalogSignal {
        attribute level : Voltage;
    }

    item def PixelValue {
        attribute value : DigitalValue;
        attribute row : Integer;
        attribute column : Integer;
    }

    item def DigitalImage {
        attribute width : PixelCount = 2048;
        attribute height : PixelCount = 2048;
        attribute pixels : PixelValue[0..*];
    }

    // ===== Port Definitions =====

    port def LightPort {
        out photons : Photon [0..*];
    }

    port def ChargePort {
        out charge : ChargePacket [0..*];
    }

    port def AnalogPort {
        out signal : AnalogSignal [0..*];
    }

    port def DigitalPort {
        out data : PixelValue [0..*];
    }

    port def ClockPort {
        out clockSignal : Frequency [0..*];
    }

    port def ThermalPort {
        in heatFlow : Real;
        out temperature : Temperature;
    }

    // ===== CCD Sensor =====

    part def CCDSensor {
        attribute rows : PixelCount = 2048;
        attribute columns : PixelCount = 2048;
        attribute quantumEfficiency : QuantumEfficiency = 0.90;
        attribute operatingTemperature : Temperature = 233.15 [K];
        attribute darkCurrent : Charge = 0.000000000001 [C];

        port lightIn : LightPort;
        port chargeOut : ChargePort;
        port thermalInterface : ThermalPort;
        port clockIn : ClockPort;

        attribute pixelArray : ChargePacket[2048, 2048];

        state def CCDOperation {
            entry;
            state Integrating {
                entry;
                do integrateLight;
            }
            state VerticalTransfer {
                entry;
                do shiftVerticalRegister;
            }
            state HorizontalTransfer {
                entry;
                do shiftHorizontalRegister;
            }
            transition integrating_to_vertical
                source Integrating
                target VerticalTransfer
                when integrationComplete;
            transition vertical_to_horizontal
                source VerticalTransfer
                target HorizontalTransfer
                when verticalTransferComplete;
            transition horizontal_to_idle
                source HorizontalTransfer
                target Integrating
                when horizontalTransferComplete;
        }

        action integrateLight {
            in photons : Photon [0..*];
            out charge : ChargePacket [0..*];
        }

        action shiftVerticalRegister {
            in clock : Frequency;
            out charge : ChargePacket [0..*];
        }

        action shiftHorizontalRegister {
            in clock : Frequency;
            out charge : ChargePacket [0..*];
        }

        exhibit state machine CCDOperation;
    }

    // ===== Vertical Register =====

    part def VerticalRegister {
        attribute capacity : PixelCount = 2048;
        port chargeIn : ChargePort;
        port chargeOut : ChargePort;
        port clockIn : ClockPort;

        action shiftDown {
            in charge : ChargePacket [0..*];
            in clock : Frequency;
            out shiftedCharge : ChargePacket [0..*];
        }
    }

    // ===== Horizontal Register =====

    part def HorizontalRegister {
        attribute capacity : PixelCount = 2048;
        port chargeIn : ChargePort;
        port chargeOut : ChargePort;
        port clockIn : ClockPort;

        action shiftOut {
            in charge : ChargePacket [0..*];
            in clock : Frequency;
            out serialCharge : ChargePacket [0..*];
        }
    }

    // ===== Low-Noise Amplifier =====

    part def LowNoiseAmplifier {
        attribute gain : Real = 1.0;
        attribute noiseFloor : Voltage = 0.000001 [V];
        port chargeIn : ChargePort;
        port analogOut : AnalogPort;
        port clockIn : ClockPort;

        action convertChargeToVoltage {
            in charge : ChargePacket;
            out signal : AnalogSignal;
        }
    }

    // ===== Analog-to-Digital Converter =====

    part def AnalogToDigitalConverter {
        attribute resolution : BitDepth = 16;
        attribute maxDigitalValue : DigitalValue = 65535;
        attribute referenceVoltage : Voltage = 5.0 [V];
        port analogIn : AnalogPort;
        port digitalOut : DigitalPort;
        port clockIn : ClockPort;

        action digitize {
            in signal : AnalogSignal;
            out pixelValue : PixelValue;
        }
    }

    // ===== Cooling System =====

    part def CoolingSystem {
        attribute targetTemperature : Temperature = 233.15 [K];
        attribute ambientTemperature : Temperature = 293.15 [K];
        attribute coolingCapacity : Real = 50.0;
        port thermalOut : ThermalPort;

        state def CoolingOperation {
            state Active {
                entry;
                do circulateCoolant;
            }
            state Standby {
                entry;
            }
            transition standby_to_active
                source Standby
                target Active
                when sensorTemperature > targetTemperature;
            transition active_to_standby
                source Active
                target Standby
                when sensorTemperature <= targetTemperature;
        }

        action circulateCoolant {
            out coolingEffect : Real;
        }

        attribute sensorTemperature : Temperature;

        exhibit state machine CoolingOperation;
    }

    // ===== Timing Generator =====

    part def TimingGenerator {
        attribute masterClockFrequency : Frequency = 20000000 [Hz];
        attribute verticalClockFrequency : Frequency = 100000 [Hz];
        attribute horizontalClockFrequency : Frequency = 1000000 [Hz];
        attribute adcClockFrequency : Frequency = 2000000 [Hz];

        port sensorClock : ClockPort;
        port verticalRegisterClock : ClockPort;
        port horizontalRegisterClock : ClockPort;
        port amplifierClock : ClockPort;
        port adcClock : ClockPort;

        action generateClocks {
            out sensorClk : Frequency;
            out verticalClk : Frequency;
            out horizontalClk : Frequency;
            out amplifierClk : Frequency;
            out adcClk : Frequency;
        }
    }

    // ===== Image Processor =====

    part def ImageProcessor {
        port dataIn : DigitalPort;
        port imageOut : DigitalPort;

        action assembleImage {
            in pixelValues : PixelValue [0..*];
            out image : DigitalImage;
        }
    }

    // ===== System Integration =====

    part def CooledCCDImager {

        port lightInput : LightPort;
        port imageOutput : DigitalPort;

        part sensor : CCDSensor {
            port lightIn : LightPort;
            port chargeOut : ChargePort;
            port thermalInterface : ThermalPort;
            port clockIn : ClockPort;
        }

        part verticalRegister : VerticalRegister {
            port chargeIn : ChargePort;
            port chargeOut : ChargePort;
            port clockIn : ClockPort;
        }

        part horizontalRegister : HorizontalRegister {
            port chargeIn : ChargePort;
            port chargeOut : ChargePort;
            port clockIn : ClockPort;
        }

        part amplifier : LowNoiseAmplifier {
            port chargeIn : ChargePort;
            port analogOut : AnalogPort;
            port clockIn : ClockPort;
        }

        part adc : AnalogToDigitalConverter {
            port analogIn : AnalogPort;
            port digitalOut : DigitalPort;
            port clockIn : ClockPort;
        }

        part coolingSystem : CoolingSystem {
            port thermalOut : ThermalPort;
        }

        part timingGenerator : TimingGenerator {
            port sensorClock : ClockPort;
            port verticalRegisterClock : ClockPort;
            port horizontalRegisterClock : ClockPort;
            port amplifierClock : ClockPort;
            port adcClock : ClockPort;
        }

        part imageProcessor : ImageProcessor {
            port dataIn : DigitalPort;
            port imageOut : DigitalPort;
        }

        // Connections: Light path
        connection lightPath connect lightInput to sensor.lightIn;

        // Connections: Charge transfer path
        connection chargeTransfer1 connect sensor.chargeOut to verticalRegister.chargeIn;
        connection chargeTransfer2 connect verticalRegister.chargeOut to horizontalRegister.chargeIn;
        connection chargeTransfer3 connect horizontalRegister.chargeOut to amplifier.chargeIn;

        // Connections: Analog signal path
        connection analogPath connect amplifier.analogOut to adc.analogIn;

        // Connections: Digital data path
        connection digitalPath connect adc.digitalOut to imageProcessor.dataIn;
        connection imageOutputPath connect imageProcessor.imageOut to imageOutput;

        // Connections: Clock distribution
        connection sensorClockLine connect timingGenerator.sensorClock to sensor.clockIn;
        connection verticalClockLine connect timingGenerator.verticalRegisterClock to verticalRegister.clockIn;
        connection horizontalClockLine connect timingGenerator.horizontalRegisterClock to horizontalRegister.clockIn;
        connection amplifierClockLine connect timingGenerator.amplifierClock to amplifier.clockIn;
        connection adcClockLine connect timingGenerator.adcClock to adc.clockIn;

        // Connections: Thermal management
        connection thermalLink connect coolingSystem.thermalOut to sensor.thermalInterface;

        // System-level state machine
        state def ImagingCycle {
            state Exposure {
                entry;
                do collectLight;
            }
            state Readout {
                entry;
                do performReadout;
            }
            state ImageAssembly {
                entry;
                do assembleDigitalImage;
            }
            transition exposure_to_readout
                source Exposure
                target Readout
                when exposureTimeElapsed;
            transition readout_to_assembly
                source Readout
                target ImageAssembly
                when allPixelsRead;
            transition assembly_to_exposure
                source ImageAssembly
                target Exposure
                when imageComplete;
        }

        action collectLight {
            in photons : Photon [0..*];
        }

        action performReadout {
            out charge : ChargePacket [0..*];
            out analog : AnalogSignal [0..*];
            out digital : PixelValue [0..*];
        }

        action assembleDigitalImage {
            in pixelValues : PixelValue [0..*];
            out image : DigitalImage;
        }

        exhibit state machine ImagingCycle;
    }

    // ===== Requirements =====

    requirement def HighSensitivityRequirement {
        subject sensor : CCDSensor;
        objective {
            assert sensor.quantumEfficiency >= 0.90;
        }
    }

    requirement def LowNoiseRequirement {
        subject amplifier : LowNoiseAmplifier;
        objective {
            assert amplifier.noiseFloor <= 0.000001 [V];
        }
    }

    requirement def CoolingRequirement {
        subject coolingSystem : CoolingSystem;
        objective {
            assert coolingSystem.targetTemperature <= 233.15 [K];
        }
    }

    requirement def ResolutionRequirement {
        subject adc : AnalogToDigitalConverter;
        objective {
            assert adc.resolution >= 16 [bit];
        }
    }

    requirement def SensorSizeRequirement {
        subject sensor : CCDSensor;
        objective {
            assert sensor.rows == 2048;
            assert sensor.columns == 2048;
        }
    }

    requirement def ReadoutFidelityRequirement {
        subject imager : CooledCCDImager;
        objective {
            assert imager.sensor.quantumEfficiency >= 0.90;
            assert imager.coolingSystem.targetTemperature <= 233.15 [K];
            assert imager.adc.resolution >= 16 [bit];
        }
    }

    requirement HighSensitivity : HighSensitivityRequirement {
        subject :>> sensor = CooledCCDImager.sensor;
    }

    requirement LowNoise : LowNoiseRequirement {
        subject :>> amplifier = CooledCCDImager.amplifier;
    }

    requirement ActiveCooling : CoolingRequirement {
        subject :>> coolingSystem = CooledCCDImager.coolingSystem;
    }

    requirement HighResolution : ResolutionRequirement {
        subject :>> adc = CooledCCDImager.adc;
    }

    requirement LargeSensor : SensorSizeRequirement {
        subject :>> sensor = CooledCCDImager.sensor;
    }

    requirement SystemFidelity : ReadoutFidelityRequirement {
        subject :>> imager = CooledCCDImager;
    }

}
