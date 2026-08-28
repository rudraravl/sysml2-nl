package CryolatheModel {
    attribute def CryoTemperature;
    attribute def ChamberPressure;
    attribute def SpindleSpeed;
    attribute def SurfaceRoughness;
    attribute def DimensionalTolerance;
    attribute def Volume;

    attribute def WorkpieceLoadedSignal;
    attribute def ChamberSealedSignal;
    attribute def TargetTempReachedSignal;
    attribute def MachiningCompleteSignal;
    attribute def SafeTempReachedSignal;
    attribute def UnloadCompleteSignal;
    attribute def EmergencyStopSignal;
    attribute def ResetSignal;

    item def CryogenicFluid {
        attribute temperature : CryoTemperature;
        attribute pressure : ChamberPressure;
    }
    item def Workpiece {
        attribute material : String;
        attribute diameter : DimensionalTolerance;
        attribute length : DimensionalTolerance;
    }
    item def MachiningProgram;
    item def ControlCommand;
    item def SensorReading;

    port def CryoFluidPort {
        attribute temperature : CryoTemperature;
        attribute pressure : ChamberPressure;
        in item fluidIn : CryogenicFluid;
        out item fluidOut : CryogenicFluid;
    }
    port def ControlOutPort {
        out item command : ControlCommand;
    }
    port def ControlInPort {
        in item command : ControlCommand;
    }
    port def SensorOutPort {
        out item reading : SensorReading;
    }
    port def SensorInPort {
        in item reading : SensorReading;
    }
    port def SafetyOutPort {
        out item emergencyStop : Boolean;
        out item doorInterlock : Boolean;
        out item leakDetected : Boolean;
    }
    port def SafetyInPort {
        in item emergencyStop : Boolean;
        in item doorInterlock : Boolean;
        in item leakDetected : Boolean;
    }

    action def LoadWorkpiece;
    action def SealChamber;
    action def StartCryoFlow;
    action def MonitorSensors;
    action def ExecuteMachining;
    action def StopCryoFlow;
    action def WarmChamber;
    action def OpenChamber;
    action def UnloadWorkpiece;
    action def HaltAllMotion;
    action def VentChamber;

    part def CryogenicChamber {
        attribute targetTemperature : CryoTemperature;
        attribute currentTemperature : CryoTemperature;
        attribute pressure : ChamberPressure;
        attribute doorSealed : Boolean;
        port cryoInPort : CryoFluidPort;
        port cryoOutPort : CryoFluidPort;
        port tempSensorPort : SensorOutPort;
        port pressureSensorPort : SensorOutPort;
    }

    part def Reservoir {
        attribute capacity : Volume;
    }
    part def Pump {
        port cmdPort : ControlInPort;
    }
    part def Regulator;
    part def SafetyValve;

    part def CryogenicDeliverySystem {
        part reservoir : Reservoir;
        part pump : Pump;
        part regulator : Regulator;
        part safetyValve : SafetyValve;
        port supplyPort : CryoFluidPort;
        port returnPort : CryoFluidPort;
        port controlPort : ControlInPort;
    }

    part def Chuck;
    part def SpindleAssembly {
        part chuck : Chuck;
        ref item workpiece : Workpiece;
        attribute speed : SpindleSpeed;
        port cmdPort : ControlInPort;
        port coolingPort : CryoFluidPort;
        port speedSensorPort : SensorOutPort;
    }

    part def IndexingMotor;
    part def CuttingTool;
    part def ToolTurret {
        attribute stationCount : Integer = 8;
        part indexingMotor : IndexingMotor;
        part tools : CuttingTool[8];
        port cmdPort : ControlInPort;
    }

    part def Actuator;
    part def CuttingInsert;
    part def CuttingToolAssembly {
        part actuators : Actuator[3];
        part cuttingInsert : CuttingInsert;
        port cmdPort : ControlInPort;
        port coolingPort : CryoFluidPort;
        port positionSensorPort : SensorOutPort;
    }

    part def ControlSystem {
        item program : MachiningProgram;
        port commandPort : ControlOutPort;
        port tempFeedbackPort : SensorInPort;
        port pressureFeedbackPort : SensorInPort;
        port speedFeedbackPort : SensorInPort;
        port positionFeedbackPort : SensorInPort;
        port safetyPort : SafetyInPort;
    }

    part def SafetySystem {
        attribute emergencyStopActive : Boolean;
        attribute doorInterlockActive : Boolean;
        attribute leakDetected : Boolean;
        port safetyPort : SafetyOutPort;
    }

    state def OperationalCycle {
        in chamber : CryogenicChamber;
        in delivery : CryogenicDeliverySystem;
        in spindle : SpindleAssembly;
        in turret : ToolTurret;
        in cuttingTool : CuttingToolAssembly;
        in control : ControlSystem;
        in safety : SafetySystem;

        entry; then loading;
        state loading {
            do action loadWorkpieceAction : LoadWorkpiece;
        }
        accept WorkpieceLoadedSignal then sealing;
        state sealing {
            do action sealChamberAction : SealChamber;
        }
        accept ChamberSealedSignal then precooling;
        state precooling {
            entry action startCryoFlowAction : StartCryoFlow;
            do action monitorSensorsAction : MonitorSensors;
        }
        accept TargetTempReachedSignal then machining;
        state machining {
            entry action executeMachiningAction : ExecuteMachining;
            do action monitorSensorsAction2 : MonitorSensors;
        }
        accept MachiningCompleteSignal then postWarmup;
        state postWarmup {
            entry action stopCryoFlowAction : StopCryoFlow;
            do action warmChamberAction : WarmChamber;
        }
        accept SafeTempReachedSignal then unloading;
        state unloading {
            entry action openChamberAction : OpenChamber;
            do action unloadWorkpieceAction : UnloadWorkpiece;
        }
        accept UnloadCompleteSignal then loading;

        accept EmergencyStopSignal then emergencyStop;
        state emergencyStop {
            entry action haltAllMotionAction : HaltAllMotion;
            do action ventChamberAction : VentChamber;
            accept ResetSignal then loading;
        }
    }

    part def Cryolathe {
        part chamber : CryogenicChamber;
        part deliverySystem : CryogenicDeliverySystem;
        part spindle : SpindleAssembly;
        part turret : ToolTurret;
        part cuttingTool : CuttingToolAssembly;
        part control : ControlSystem;
        part safety : SafetySystem;

        connect deliverySystem.supplyPort to chamber.cryoInPort;
        connect chamber.cryoOutPort to deliverySystem.returnPort;
        connect deliverySystem.supplyPort to spindle.coolingPort;
        connect deliverySystem.supplyPort to cuttingTool.coolingPort;
        connect chamber.tempSensorPort to control.tempFeedbackPort;
        connect chamber.pressureSensorPort to control.pressureFeedbackPort;
        connect spindle.speedSensorPort to control.speedFeedbackPort;
        connect cuttingTool.positionSensorPort to control.positionFeedbackPort;
        connect control.commandPort to deliverySystem.controlPort;
        connect control.commandPort to spindle.cmdPort;
        connect control.commandPort to cuttingTool.cmdPort;
        connect control.commandPort to turret.cmdPort;
        connect safety.safetyPort to control.safetyPort;

        exhibit state operationalCycle : OperationalCycle {
            in chamber = chamber;
            in delivery = deliverySystem;
            in spindle = spindle;
            in turret = turret;
            in cuttingTool = cuttingTool;
            in control = control;
            in safety = safety;
        }
    }

    requirement def DimensionalAccuracyReq {
        doc /* The machined part shall have dimensional accuracy within 5 microns. */
        attribute tolerance : DimensionalTolerance = 5.0e-6;
    }
    requirement def SurfaceFinishReq {
        doc /* The surface finish shall be better than 0.1 microns Ra. */
        attribute roughness : SurfaceRoughness = 1.0e-7;
    }
    requirement def CryoTempReq {
        doc /* The chamber temperature shall be maintained at 77 K during machining. */
        attribute targetTemp : CryoTemperature = 77.0;
    }
    requirement def SafetyInterlockReq {
        doc /* The system shall prevent operation when the chamber door is open. */
    }
}
