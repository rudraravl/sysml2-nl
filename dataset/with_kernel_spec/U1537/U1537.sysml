package WindTurbineSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def WindSpeedValue :> ISQ::speed;
    attribute def WindDirectionValue :> ISQ::planeAngle;
    attribute def TorqueValue :> ISQ::torque;
    attribute def RotationalSpeedValue :> ISQ::angularVelocity;
    attribute def PowerValue :> ISQ::power;
    attribute def VoltageValue :> ISQ::electricPotential;
    attribute def LengthValue :> ISQ::length;
    attribute def AngleValue :> ISQ::planeAngle;
    attribute def GearRatioValue :> Real;

    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeedValue;
    }
    item def ElectricalPower {
        attribute power : PowerValue;
        attribute voltage : VoltageValue;
    }
    item def WindCondition {
        attribute speed : WindSpeedValue;
        attribute direction : WindDirectionValue;
    }
    item def ControlCommand {
        attribute yawAngle : AngleValue;
        attribute pitchAngle : AngleValue;
        attribute brakeEngaged : Boolean;
    }

    port def MechanicalPort {
        attribute mechanical : MechanicalPower;
    }
    port def ElectricalPort {
        attribute electrical : ElectricalPower;
    }
    port def GridPort {
        attribute electrical : ElectricalPower;
    }
    port def WindSensorPort {
        attribute wind : WindCondition;
    }
    port def ControlCommandPort {
        attribute command : ControlCommand;
    }

    action def CaptureWindEnergy {
        in wind : WindCondition;
        out mechanical : MechanicalPower;
    }
    action def IncreaseRotationalSpeed {
        in lowSpeedMech : MechanicalPower;
        out highSpeedMech : MechanicalPower;
        attribute ratio : GearRatioValue = 95;
        constraint { highSpeedMech.rotationalSpeed == lowSpeedMech.rotationalSpeed * ratio }
        constraint { highSpeedMech.torque == lowSpeedMech.torque / ratio }
    }
    action def GenerateElectricity {
        in mechanical : MechanicalPower;
        out electrical : ElectricalPower;
        attribute ratedPower : PowerValue = 2.5 [MW];
        constraint { electrical.power <= ratedPower }
    }
    action def ConditionPower {
        in rawElectrical : ElectricalPower;
        out gridElectrical : ElectricalPower;
    }
    action def MonitorWind {
        in wind : WindCondition;
    }
    action def ControlYawAction {
        in windDirection : WindDirectionValue;
        out yawAngle : AngleValue;
    }
    action def ControlPitchAction {
        in windSpeed : WindSpeedValue;
        out pitchAngle : AngleValue;
    }
    action def EngageBrakeAction {
        in command : Boolean;
        out brakeEngaged : Boolean;
    }

    item def StartGenerating;
    item def ShutdownCommand;
    item def StartupComplete;
    item def ShutdownComplete;
    item def MaintenanceComplete;
    item def YawComplete;
    item def PitchComplete;
    item def BrakeComplete;
    item def FeatherComplete;

    part def Tower {
        attribute height : LengthValue = 85 [m];
        attribute material : String = "Steel";
    }

    part def Blade {
        attribute length : LengthValue = 45 [m];
        attribute pitchAngle : AngleValue;
    }

    part def Hub;

    part def Rotor {
        attribute diameter : LengthValue = 90 [m];
        part hub : Hub;
        part blade1 : Blade;
        part blade2 : Blade;
        part blade3 : Blade;
        port windPort : WindSensorPort;
        port mechOut : MechanicalPort;
        perform CaptureWindEnergy {
            in wind = windPort.wind;
            out mechanical = mechOut.mechanical;
        }
    }

    part def Gearbox {
        attribute ratio : GearRatioValue = 95;
        port mechIn : MechanicalPort;
        port mechOut : MechanicalPort;
        perform IncreaseRotationalSpeed {
            in lowSpeedMech = mechIn.mechanical;
            out highSpeedMech = mechOut.mechanical;
        }
    }

    part def Generator {
        attribute ratedPower : PowerValue = 2.5 [MW];
        port mechIn : MechanicalPort;
        port elecOut : ElectricalPort;
        perform GenerateElectricity {
            in mechanical = mechIn.mechanical;
            out electrical = elecOut.electrical;
        }
    }

    part def PowerConverter {
        port elecIn : ElectricalPort;
        port gridOut : ElectricalPort;
        perform ConditionPower {
            in rawElectrical = elecIn.electrical;
            out gridElectrical = gridOut.electrical;
        }
    }

    part def YawSystem {
        port controlIn : ControlCommandPort;
        attribute currentYawAngle : AngleValue;
    }

    part def PitchSystem {
        port controlIn : ControlCommandPort;
        part blade1 : Blade;
        part blade2 : Blade;
        part blade3 : Blade;
    }

    part def BrakeSystem {
        port controlIn : ControlCommandPort;
        attribute brakeEngaged : Boolean = false;
    }

    part def ControlSystem {
        attribute cutInSpeed : WindSpeedValue = 3.5 [m/s];
        attribute cutOutSpeed : WindSpeedValue = 25 [m/s];
        attribute startupComplete : Boolean = false;
        attribute shutdownComplete : Boolean = false;
        attribute brakeEngaged : Boolean = false;
        attribute bladesFeathered : Boolean = false;

        port windSensor : WindSensorPort;
        port yawCmd : ControlCommandPort;
        port pitchCmd : ControlCommandPort;
        port brakeCmd : ControlCommandPort;

        action monitorWind : MonitorWind {
            in wind = windSensor.wind;
        }
        action controlYawAction : ControlYawAction {
            in windDirection = windSensor.wind.direction;
            out yawAngle = yawCmd.command.yawAngle;
        }
        action controlPitchAction : ControlPitchAction {
            in windSpeed = windSensor.wind.speed;
            out pitchAngle = pitchCmd.command.pitchAngle;
        }
        action engageBrakeAction : EngageBrakeAction {
            in command = brakeCmd.command.brakeEngaged;
            out brakeEngaged = brakeCmd.command.brakeEngaged;
        }

        exhibit state 'Control States' {
            entry; then monitoring;

            state monitoring;
            accept StartGenerating
                then yawing;

            state yawing {
                entry controlYawAction;
            }
            accept YawComplete
                then pitching;

            state pitching {
                entry controlPitchAction;
            }
            accept PitchComplete
                then active;

            state active {
                do monitorWind;
                do controlYawAction;
                do controlPitchAction;
            }
            accept ShutdownCommand
                then braking;

            state braking {
                entry engageBrakeAction;
            }
            accept BrakeComplete
                then feathering;

            state feathering {
                entry controlPitchAction;
            }
            accept FeatherComplete
                then standby;

            state standby;
            accept MaintenanceComplete
                then monitoring;
        }
    }

    part def Nacelle {
        part gearbox : Gearbox;
        part generator : Generator;
        part powerConverter : PowerConverter;
        part yawSystem : YawSystem;
        part pitchSystem : PitchSystem;
        part brakeSystem : BrakeSystem;
        part controlSystem : ControlSystem;

        port mechInFromRotor : MechanicalPort;
        port windSensorExternal : WindSensorPort;
        port gridOutPort : ElectricalPort;

        connect mechInFromRotor to gearbox.mechIn;
        connect gearbox.mechOut to generator.mechIn;
        connect generator.elecOut to powerConverter.elecIn;
        connect powerConverter.gridOut to gridOutPort;
        connect windSensorExternal to controlSystem.windSensor;
        connect controlSystem.yawCmd to yawSystem.controlIn;
        connect controlSystem.pitchCmd to pitchSystem.controlIn;
        connect controlSystem.brakeCmd to brakeSystem.controlIn;
    }

    part def Grid {
        port gridPort : GridPort;
    }

    part def WindTurbine {
        attribute cutInSpeed : WindSpeedValue = 3.5 [m/s];
        attribute cutOutSpeed : WindSpeedValue = 25 [m/s];

        part tower : Tower;
        part nacelle : Nacelle;
        part rotor : Rotor;
        part grid : Grid;

        port windSensorPort : WindSensorPort;
        port gridConnection : ElectricalPort;

        action captureWindEnergy : CaptureWindEnergy;
        action increaseRotationalSpeed : IncreaseRotationalSpeed;
        action generateElectricity : GenerateElectricity;
        action conditionPower : ConditionPower;
        action monitorWind : MonitorWind;
        action controlYawAction : ControlYawAction;
        action controlPitchAction : ControlPitchAction;

        connect rotor.mechOut to nacelle.mechInFromRotor;
        connect windSensorPort to rotor.windPort;
        connect windSensorPort to nacelle.windSensorExternal;
        connect nacelle.gridOutPort to grid.gridPort;
        connect nacelle.gridOutPort to gridConnection;

        exhibit state 'Turbine Operation' {
            entry; then idle;

            state idle;
            accept when windSensorPort.wind.speed >= cutInSpeed
                do send new StartGenerating() to nacelle.controlSystem
                then starting;

            state starting;
            accept when nacelle.controlSystem.startupComplete
                then generating;

            state generating {
                do captureWindEnergy;
                do increaseRotationalSpeed;
                do generateElectricity;
                do conditionPower;
                do monitorWind;
                do controlYawAction;
                do controlPitchAction;
            }
            accept when windSensorPort.wind.speed >= cutOutSpeed
                do send new ShutdownCommand() to nacelle.controlSystem
                then shuttingDown;

            state shuttingDown;
            accept when nacelle.controlSystem.shutdownComplete
                then feathered;

            state feathered;
            accept MaintenanceComplete
                then idle;
        }
    }

    requirement def PowerGenerationRequirement {
        doc /* The wind turbine shall generate 2.5 MW of electrical power at rated conditions. */
        subject turbine : WindTurbine;
        attribute requiredPower : PowerValue = 2.5 [MW];
        require constraint { turbine.nacelle.generator.ratedPower >= requiredPower }
    }

    requirement def CutInSpeedRequirement {
        doc /* The turbine shall begin generating power at wind speeds of 3.5 m/s or greater. */
        subject turbine : WindTurbine;
        attribute cutInSpeedReqd : WindSpeedValue = 3.5 [m/s];
        require constraint { turbine.cutInSpeed == cutInSpeedReqd }
    }

    requirement def CutOutSpeedRequirement {
        doc /* The turbine shall shut down and engage safety systems if wind speeds exceed 25 m/s. */
        subject turbine : WindTurbine;
        attribute cutOutSpeedReqd : WindSpeedValue = 25 [m/s];
        require constraint { turbine.cutOutSpeed == cutOutSpeedReqd }
    }

    requirement def GearboxRatioRequirement {
        doc /* The gearbox shall increase rotational speed by a factor of 95. */
        subject gearbox : Gearbox;
        attribute requiredRatio : GearRatioValue = 95;
        require constraint { gearbox.ratio == requiredRatio }
    }

    requirement def RotorDiameterRequirement {
        doc /* The rotor diameter shall be 90 meters, composed of three 45-meter blades. */
        subject rotor : Rotor;
        attribute requiredDiameter : LengthValue = 90 [m];
        attribute bladeLength : LengthValue = 45 [m];
        require constraint { rotor.diameter == requiredDiameter }
        require constraint { rotor.blade1.length == bladeLength }
        require constraint { rotor.blade2.length == bladeLength }
        require constraint { rotor.blade3.length == bladeLength }
    }

    requirement def TowerHeightRequirement {
        doc /* The tower shall be 85 meters tall and constructed of steel. */
        subject tower : Tower;
        attribute requiredHeight : LengthValue = 85 [m];
        require constraint { tower.height == requiredHeight }
        require constraint { tower.material == "Steel" }
    }

    requirement def YawAlignmentRequirement {
        doc /* The yaw system shall align the rotor with the wind direction for optimal power capture. */
        subject yawSystem : YawSystem;
    }

    requirement def PitchControlRequirement {
        doc /* The pitch system shall adjust blade angles to control rotational speed and feather blades in high winds. */
        subject pitchSystem : PitchSystem;
    }

    requirement def GridConnectionRequirement {
        doc /* The power converter shall stabilize output power and step up voltage to match grid requirements. */
        subject powerConverter : PowerConverter;
    }

    package Usages {
        private import WindTurbineSystem::*;
        part windTurbine1 : WindTurbine;
    }
}
