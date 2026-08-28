package 'Szczecin Water Pump Station' {
    attribute def Length :> ScalarValues::Real;
    attribute def Pressure :> ScalarValues::Real;
    attribute def VolumeFlowRate :> ScalarValues::Real;
    attribute def RotationalSpeed :> ScalarValues::Real;
    
    item def Water;
    item def Torque;
    
    item def LevelData {
        attribute level : Length;
    }
    item def PressureData {
        attribute pressure : Pressure;
    }
    item def FlowData {
        attribute flowRate : VolumeFlowRate;
    }
    item def MotorCommand {
        attribute targetSpeed : RotationalSpeed;
    }
    
    part def IntakeReservoir {
        attribute currentLevel : Length;
        port waterOut {
            out water : Water;
        }
    }
    
    part def CentrifugalPump {
        port waterIn {
            in water : Water;
        }
        port waterOut {
            out water : Water;
        }
        port driveIn {
            in torque : Torque;
        }
    }
    
    part def ElectricMotor {
        attribute currentSpeed : RotationalSpeed;
        port driveOut {
            out torque : Torque;
        }
        port commandIn {
            in command : MotorCommand;
        }
        action motorBehavior {
            action receiveCommand accept command : MotorCommand via commandIn;
            then action setSpeed {
                currentSpeed := receiveCommand.command.targetSpeed;
            }
        }
    }
    
    part def LevelSensor {
        port dataOut {
            out data : LevelData;
        }
    }
    
    part def PressureSensor {
        port dataOut {
            out data : PressureData;
        }
    }
    
    part def FlowMeter {
        port dataOut {
            out data : FlowData;
        }
    }
    
    part def DistributionNetwork {
        port waterIn {
            in water : Water;
        }
    }
    
    part def PumpController {
        port levelIn {
            in levelData : LevelData;
        }
        port pressureIn {
            in pressureData : PressureData;
        }
        port flowIn {
            in flowData : FlowData;
        }
        port commandOut {
            out command : MotorCommand;
        }
        
        attribute targetPressure : Pressure = 500000;
        attribute targetFlow : VolumeFlowRate = 0.1;
        
        action controlLoop {
            action acceptLevel accept levelData : LevelData via levelIn;
            then action acceptPressure accept pressureData : PressureData via pressureIn;
            then action acceptFlow accept flowData : FlowData via flowIn;
            then action computeSpeed {
                in level = acceptLevel.levelData.level;
                in pressure = acceptPressure.pressureData.pressure;
                in flow = acceptFlow.flowData.flowRate;
                out speed : RotationalSpeed;
            }
            then send new MotorCommand() via commandOut;
        }
    }
    
    part def WaterPumpStation {
        part intakeReservoir : IntakeReservoir;
        part pump : CentrifugalPump;
        part motor : ElectricMotor;
        part levelSensor : LevelSensor;
        part pressureSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part distributionNetwork : DistributionNetwork;
        part controller : PumpController;
        
        flow waterFlow1 of Water from intakeReservoir.waterOut.water to pump.waterIn.water;
        flow waterFlow2 of Water from pump.waterOut.water to distributionNetwork.waterIn.water;
        
        flow driveFlow of Torque from motor.driveOut.torque to pump.driveIn.torque;
        
        flow levelDataFlow of LevelData from levelSensor.dataOut.data to controller.levelIn.levelData;
        flow pressureDataFlow of PressureData from pressureSensor.dataOut.data to controller.pressureIn.pressureData;
        flow flowDataFlow of FlowData from flowMeter.dataOut.data to controller.flowIn.flowData;
        
        flow commandFlow of MotorCommand from controller.commandOut.command to motor.commandIn.command;
    }
    
    requirement def MaintainPressure {
        subject station : WaterPumpStation;
        /* The station shall maintain output pressure at targetPressure +/- 0.5 bar. */
        attribute targetPressure : Pressure;
    }
    
    requirement def PreventDryRun {
        subject station : WaterPumpStation;
        /* The station shall stop the pump if intake level falls below 1.0 m. */
        attribute minLevel : Length = 1.0;
    }
    
    requirement def MeetFlowDemand {
        subject station : WaterPumpStation;
        /* The station shall provide a flow rate that meets the city's demand. */
        attribute targetFlow : VolumeFlowRate;
    }
}
