package 'Watermill Model' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def Water;
        item def Grain;
        item def Flour;

        alias Torque for ISQ::TorqueValue;
        alias SpeedValue for ISQ::AngularVelocity;
        alias FlowRateValue for ISQ::VolumeFlowRate;
        alias MassFlowRateValue for ISQ::MassFlowRate;

        part def WaterChannel {
            in waterIn : Water;
            out waterOut : Water;
            attribute flowRate : FlowRateValue;
        }

        part def WaterWheel {
            in waterIn : Water;
            out torqueOut : Torque;
            out speedOut : SpeedValue;
            attribute speed : SpeedValue;
        }

        part def DriveShaft {
            in torqueIn : Torque;
            in speedIn : SpeedValue;
            out torqueOut : Torque;
            out speedOut : SpeedValue;
        }

        part def UpperMillstone {
            in torqueIn : Torque;
            in speedIn : SpeedValue;
            in grainIn : Grain;
            out flourOut : Flour;
            attribute speed : SpeedValue;
        }

        part def LowerMillstone {
            attribute isStationary : Boolean = true;
        }

        part def GrainHopper {
            out grainOut : Grain;
            attribute feedRate : MassFlowRateValue;
        }

        part def FlourCollector {
            in flourIn : Flour;
        }

        part def Watermill {
            part channel : WaterChannel;
            part wheel : WaterWheel;
            part shaft : DriveShaft;
            part upperStone : UpperMillstone;
            part lowerStone : LowerMillstone;
            part hopper : GrainHopper;
            part collector : FlourCollector;

            in waterSupply : Water;

            connect waterSupply to channel.waterIn;
            connect channel.waterOut to wheel.waterIn;
            connect wheel.torqueOut to shaft.torqueIn;
            connect wheel.speedOut to shaft.speedIn;
            connect shaft.torqueOut to upperStone.torqueIn;
            connect shaft.speedOut to upperStone.speedIn;
            connect hopper.grainOut to upperStone.grainIn;
            connect upperStone.flourOut to collector.flourIn;
        }

        action def DirectWater { out water : Water; }
        action def TurnWheel { in water : Water; out torque : Torque; out speed : SpeedValue; }
        action def TransferPower { in torque : Torque; in speed : SpeedValue; out shaftTorque : Torque; out shaftSpeed : SpeedValue; }
        action def GrindGrain { in torque : Torque; in speed : SpeedValue; in grain : Grain; out flour : Flour; }
        action def CollectFlour { in flour : Flour; }
        action def DecelerateMill { in speed : SpeedValue; }

        action def OperateMill {
            in grain : Grain;
            out flour : Flour;

            action directWater : DirectWater { out water : Water; }
            flow directWater.water to turnWheel.water;
            action turnWheel : TurnWheel { in water : Water; out torque : Torque; out speed : SpeedValue; }
            flow turnWheel.torque to transferPower.torque;
            flow turnWheel.speed to transferPower.speed;
            action transferPower : TransferPower { in torque : Torque; in speed : SpeedValue; out shaftTorque : Torque; out shaftSpeed : SpeedValue; }
            flow transferPower.shaftTorque to grindGrain.torque;
            flow transferPower.shaftSpeed to grindGrain.speed;
            action grindGrain : GrindGrain { in torque : Torque; in speed : SpeedValue; in grain = OperateMill::grain; out flour = OperateMill::flour; }
            flow grindGrain.flour to collectFlour.flour;
            action collectFlour : CollectFlour { in flour : Flour; }
        }

        attribute def WaterFlowOn;
        attribute def WaterFlowOff;
        attribute def OperationalSpeedReached;
        attribute def MillStopped;

        state def WatermillStates {
            in wheelSpeed : SpeedValue;
            in flowRate : FlowRateValue;
            entry; then idle;

            state idle;
            transition idle_to_starting
                first idle
                accept WaterFlowOn
                if flowRate > 0
                then starting;

            state starting {
                do action accelerate : TurnWheel;
            }
            transition starting_to_operating
                first starting
                accept OperationalSpeedReached
                if wheelSpeed >= 10
                then operating;
            transition starting_to_shuttingdown
                first starting
                accept WaterFlowOff
                then shuttingDown;

            state operating {
                do action operate : OperateMill;
                exit action decelerate : DecelerateMill { in speed = wheelSpeed; }
            }
            transition operating_to_shuttingdown
                first operating
                accept WaterFlowOff
                then shuttingDown;

            state shuttingDown {
                do action decelerate : DecelerateMill { in speed = wheelSpeed; }
            }
            transition shuttingdown_to_idle
                first shuttingDown
                accept MillStopped
                then idle;
        }

        requirement def OperationalRequirement {
            doc /* The mill shall reach minimum operational speed before grinding begins. */
            subject mill : Watermill;
        }
        requirement def SafetyRequirement {
            doc /* The mill shall automatically shut down and decelerate when water flow stops to prevent millstone damage. */
            subject mill : Watermill;
        }
    }

    package Usages {
        private import Definitions::*;

        part watermillSystem : Watermill {
            attribute wheelSpeed : SpeedValue;
            attribute flowRate : FlowRateValue;

            state millStates : WatermillStates {
                in wheelSpeed = watermillSystem.wheelSpeed;
                in flowRate = watermillSystem.flowRate;
            }
        }
    }
}
