package IndoorAutonomousRobotSystem {
    item def Position3D {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
    }

    item def Path {
        attribute waypoints : Position3D[1..*];
    }

    attribute def TaskAssignment {
        attribute id : ScalarValues::String;
        attribute taskType : ScalarValues::String;
        attribute destination : Position3D;
    }

    attribute def TaskReport {
        attribute taskId : ScalarValues::String;
        attribute status : ScalarValues::String;
        attribute completionTime : ISQ::DurationValue;
    }

    attribute def BatteryStatus {
        attribute chargePercent : ScalarValues::Real;
        attribute level : ScalarValues::String;
    }

    attribute def SensorData {
        attribute obstacleDistances : ISQ::LengthValue[6];
        attribute objectCount : ScalarValues::Integer;
    }

    attribute def NavigationCommand {
        attribute target : Position3D;
    }

    attribute def MovementCommand {
        attribute path : Path;
    }

    attribute def NavigationResult {
        attribute success : ScalarValues::Boolean;
    }

    attribute def SigTaskAssigned;
    attribute def SigTaskComplete;
    attribute def SigLowBattery;
    attribute def SigBatteryFull;
    attribute def SigFaultDetected;
    attribute def SigFaultRecovered;
    attribute def SigEmergencyStop;
    attribute def SigPlanComplete;
    attribute def SigNavComplete;
    attribute def SigExecComplete;
    attribute def SigReportComplete;

    port def DispatcherPort {
        out attribute task : TaskAssignment;
        in attribute report : TaskReport;
    }

    port def RobotTaskPort {
        in attribute task : TaskAssignment;
        out attribute report : TaskReport;
    }

    port def SensorDataOutPort {
        out attribute data : SensorData;
    }

    port def SensorDataInPort {
        in attribute data : SensorData;
    }

    port def NavCommandOutPort {
        out attribute navCommand : NavigationCommand;
        out attribute moveCommand : MovementCommand;
    }

    port def NavCommandInPort {
        in attribute navCommand : NavigationCommand;
        in attribute moveCommand : MovementCommand;
    }

    port def NavResultOutPort {
        out attribute path : Path;
        out attribute navResult : NavigationResult;
    }

    port def NavResultInPort {
        in attribute path : Path;
        in attribute navResult : NavigationResult;
    }

    port def TaskCommandOutPort {
        out attribute task : TaskAssignment;
    }

    port def TaskCommandInPort {
        in attribute task : TaskAssignment;
    }

    port def TaskResultOutPort {
        out attribute report : TaskReport;
    }

    port def TaskResultInPort {
        in attribute report : TaskReport;
    }

    port def PowerStatusOutPort {
        out attribute batteryStatus : BatteryStatus;
        out attribute lowBattery : SigLowBattery;
        out attribute batteryFull : SigBatteryFull;
        out attribute fault : SigFaultDetected;
    }

    port def PowerStatusInPort {
        in attribute batteryStatus : BatteryStatus;
        in attribute lowBattery : SigLowBattery;
        in attribute batteryFull : SigBatteryFull;
        in attribute fault : SigFaultDetected;
    }

    port def StationPowerPort {
        out attribute powerAvailable : ScalarValues::Boolean;
    }

    port def RobotDockingPort {
        in attribute externalPower : ScalarValues::Boolean;
    }

    requirement def CollisionAvoidanceReq {
        attribute minDistance : ISQ::LengthValue = 10 [SI::m];
        doc /* The robot shall avoid collisions in human-occupied spaces. */;
    }

    requirement def OperationalEnduranceReq {
        attribute minDuration : ISQ::DurationValue = 6 [SI::h];
        doc /* The robot shall operate for at least six hours on a single charge. */;
    }

    requirement def TaskReliabilityReq {
        attribute minSuccessRate : ScalarValues::Real = 0.99;
        doc /* The robot shall successfully complete assigned tasks with high reliability and accuracy. */;
    }

    requirement roboticSystemRequirements {
        requirement collisionAvoidance : CollisionAvoidanceReq;
        requirement endurance : OperationalEnduranceReq;
        requirement reliability : TaskReliabilityReq;
    }

    part def Sensor {
        attribute maxRange : ISQ::LengthValue = 10 [SI::m];
        port dataOut : SensorDataOutPort;
        perform action sense {
            out attribute data : SensorData;
            first start;
            then done;
        }
    }

    part def PerceptionSystem {
        part sensors[6] : Sensor;
        port dataOut : SensorDataOutPort;
        perform action perceiveEnvironment {
            out attribute data : SensorData;
            first start;
            then done;
        }
    }

    part def NavigationSystem {
        port navCommandIn : NavCommandInPort;
        port navResultOut : NavResultOutPort;
        port sensorDataIn : SensorDataInPort;
        perform action calculatePath {
            in attribute target : Position3D;
            in attribute sensorData : SensorData;
            out attribute path : Path;
            first start;
            then done;
        }
        perform action moveAlongPath {
            in attribute path : Path;
            out attribute result : NavigationResult;
            first start;
            then done;
        }
    }

    part def TaskExecutionSystem {
        port taskIn : TaskCommandInPort;
        port taskOut : TaskResultOutPort;
        perform action executeTask {
            in attribute task : TaskAssignment;
            out attribute report : TaskReport;
            first start;
            then done;
        }
    }

    part def Battery {
        attribute capacity : ISQ::EnergyValue = 21600000 [SI::J];
        attribute currentCharge : ISQ::EnergyValue = 21600000 [SI::J];
        port powerOut : PowerStatusOutPort;
        perform action discharge {
            first start;
            then done;
        }
    }

    part def PowerManagementSystem {
        port batteryIn : PowerStatusInPort;
        port externalPowerIn : RobotDockingPort;
        port statusOut : PowerStatusOutPort;
        perform action monitorBattery {
            out attribute status : BatteryStatus;
            first start;
            then done;
        }
        perform action manageCharging {
            first start;
            then done;
        }
    }

    part def CentralControlSystem {
        port taskIn : RobotTaskPort;
        port perceptionIn : SensorDataInPort;
        port navCommandOut : NavCommandOutPort;
        port navResultIn : NavResultInPort;
        port taskCommandOut : TaskCommandOutPort;
        port taskResultIn : TaskResultInPort;
        port powerStatusIn : PowerStatusInPort;
        port chargingCmdOut {
            out attribute requestCharging : ScalarValues::Boolean;
        }

        perform action planRoute {
            in attribute task : TaskAssignment;
            out attribute navCommand : NavigationCommand;
            first start;
            then done;
        }

        perform action navigateToTarget {
            first start;
            then done;
        }

        perform action executeAssignedTask {
            first start;
            then done;
        }

        perform action reportResult {
            first start;
            then done;
        }

        perform action diagnoseFault {
            first start;
            then done;
        }

        perform action returnToCharger {
            first start;
            then done;
        }

        perform action idle {
            first start;
            then done;
        }

        state controlStates {
            entry; then standby;

            state standby {
                do action idle;
            }
            accept SigTaskAssigned then active;
            accept SigLowBattery then charging;
            accept SigFaultDetected then fault;

            state active {
                entry; then planning;
                state planning {
                    do action planRoute;
                }
                accept SigPlanComplete then navigating;
                state navigating {
                    do action navigateToTarget;
                }
                accept SigNavComplete then executing;
                state executing {
                    do action executeAssignedTask;
                }
                accept SigExecComplete then reporting;
                state reporting {
                    do action reportResult;
                }
                accept SigReportComplete then standby;
            }
            accept SigLowBattery then charging;
            accept SigFaultDetected then fault;

            state charging {
                do action returnToCharger;
            }
            accept SigBatteryFull then standby;
            accept SigFaultDetected then fault;

            state fault {
                do action diagnoseFault;
            }
            accept SigFaultRecovered then standby;
            accept SigEmergencyStop then done;
        }
    }

    part def PersonalRobot {
        part centralControl : CentralControlSystem;
        part perception : PerceptionSystem;
        part navigation : NavigationSystem;
        part taskExecution : TaskExecutionSystem;
        part powerManagement : PowerManagementSystem;
        part battery : Battery;

        port dispatcherPort : RobotTaskPort;
        port dockingPort : RobotDockingPort;

        connect dispatcherPort.task to centralControl.taskIn.task;
        connect centralControl.taskIn.report to dispatcherPort.report;
        connect perception.dataOut to centralControl.perceptionIn;
        connect perception.dataOut to navigation.sensorDataIn;
        connect centralControl.navCommandOut to navigation.navCommandIn;
        connect navigation.navResultOut to centralControl.navResultIn;
        connect centralControl.taskCommandOut to taskExecution.taskIn;
        connect taskExecution.taskOut to centralControl.taskResultIn;
        connect battery.powerOut to powerManagement.batteryIn;
        connect powerManagement.statusOut to centralControl.powerStatusIn;
        connect dockingPort to powerManagement.externalPowerIn;
    }

    part def ChargingStation {
        port stationPort : StationPowerPort;
        attribute isOccupied : ScalarValues::Boolean = false;
        perform action supplyPower {
            first start;
            then done;
        }
    }

    part def TaskDispatcher {
        port dispatchPort : DispatcherPort;
        perform action assignTask {
            out attribute task : TaskAssignment;
            first start;
            then done;
        }
        perform action receiveReport {
            in attribute report : TaskReport;
            first start;
            then done;
        }
    }

    part def RoboticSystem {
        part robot : PersonalRobot;
        part chargingStation : ChargingStation;
        part dispatcher : TaskDispatcher;

        connect dispatcher.dispatchPort to robot.dispatcherPort;
        connect robot.dockingPort to chargingStation.stationPort;
    }

    part roboticSystemInstance : RoboticSystem;

    satisfy CollisionAvoidanceReq by roboticSystemInstance.robot.perception;
    satisfy CollisionAvoidanceReq by roboticSystemInstance.robot.navigation;
    satisfy OperationalEnduranceReq by roboticSystemInstance.robot.battery;
    satisfy OperationalEnduranceReq by roboticSystemInstance.robot.powerManagement;
    satisfy TaskReliabilityReq by roboticSystemInstance.robot.centralControl;
    satisfy TaskReliabilityReq by roboticSystemInstance.robot.taskExecution;
}
