package 'GreyWalterTortoiseSystem' {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def IlluminanceValue :> Real { unit 'lux'; }
    attribute def MassValue :> Real { unit 'kg'; }
    attribute def SpeedValue :> Real { unit 'm/s'; }
    attribute def BatteryCapacityValue :> Real { unit 'Wh'; }
    attribute def ChargeLevelValue :> Real { unit '%'; }
    attribute def AngleValue :> Real { unit 'deg'; }
    attribute def PowerValue :> Real { unit 'W'; }

    item def LightSignal {
        attribute illuminance : IlluminanceValue;
    }

    attribute def MotorCommand {
        attribute speed : SpeedValue;
        attribute angle : AngleValue;
    }
    attribute def NavigationPath;
    attribute def StatusReport;
    attribute def Docked;
    attribute def Undocked;
    attribute def SigPowerOn;
    attribute def SigPowerOff;

    action def SenseLight {
        in light : LightSignal;
        out illuminance : IlluminanceValue;
    }
    action def MoveTowardLight {
        in light : LightSignal;
        out command : MotorCommand;
    }
    action def SwitchOnHeadlamp {
        out headlampOn : Boolean;
    }
    action def SwitchOffHeadlamp {
        out headlampOff : Boolean;
    }
    action def MonitorBattery {
        in currentCharge : ChargeLevelValue;
        out status : StatusReport;
    }
    action def NavigateToStation {
        in beacon : LightSignal;
        out path : NavigationPath;
    }
    action def DockAndRecharge {
        in charge : ChargeLevelValue;
        out newCharge : ChargeLevelValue;
    }
    action def Undock {
        out status : StatusReport;
    }

    part def PhotocellSensor {
        attribute sensitivity : Real;
        port sensorIn {
            in light : LightSignal;
        }
        port sensorOut {
            out illuminance : IlluminanceValue;
        }
        perform action sense : SenseLight;
    }

    part def DriveMotor {
        attribute maxPower : PowerValue;
        port motorInput {
            in command : MotorCommand;
        }
        port motorOutput {
            out actualSpeed : SpeedValue;
        }
    }

    part def SteeringMechanism {
        attribute maxAngle : AngleValue;
        port steerInput {
            in command : MotorCommand;
        }
        port steerOutput {
            out actualAngle : AngleValue;
        }
    }

    part def Headlamp {
        attribute maxIntensity : IlluminanceValue;
        port lampInput {
            in on : Boolean;
        }
        port lampOutput {
            out emittedLight : LightSignal;
        }
    }

    part def RechargeableBattery {
        attribute capacity : BatteryCapacityValue;
        attribute currentCharge : ChargeLevelValue;
        port powerIn {
            in chargePower : PowerValue;
        }
        port powerOut {
            out supplyPower : PowerValue;
        }
        port statusOut {
            out chargeLevel : ChargeLevelValue;
        }
        perform action monitor : MonitorBattery;
        perform action recharge : DockAndRecharge;
    }

    part def TortoiseRobot {
        attribute massActual : MassValue;
        attribute maxSpeed : SpeedValue;
        attribute batteryCapacity : BatteryCapacityValue;
        attribute dimLightThreshold : IlluminanceValue = 10.0;
        attribute brightLightThreshold : IlluminanceValue = 50.0;
        attribute lowBatteryThreshold : ChargeLevelValue = 20.0;
        attribute fullBatteryThreshold : ChargeLevelValue = 95.0;

        port lightInPort {
            in light : LightSignal;
        }
        port lightOutPort {
            out light : LightSignal;
        }
        port powerPort {
            in charge : ChargeLevelValue;
        }

        part photocellSensor : PhotocellSensor;
        part driveMotor : DriveMotor;
        part steeringMechanism : SteeringMechanism;
        part headlamp : Headlamp;
        part battery : RechargeableBattery {
            bind capacity = batteryCapacity;
        }

        connect lightInPort.light to photocellSensor.sensorIn.light;
        connect headlamp.lampOutput.emittedLight to lightOutPort.light;
        connect battery.statusOut.chargeLevel to powerPort.charge;

        exhibit state robotStates {
            entry; then off;
            state off;
            transition off_exploring
                first off
                accept SigPowerOn
                then exploring;
            state exploring {
                entry action senseAmbient : SenseLight;
                do action monitorBattery : MonitorBattery;
            }
            transition exploring_dimLight
                first exploring
                if photocellSensor.sensorOut.illuminance < dimLightThreshold
                do action switchOnHeadlamp : SwitchOnHeadlamp
                then exploring;
            transition exploring_strongLight
                first exploring
                if photocellSensor.sensorOut.illuminance > brightLightThreshold
                then seekingLight;
            transition exploring_batteryLow
                first exploring
                if battery.currentCharge < lowBatteryThreshold
                then lowBattery;
            transition exploring_off
                first exploring
                accept SigPowerOff
                then off;
            state seekingLight {
                entry action moveTowardLight : MoveTowardLight;
                do action monitorBatterySeeking : MonitorBattery;
            }
            transition seekingLight_batteryLow
                first seekingLight
                if battery.currentCharge < lowBatteryThreshold
                then lowBattery;
            transition seekingLight_off
                first seekingLight
                accept SigPowerOff
                then off;
            state lowBattery {
                entry action navigateToStation : NavigateToStation;
                do action switchOffHeadlamp : SwitchOffHeadlamp;
            }
            transition lowBattery_docked
                first lowBattery
                accept Docked
                then charging;
            state charging {
                do action recharge : DockAndRecharge;
            }
            transition charging_batteryFull
                first charging
                if battery.currentCharge >= fullBatteryThreshold
                then undocking;
            state undocking {
                entry action undock : Undock;
            }
            transition undocking_exploring
                first undocking
                accept Undocked
                then exploring;
        }
    }

    part def ChargingStation {
        part beacon {
            attribute beaconIntensity : IlluminanceValue = 500.0;
            port beaconEmitter {
                out light : LightSignal;
            }
        }
        part dock1 {
            port powerOutput {
                out chargePower : PowerValue;
            }
            port dockingSensor {
                in attribute isDocked : Boolean;
            }
        }
        part dock2 {
            port powerOutput {
                out chargePower : PowerValue;
            }
            port dockingSensor {
                in attribute isDocked : Boolean;
            }
        }
        port beaconPort {
            out light : LightSignal;
        }
        port dockPort1 {
            out chargePower : PowerValue;
        }
        port dockPort2 {
            out chargePower : PowerValue;
        }
        connect beacon.beaconEmitter.light to beaconPort.light;
        connect dock1.powerOutput.chargePower to dockPort1.chargePower;
        connect dock2.powerOutput.chargePower to dockPort2.chargePower;
    }

    part def Environment {
        attribute ambientIlluminance : IlluminanceValue;
        port ambientLightPort {
            out ambientLight : LightSignal;
        }
    }

    part elmer : TortoiseRobot {
        attribute massActual = 1.2;
        attribute maxSpeed = 0.1;
        attribute batteryCapacity = 10.0;
    }

    part elsie : TortoiseRobot {
        attribute massActual = 1.5;
        attribute maxSpeed = 0.08;
        attribute batteryCapacity = 12.0;
    }

    part station : ChargingStation;
    part environment : Environment;

    connect environment.ambientLightPort.ambientLight to elmer.lightInPort.light;
    connect environment.ambientLightPort.ambientLight to elsie.lightInPort.light;
    connect elmer.lightOutPort.light to elsie.lightInPort.light;
    connect elsie.lightOutPort.light to elmer.lightInPort.light;
    connect station.beaconPort.light to elmer.lightInPort.light;
    connect station.beaconPort.light to elsie.lightInPort.light;
    connect station.dockPort1.chargePower to elmer.battery.powerIn.chargePower;
    connect station.dockPort2.chargePower to elsie.battery.powerIn.chargePower;

    requirement def LightSeekingRequirement {
        doc /* Each robot shall continuously sense ambient light and move toward sources exceeding the bright light threshold. */
        subject robot : TortoiseRobot;
        attribute threshold : IlluminanceValue = 50.0;
    }

    requirement def HeadlampActivationRequirement {
        doc /* Each robot shall automatically switch on its headlamp when ambient light falls below the dim light threshold. */
        subject robot : TortoiseRobot;
        attribute threshold : IlluminanceValue = 10.0;
    }

    requirement def BatteryManagementRequirement {
        doc /* Each robot shall navigate to the charging station and dock when battery charge falls below the low threshold, and undock when charge exceeds the full threshold. */
        subject robot : TortoiseRobot;
        attribute lowThreshold : ChargeLevelValue = 20.0;
        attribute highThreshold : ChargeLevelValue = 95.0;
    }

    requirement def EmergentBehaviorRequirement {
        doc /* Two robots shall exhibit emergent mutual attraction and circling behavior through their light-seeking and headlamp emission interactions. */
        subject robot1 : TortoiseRobot;
        subject robot2 : TortoiseRobot;
    }

    requirement elmerLightSeeking : LightSeekingRequirement {
        subject robot = elmer;
    }
    requirement elmerHeadlamp : HeadlampActivationRequirement {
        subject robot = elmer;
    }
    requirement elmerBattery : BatteryManagementRequirement {
        subject robot = elmer;
    }
    requirement elsieLightSeeking : LightSeekingRequirement {
        subject robot = elsie;
    }
    requirement elsieHeadlamp : HeadlampActivationRequirement {
        subject robot = elsie;
    }
    requirement elsieBattery : BatteryManagementRequirement {
        subject robot = elsie;
    }
    requirement emergentDance : EmergentBehaviorRequirement {
        subject robot1 = elmer;
        subject robot2 = elsie;
    }
}
