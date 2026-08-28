package AutonomousEntertainmentRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Speed :> Real;
    attribute def SoundLevel :> Real;
    attribute def ChargeLevel :> Real;

    item def AudienceDetected;
    item def StartInteraction;
    item def StopInteraction;
    item def LowBatteryAlert;
    item def ErrorDetected;
    item def ChargeComplete;
    item def Reset;
    attribute def NavigationCommand;

    port def PowerPort {
        out attribute chargeLevel : ChargeLevel;
        in attribute powerSupply : Boolean;
    }

    port def SensorPort {
        out attribute audiencePresent : Boolean;
        out attribute engagementLevel : Real;
    }

    port def MotionPort {
        in attribute command : NavigationCommand;
        out attribute currentSpeed : Speed;
    }

    port def AudioPort {
        out attribute currentVolume : SoundLevel;
    }

    action def Move;
    action def Dance;
    action def PlayMusic;
    action def TellStory;
    action def ComedyRoutine;
    action def DetectAudience {
        out audiencePresent : Boolean;
        out engagementLevel : Real;
    }
    action def MonitorCharge {
        out charge : ChargeLevel;
    }
    action def StopActivity;
    action def LocateChargingStation;
    action def NavigateToStation;
    action def DockAndCharge;
    action def Diagnose;
    action def SupplyPower;

    action def ManageCharging {
        in charge : ChargeLevel;
        first start;
        then action stop : StopActivity;
        then action locate : LocateChargingStation;
        then action navigate : NavigateToStation;
        then action dock : DockAndCharge;
        then done;
    }

    part def ChargingStation {
        port powerPort : PowerPort;
        perform action supplyPower : SupplyPower;
    }

    part def MotionSystem {
        port motionPort : MotionPort;
        attribute maxSpeed : Speed;
        perform action move : Move;
        perform action dance : Dance;
        perform action stop : StopActivity;
    }

    part def AudioSystem {
        port audioPort : AudioPort;
        attribute maxVolume : SoundLevel;
        perform action playMusic : PlayMusic;
        perform action tellStory : TellStory;
        perform action comedyRoutine : ComedyRoutine;
        perform action stop : StopActivity;
    }

    part def SensorSystem {
        port sensorPort : SensorPort;
        perform action detectAudience : DetectAudience;
    }

    part def Battery {
        attribute chargeLevel : ChargeLevel;
        port powerPort : PowerPort;
    }

    part def PowerManagement {
        part battery : Battery;
        port powerPort : PowerPort;
        perform action monitorCharge : MonitorCharge;
        perform action manageCharging : ManageCharging;
    }

    part def NavigationSystem {
        perform action locateChargingStation : LocateChargingStation;
        perform action navigateToChargingStation : NavigateToStation;
    }

    part def Robot {
        attribute maxSpeed : Speed;
        attribute maxVolume : SoundLevel;

        part motionSystem : MotionSystem;
        part audioSystem : AudioSystem;
        part sensorSystem : SensorSystem;
        part powerSystem : PowerManagement;
        part navigationSystem : NavigationSystem;

        port powerPort : PowerPort;

        connect powerSystem.powerPort to powerPort;

        perform action diagnose : Diagnose;

        state RobotStates {
            entry; then idle;

            state idle;
            accept audienceDetected : AudienceDetected then performing;
            accept lowBattery : LowBatteryAlert then charging;
            accept error : ErrorDetected then error;

            state performing;
            accept startInteraction : StartInteraction then interacting;
            accept stopPerformance : StopInteraction then idle;
            accept lowBattery : LowBatteryAlert then charging;
            accept error : ErrorDetected then error;

            state interacting;
            accept stopInteraction : StopInteraction then idle;
            accept lowBattery : LowBatteryAlert then charging;
            accept error : ErrorDetected then error;

            state charging;
            accept chargeComplete : ChargeComplete then idle;
            accept error : ErrorDetected then error;

            state error;
            accept reset : Reset then idle;
        }

        action def ManagePower {
            loop action monitoring {
                action checkCharge : MonitorCharge {
                    out charge;
                }
                then if monitoring.checkCharge.charge < 20 {
                    action stopActivity : StopActivity;
                    then action locate : LocateChargingStation;
                    then action navigate : NavigateToStation;
                    then action dock : DockAndCharge;
                }
            } until monitoring.checkCharge.charge >= 95;
        }

        perform action managePower : ManagePower;
    }

    requirement def MaxSpeedLimit {
        doc /* Maximum movement speed shall not exceed 2.0 m/s */
        subject speed : Speed;
        constraint { speed <= 2.0 }
    }

    requirement def MaxVolumeLimit {
        doc /* Maximum sound volume shall not exceed 85 dB */
        subject volume : SoundLevel;
        constraint { volume <= 85 }
    }

    requirement def AutonomousChargingRequirement {
        doc /* Robot shall autonomously navigate to charging station when battery is low */
        subject robot : Robot;
    }

    part entertainmentSystem {
        part robot : Robot {
            :>> maxSpeed = 2.0;
            :>> maxVolume = 85;
        }
        part chargingStation : ChargingStation;

        requirement safetyConstraints {
            doc /* Safety constraints for autonomous robot operation */
            subject robot : Robot;
            requirement maxSpeed : MaxSpeedLimit {
                subject = robot.motionSystem.maxSpeed;
            }
            requirement maxVolume : MaxVolumeLimit {
                subject = robot.audioSystem.maxVolume;
            }
            requirement autonomousCharging : AutonomousChargingRequirement {
                subject = robot;
            }
        }

        connection powerConnection connect robot.powerPort to chargingStation.powerPort;
    }
}
