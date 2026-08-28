package ModularRobotSystem {
    attribute def Command;
    attribute def SensorData;
    attribute def Task;
    attribute def ConfigurationPlan {
        attribute requiresReconfiguration : ScalarValues::Boolean;
    }

    port def DockingPort {
        in attribute command : Command;
        out attribute data : SensorData;
        in attribute power : ISQ::PowerValue;
        attribute isLocked : ScalarValues::Boolean;
    }

    abstract part def Module {
        attribute batteryLevel : ISQ::EnergyValue;
        port dockingPort[4] : DockingPort;
    }

    part def LocomotionModule :> Module {
        attribute maxSpeed : ISQ::LinearVelocityValue;
    }

    part def ManipulationModule :> Module {
        attribute armJoints : ScalarValues::Integer;
    }

    part def SensingModule :> Module {
        attribute environmentData : SensorData;
    }

    part def ComputationModule :> Module {
        attribute processingLoad : ScalarValues::Real;
    }

    part def PowerModule :> Module {
        attribute capacity : ISQ::EnergyValue;
    }

    part def CentralController :> ComputationModule {
        attribute task : Task;
        attribute plan : ConfigurationPlan;
        port controlPort : DockingPort;
    }

    action def SensePlanAct {
        first start;
        then action sense;
        then action plan;
        then action act;
        then done;
    }

    action def ReconfigureSteps {
        first start;
        then action disconnect;
        then action move;
        then action align;
        then action lock;
        then done;
    }

    action def Evaluate;

    part def ModularRobot {
        attribute currentTask : Task;
        attribute currentPlan : ConfigurationPlan;

        part controller : CentralController;
        part locomotion[2] : LocomotionModule;
        part manipulation[1] : ManipulationModule;
        part sensing[2] : SensingModule;
        part computation[1] : ComputationModule;
        part power[1] : PowerModule;

        connection ctrlConn connect controller.controlPort to locomotion[1].dockingPort[1];
        connection powerConn connect power[1].dockingPort[1] to controller.controlPort;

        state RobotStates {
            entry; then Idle;
            state Idle;
            accept t : Task then Planning;

            state Planning {
                do action Evaluate;
            }
            transition first Planning if currentPlan.requiresReconfiguration then Reconfiguring;
            transition first Planning then ExecutingTask;

            state ExecutingTask {
                do action SensePlanAct;
            }
            transition first ExecutingTask accept t : Task then Planning;

            state Reconfiguring {
                do action ReconfigureSteps;
            }
            transition first Reconfiguring then ExecutingTask;
        }
    }

    requirement def ReconfigurationCapability {
        subject robot : ModularRobot;
        doc /*
        * The robot shall autonomously reconfigure its physical structure
        * to adapt to new tasks and environments.
        */
    }

    requirement def PowerSharing {
        subject module : Module;
        doc /*
        * Modules shall share power through their docking ports.
        */
    }

    requirement def AutonomousOperation {
        subject robot : ModularRobot;
        doc /*
        * The robot shall operate autonomously through a continuous cycle
        * of sensing, planning, and acting.
        */
    }
}
