package 'Autonomous Domestic Robotic Cleaning System' {
    private import ScalarValues::*;
    private import ISQ::*;

    enum def FloorSurface {
        enum hardwood;
        enum tile;
        enum carpet;
    }

    enum def CleaningTask {
        enum vacuuming;
        enum mopping;
        enum dusting;
    }

    item def TaskCommand {
        task : CleaningTask;
        surface : FloorSurface;
    }
    item def StatusUpdate;
    item def PathPlan;
    item def ObstacleData;
    item def PositionData;
    item def PowerStatus {
        chargeLevel : Real;
    }

    attribute def 'Task Command';
    attribute def 'Task Complete';
    attribute def 'Arrived At Target';
    attribute def 'Docked';

    action def 'Navigate to Target';
    action def 'Perform Cleaning';
    action def 'Return to Base';
    action def 'Charge Battery';

    part def ChargingStation {
        port dockPort {
            in powerStatus : PowerStatus;
            out powerSupply : Real;
        }
    }

    part def ControlModule {
        port commandPort { in taskCommand : TaskCommand; }
        port statusPort { out statusUpdate : StatusUpdate; }
        port navCommandPort { out navCommand : TaskCommand; }
        port cleanCommandPort { out cleanCommand : TaskCommand; }
        port powerStatusPort { in powerStatus : PowerStatus; }
    }

    part def NavigationModule {
        port navCommandPort { in navCommand : TaskCommand; }
        port pathPort { out pathPlan : PathPlan; }
        port obstaclePort { out obstacleData : ObstacleData; }
        port positionPort { out positionData : PositionData; }
    }

    part def CleaningModule {
        port cleanCommandPort { in cleanCommand : TaskCommand; }
    }

    part def PowerModule {
        port powerStatusPort { out powerStatus : PowerStatus; }
        port dockPort {
            out powerStatus : PowerStatus;
            in powerSupply : Real;
        }
        attribute chargeLevel : Real;
    }

    part def CleaningRobot {
        port commandPort { in taskCommand : TaskCommand; }
        port dockPort {
            out powerStatus : PowerStatus;
            in powerSupply : Real;
        }

        part controlModule : ControlModule;
        part navigationModule : NavigationModule;
        part cleaningModule : CleaningModule;
        part powerModule : PowerModule;

        bind commandPort = controlModule.commandPort;
        bind controlModule.navCommandPort = navigationModule.navCommandPort;
        bind controlModule.cleanCommandPort = cleaningModule.cleanCommandPort;
        bind controlModule.powerStatusPort = powerModule.powerStatusPort;
        bind dockPort = powerModule.dockPort;

        perform action 'navigate to target' : 'Navigate to Target';
        perform action 'perform cleaning' : 'Perform Cleaning';
        perform action 'return to base' : 'Return to Base';
        perform action 'charge battery' : 'Charge Battery';

        exhibit state 'robot states' {
            entry; then standby;
            state standby;
            accept 'Task Command'
                then navigating;
            state navigating {
                do 'navigate to target';
            }
            accept 'Arrived At Target'
                then performing;
            state performing {
                do 'perform cleaning';
            }
            accept 'Task Complete'
                then returning;
            accept when powerModule.chargeLevel < 20
                then returning;
            state returning {
                do 'return to base';
            }
            accept 'Docked'
                then charging;
            state charging {
                do 'charge battery';
            }
            accept when powerModule.chargeLevel >= 100
                then standby;
        }
    }

    part robot : CleaningRobot;
    part station : ChargingStation;

    interface dockInterface connect robot.dockPort to station.dockPort {
        flow powerStatusFlow of PowerStatus
            from robot.dockPort.powerStatus to station.dockPort.powerStatus;
        flow powerSupplyFlow of Real
            from station.dockPort.powerSupply to robot.dockPort.powerSupply;
    }

    requirement def 'Autonomous Cleaning Requirement' {
        text = "The system shall autonomously perform cleaning tasks on various surfaces and return to charge when low.";
    }

    requirement 'autonomous cleaning req' : 'Autonomous Cleaning Requirement' {
        subject = robot;
    }
}
