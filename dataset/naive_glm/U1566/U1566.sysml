package SpacecraftSolarPowerSystem {
    import ScalarValues::*;
    import MeasurementReferences::*;

    // Units and Value Types
    unit Volt { symbol = "V"; }
    unit Ampere { symbol = "A"; }
    unit Watt { symbol = "W"; }
    unit Degree { symbol = "deg"; }
    unit Lux { symbol = "lx"; }
    unit WattHour { symbol = "Wh"; }

    attribute def Voltage :> Real { :>> unit = Volt; }
    attribute def Current :> Real { :>> unit = Ampere; }
    attribute def Power :> Real { :>> unit = Watt; }
    attribute def Angle :> Real { :>> unit = Degree; }
    attribute def Intensity :> Real { :>> unit = Lux; }
    attribute def Energy :> Real { :>> unit = WattHour; }

    // Items
    item def Sunlight;
    item def RawPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def RegulatedPower {
        attribute voltage : Voltage = 28;
        attribute current : Current;
    }
    item def SunVector {
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute intensity : Intensity;
    }
    item def GimbalCommand {
        attribute targetAzimuth : Angle;
        attribute targetElevation : Angle;
    }
    item def MechanicalRotation {
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    // Ports
    port def SunlightInPort { in sunlight : Sunlight; }
    port def RawPowerOutPort { out rawPower : RawPower; }
    port def RawPowerInPort { in rawPower : RawPower; }
    port def PowerOutPort { out power : RegulatedPower; }
    port def PowerInPort { in power : RegulatedPower; }
    port def SunVecOutPort { out sunVector : SunVector; }
    port def SunVecInPort { in sunVector : SunVector; }
    port def CmdOutPort { out cmd : GimbalCommand; }
    port def CmdInPort { in cmd : GimbalCommand; }
    port def MechOutPort { out rotation : MechanicalRotation; }
    port def MechInPort { in rotation : MechanicalRotation; }

    // Components
    part def SolarCell {
        attribute efficiency : Real;
        port rawPowerOut : RawPowerOutPort;
    }
    part def SolarPanel {
        part cells : SolarCell[32];
        port rawPowerOut : RawPowerOutPort;
    }
    part def SolarArray {
        part panels : SolarPanel[4];
        port sunlightIn : SunlightInPort;
        port rawPowerOut : RawPowerOutPort;
        port mechIn : MechInPort;
    }
    part def SunSensor {
        port sunVecOut : SunVecOutPort;
    }
    part def AttitudeController {
        port sunVecIn : SunVecInPort;
        port cmdOut : CmdOutPort;
    }
    part def GimbalActuator {
        port cmdIn : CmdInPort;
        port mechOut : MechOutPort;
    }
    part def PowerRegulator {
        attribute targetVoltage : Voltage = 28;
        port rawPowerIn : RawPowerInPort;
        port regulatedPowerOut : PowerOutPort;
    }
    part def Battery {
        attribute capacity : Energy = 1000;
        attribute chargeLevel : Energy;
        port chargePowerIn : PowerInPort;
        port dischargePowerOut : PowerOutPort;
    }
    part def Load {
        abstract;
        port powerIn : PowerInPort;
    }
    part def CommsLoad :> Load {}
    part def ScienceLoad :> Load {}
    part def ThermalLoad :> Load {}
    part def PowerDistributionUnit {
        port mainPowerIn : PowerInPort;
        port batteryChargeOut : PowerOutPort;
        port batteryDischargeIn : PowerInPort;
        port commsOut : PowerOutPort;
        port scienceOut : PowerOutPort;
        port thermalOut : PowerOutPort;
    }

    // State Machine
    state machine def PowerSystemStateMachine {
        attribute orbitAchieved : Boolean;
        attribute arrayDeployed : Boolean;
        attribute sunLocked : Boolean;
        attribute eclipseDetected : Boolean;
        attribute eclipseEnded : Boolean;
        attribute faultDetected : Boolean;
        attribute faultCleared : Boolean;

        state Stowed;
        state Deploying;
        state SunAcquisition;
        state NominalOperation;
        state Eclipse;
        state SafeMode;

        transition initial to Stowed;
        transition Stowed to Deploying when orbitAchieved;
        transition Deploying to SunAcquisition when arrayDeployed;
        transition SunAcquisition to NominalOperation when sunLocked;
        transition NominalOperation to Eclipse when eclipseDetected;
        transition Eclipse to NominalOperation when eclipseEnded;
        transition NominalOperation to SafeMode when faultDetected;
        transition Eclipse to SafeMode when faultDetected;
        transition SafeMode to SunAcquisition when faultCleared;
    }

    // Requirements
    requirement def SpacecraftSolarPowerRequirement {
        doc /* The system shall autonomously capture sunlight, convert it into regulated electricity, and distribute it to the spacecraft's various subsystems, while also storing energy for periods when the sun is not visible. */
    }

    // System
    part def SpacecraftSolarPowerSystem {
        port sunlightIn : SunlightInPort;
        
        part solarArray : SolarArray;
        part sunSensor : SunSensor;
        part attitudeController : AttitudeController;
        part gimbalActuator : GimbalActuator;
        part powerRegulator : PowerRegulator;
        part pdu : PowerDistributionUnit;
        part battery : Battery;
        part commsLoad : CommsLoad;
        part scienceLoad : ScienceLoad;
        part thermalLoad : ThermalLoad;

        state machine powerState : PowerSystemStateMachine;
        requirement powerReq : SpacecraftSolarPowerRequirement;
        satisfy powerReq;

        // Connections
        connect sunlightIn to solarArray.sunlightIn;
        connect solarArray.rawPowerOut to powerRegulator.rawPowerIn;
        connect powerRegulator.regulatedPowerOut to pdu.mainPowerIn;
        connect pdu.commsOut to commsLoad.powerIn;
        connect pdu.scienceOut to scienceLoad.powerIn;
        connect pdu.thermalOut to thermalLoad.powerIn;
        connect pdu.batteryChargeOut to battery.chargePowerIn;
        connect battery.dischargePowerOut to pdu.batteryDischargeIn;
        connect sunSensor.sunVecOut to attitudeController.sunVecIn;
        connect attitudeController.cmdOut to gimbalActuator.cmdIn;
        connect gimbalActuator.mechOut to solarArray.mechIn;
    }
}
