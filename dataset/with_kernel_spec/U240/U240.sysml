package HEALS_System {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Wavelength :> Real;
    attribute def Temperature :> Real;
    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Power :> Real;
    attribute def FlowRate :> Real;
    attribute def Emissivity :> Real;

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def OpticalRadiation {
        attribute peakWavelength : Wavelength = 550 [SI::nm];
        attribute power : Power;
    }

    item def Heat {
        attribute power : Power;
    }

    item def Coolant {
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }

    item def PowerOn;
    item def PowerOff;
    item def Overheat;
    item def TempNormal;

    port def ElectricalInputPort {
        in item power : ElectricalEnergy;
    }

    port def ElectricalOutputPort {
        out item power : ElectricalEnergy;
    }

    port def OpticalInputPort {
        in item light : OpticalRadiation;
    }

    port def OpticalOutputPort {
        out item light : OpticalRadiation;
    }

    port def ThermalInputPort {
        in item heat : Heat;
    }

    port def ThermalOutputPort {
        out item heat : Heat;
    }

    port def CoolantInputPort {
        in item coolant : Coolant;
    }

    port def CoolantOutputPort {
        out item coolant : Coolant;
    }

    port def ControlPort {
        in item powerOn : PowerOn;
        in item powerOff : PowerOff;
        in item overheat : Overheat;
        in item tempNormal : TempNormal;
    }

    action def EmitLight {
        in electrical : ElectricalEnergy;
        out forwardLight : OpticalRadiation;
        out backwardLight : OpticalRadiation;
        out heat : Heat;
    }

    action def ReflectLight {
        in backwardLight : OpticalRadiation;
        out forwardLight : OpticalRadiation;
    }

    action def TransmitLight {
        in light : OpticalRadiation;
        out transmittedLight : OpticalRadiation;
    }

    action def RegulatePower {
        in inputPower : ElectricalEnergy;
        out outputPower : ElectricalEnergy;
    }

    action def ManageCooling {
        in heat : Heat;
        in coolantIn : Coolant;
        out coolantOut : Coolant;
    }

    action def PumpCoolant {
        out flow : Coolant;
    }

    action def Warmup;
    action def ProvideStableLight;
    action def RegulateTemperature;
    action def EmergencyCooling;
    action def Cooldown;

    part def HeatSink {
        attribute thermalResistance : Real;
        port thermalIn : ThermalInputPort;
        port thermalOut : ThermalOutputPort;
    }

    part def CoolantChannel {
        port coolantIn : CoolantInputPort;
        port coolantOut : CoolantOutputPort;
        port thermalIn : ThermalInputPort;
        perform action pumpCoolant : PumpCoolant;
    }

    part def LuminescentPhosphorLayer {
        attribute matrix : String = "Yttrium Aluminum Garnet";
        attribute aluminumConcentration : Real;
        attribute phosphorDopantConcentration : Real;
        port electricalIn : ElectricalInputPort;
        port opticalForwardOut : OpticalOutputPort;
        port opticalBackwardOut : OpticalOutputPort;
        port thermalOut : ThermalOutputPort;
        perform action emitLight : EmitLight;
    }

    part def AluminumReflectorLayer {
        attribute emissivity : Emissivity = 0.9;
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        port thermalIn : ThermalInputPort;
        port thermalOut : ThermalOutputPort;
        perform action reflectLight : ReflectLight;
    }

    part def EncapsulationLayer {
        attribute material : String = "Silicone Composite";
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        perform action transmitLight : TransmitLight;
    }

    part def PowerSupplyUnit {
        attribute outputVoltage : Voltage = 24 [SI::V];
        attribute outputCurrent : Current = 2 [SI::A];
        port powerIn : ElectricalInputPort;
        port powerOut : ElectricalOutputPort;
        port thermalOut : ThermalOutputPort;
        perform action regulatePower : RegulatePower;
    }

    part def ThermalManagementSubsystem {
        attribute currentTemperature : Temperature;
        port thermalIn : ThermalInputPort;
        port coolantIn : CoolantInputPort;
        port coolantOut : CoolantOutputPort;
        part heatSink : HeatSink;
        part coolantChannel : CoolantChannel;
        connect thermalIn to heatSink.thermalIn;
        connect heatSink.thermalOut to coolantChannel.thermalIn;
        connect coolantIn to coolantChannel.coolantIn;
        connect coolantChannel.coolantOut to coolantOut;
        perform action manageCooling : ManageCooling;
    }

    part def HEALSDevice {
        attribute maxOperatingTemp : Temperature = 350 [SI::K];
        attribute safeOperatingTemp : Temperature = 300 [SI::K];
        attribute internalTemperature : Temperature;
        port powerIn : ElectricalInputPort;
        port controlPort : ControlPort;
        port lightOut : OpticalOutputPort;
        port coolantIn : CoolantInputPort;
        port coolantOut : CoolantOutputPort;

        part powerSupply : PowerSupplyUnit;
        part phosphor : LuminescentPhosphorLayer;
        part reflector : AluminumReflectorLayer;
        part encapsulation : EncapsulationLayer;
        part thermal : ThermalManagementSubsystem;

        perform action warmupAct : Warmup;
        perform action provideStableLightAct : ProvideStableLight;
        perform action regulateTemperatureAct : RegulateTemperature;
        perform action emergencyCoolingAct : EmergencyCooling;
        perform action cooldownAct : Cooldown;

        connect powerIn to powerSupply.powerIn;
        connect powerSupply.powerOut to phosphor.electricalIn;
        connect phosphor.opticalForwardOut to encapsulation.opticalIn;
        connect phosphor.opticalBackwardOut to reflector.opticalIn;
        connect reflector.opticalOut to encapsulation.opticalIn;
        connect encapsulation.opticalOut to lightOut;

        connect phosphor.thermalOut to reflector.thermalIn;
        connect reflector.thermalOut to thermal.thermalIn;
        connect powerSupply.thermalOut to thermal.thermalIn;

        connect coolantIn to thermal.coolantIn;
        connect thermal.coolantOut to coolantOut;

        exhibit state operationalState {
            entry; then standby;

            state standby;
            accept PowerOn via controlPort then warmup;

            state warmup;
            accept after 30 [SI::s] then active;
            accept PowerOff via controlPort then cooldown;

            state active;
            accept Overheat via controlPort then overtemperature;
            accept PowerOff via controlPort then cooldown;

            state overtemperature;
            accept TempNormal via controlPort then active;
            accept PowerOff via controlPort then cooldown;

            state cooldown;
            accept after 120 [SI::s] then standby;
        }
    }

    requirement def GreenLightEmissionRequirement {
        doc /* The HEALS system shall emit optical radiation peaking at 550 nm. */
        subject device : HEALSDevice;
    }

    requirement def ThermalManagementRequirement {
        doc /* The HEALS system shall maintain internal temperature at or below 350 K during active operation. */
        subject device : HEALSDevice;
    }

    requirement def HighEmissivityRequirement {
        doc /* The aluminum reflector layer shall have an emissivity of at least 0.8 for radiative cooling. */
        subject reflector : AluminumReflectorLayer;
    }

    part heals : HEALSDevice;
}
