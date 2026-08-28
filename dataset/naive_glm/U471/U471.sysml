package HydraulicPowerSystem {

    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def DisplacementValue :> Real;
    attribute def AngleValue :> Real;
    attribute def RotationalSpeedValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def LengthValue :> Real;
    attribute def PowerValue :> Real;
    attribute def MassValue :> Real;
    attribute def ForceValue :> Real;
    attribute def TimeValue :> Real;

    item def HydraulicFluid {
        attribute density : MassValue;
        attribute viscosity : Real;
        attribute bulkModulus : PressureValue;
    }

    port def HydraulicPort {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }

    port def DrivePort {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
    }

    port def ControlPort {
        attribute command : String;
        attribute value : Real;
    }

    action def StartPumpAction;
    action def StopPumpAction;
    action def EmergencyStopAction;
    action def MonitorAction;
    action def AssessPerformanceAction;

    part def Reservoir {
        out port suction : HydraulicPort;
        in port return : HydraulicPort;
        attribute storedVolume : VolumeValue;
        attribute maxVolume : VolumeValue;
        attribute ambientTemperature : TemperatureValue;
    }

    part def Filter {
        in port fluidIn : HydraulicPort;
        out port fluidOut : HydraulicPort;
        attribute pressureDrop : PressureValue;
        attribute efficiency : Real;
        attribute micronRating : Real;
        attribute isClogged : Boolean;
    }

    part def Motor {
        in port controlIn : ControlPort;
        out port driveOut : DrivePort;
        attribute ratedSpeed : RotationalSpeedValue;
        attribute ratedTorque : TorqueValue;
        attribute running : Boolean;
        attribute electricalPowerInput : PowerValue;
    }

    part def Swashplate {
        attribute angle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute minAngle : AngleValue;
    }

    part def Piston {
        attribute boreDiameter : LengthValue;
        attribute maxStrokeLength : LengthValue;
        attribute currentStroke : LengthValue;
        attribute position : LengthValue;
    }

    part def CylinderBlock {
        attribute rotationalPosition : AngleValue;
        attribute numberOfPistons : Integer = 9;
        part pistons[9] : Piston;
    }

    part def VariableDisplacementPump {
        in port driveIn : DrivePort;
        in port suctionIn : HydraulicPort;
        out port dischargeOut : HydraulicPort;
        in port controlIn : ControlPort;
        out port pumpStatusOut : ControlPort;

        attribute displacement : DisplacementValue;
        attribute swashplateAngle : AngleValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute volumetricEfficiency : Real;
        attribute maxPressure : PressureValue;
        attribute isRunning : Boolean;

        part cylinderBlock : CylinderBlock;
        part swashplate : Swashplate;

        attribute actualFlowRate : FlowRateValue = rotationalSpeed * displacement * volumetricEfficiency;
    }

    part def Actuator {
        in port hydraulicIn : HydraulicPort;
        out port returnOut : HydraulicPort;
        attribute maxForce : ForceValue;
        attribute strokeLength : LengthValue;
        attribute currentForce : ForceValue;
        attribute currentVelocity : LengthValue;
    }

    part def PressureReliefValve {
        in port lineIn : HydraulicPort;
        out port reliefOut : HydraulicPort;
        attribute setPressure : PressureValue;
        attribute isOpen : Boolean;
        attribute currentPressure : PressureValue;
        attribute crackingPressure : PressureValue;
    }

    part def Cooler {
        in port fluidIn : HydraulicPort;
        out port fluidOut : HydraulicPort;
        attribute coolingCapacity : PowerValue;
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute isOperating : Boolean;
    }

    part def Controller {
        in port pressureSensor : HydraulicPort;
        in port temperatureSensor : HydraulicPort;
        in port pumpStatusIn : ControlPort;
        out port pumpControlOut : ControlPort;
        out port eStopOut : ControlPort;

        attribute safeMaxPressure : PressureValue;
        attribute safeMinPressure : PressureValue;
        attribute safeMaxTemperature : TemperatureValue;
        attribute safeMinTemperature : TemperatureValue;
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute systemStatus : String;
        attribute monitorEnabled : Boolean;
        attribute eStopActive : Boolean;

        state machine OperationStates {
            state Off;
            state StartingUp {
                entry StartPumpAction;
            }
            state Running {
                do MonitorAction;
            }
            state ShuttingDown {
                entry StopPumpAction;
            }
            state EmergencyStopped {
                entry EmergencyStopAction;
            }

            transition Off2Starting {
                source = Off;
                target = StartingUp;
                guard = (pumpStatusIn.command == "start") and (not eStopActive);
            }
            transition Starting2Running {
                source = StartingUp;
                target = Running;
                guard = (pumpControlOut.value > 0);
            }
            transition Running2Shutting {
                source = Running;
                target = ShuttingDown;
                guard = (pumpStatusIn.command == "stop");
            }
            transition Shutting2Off {
                source = ShuttingDown;
                target = Off;
                guard = (pumpControlOut.value == 0);
            }
            transition Running2Emergency {
                source = Running;
                target = EmergencyStopped;
                guard = (pumpStatusIn.command == "estop") or (currentPressure > safeMaxPressure) or (currentTemperature > safeMaxTemperature);
            }
            transition Starting2Emergency {
                source = StartingUp;
                target = EmergencyStopped;
                guard = (pumpStatusIn.command == "estop") or (currentPressure > safeMaxPressure) or (currentTemperature > safeMaxTemperature);
            }
            transition Emergency2Off {
                source = EmergencyStopped;
                target = Off;
                guard = (pumpStatusIn.command == "reset");
            }
        }

        compute assessStatus : String = (
            (currentPressure > safeMaxPressure) or (currentTemperature > safeMaxTemperature) ? "critical"
            : ((currentPressure > 0.8 * safeMaxPressure) or (currentTemperature > 0.8 * safeMaxTemperature) ? "degraded"
            : "normal")
        );
    }

    part hydraulicPowerSystem {
        part reservoir : Reservoir;
        part suctionFilter : Filter;
        part motor : Motor;
        part pump : VariableDisplacementPump;
        part pressureFilter : Filter;
        part reliefValve : PressureReliefValve;
        part actuator : Actuator;
        part cooler : Cooler;
        part controller : Controller;

        connection driveConnection {
            end a = motor.driveOut;
            end b = pump.driveIn;
        }

        connection suctionConnection1 {
            end a = reservoir.suction;
            end b = suctionFilter.fluidIn;
        }
        connection suctionConnection2 {
            end a = suctionFilter.fluidOut;
            end b = pump.suctionIn;
        }

        connection dischargeConnection1 {
            end a = pump.dischargeOut;
            end b = pressureFilter.fluidIn;
        }
        connection dischargeConnection2 {
            end a = pressureFilter.fluidOut;
            end b = actuator.hydraulicIn;
        }

        connection returnConnection1 {
            end a = actuator.returnOut;
            end b = cooler.fluidIn;
        }
        connection returnConnection2 {
            end a = cooler.fluidOut;
            end b = reservoir.return;
        }

        connection reliefTapConnection {
            end a = pump.dischargeOut;
            end b = reliefValve.lineIn;
        }
        connection reliefReturnConnection {
            end a = reliefValve.reliefOut;
            end b = cooler.fluidIn;
        }

        connection pressureMonitorConnection {
            end a = pump.dischargeOut;
            end b = controller.pressureSensor;
        }
        connection temperatureMonitorConnection {
            end a = cooler.fluidOut;
            end b = controller.temperatureSensor;
        }
        connection pumpStatusConnection {
            end a = pump.pumpStatusOut;
            end b = controller.pumpStatusIn;
        }
        connection pumpControlConnection {
            end a = controller.pumpControlOut;
            end b = pump.controlIn;
        }
        connection eStopConnection {
            end a = controller.eStopOut;
            end b = motor.controlIn;
        }
    }

    requirement def PumpPerformanceRequirement {
        doc :>> "The variable-displacement pump shall deliver variable flow rates by adjusting the swash plate angle.";
        attribute minDisplacement : DisplacementValue;
        attribute maxDisplacement : DisplacementValue;
        attribute maxOperatingPressure : PressureValue;
        attribute pistonCount : Integer;
        constraint {
            maxOperatingPressure <= 3.0e7;
            pistonCount == 9;
        }
    }

    requirement def SafetyRequirement {
        doc :>> "The pressure relief valve shall open at set pressure to prevent over-pressurization.";
        attribute reliefSetPressure : PressureValue;
        attribute maxSafePressure : PressureValue;
        constraint {
            reliefSetPressure <= maxSafePressure;
        }
    }

    requirement def MonitoringRequirement {
        doc :>> "The controller shall monitor system pressure and fluid temperature continuously and assess performance as normal, degraded, or critical.";
        attribute monitoringInterval : TimeValue;
        attribute pressureAlarmThreshold : PressureValue;
        attribute temperatureAlarmThreshold : TemperatureValue;
        attribute statusLevels : String;
    }

    requirement def EmergencyStopRequirement {
        doc :>> "Emergency stop shall halt pump operation within 0.5 seconds.";
        attribute responseTime : TimeValue;
        constraint {
            responseTime <= 0.5;
        }
    }

    requirement def FiltrationRequirement {
        doc :>> "Suction filter shall be 10 micron; pressure filter shall be 3 micron or better.";
        attribute suctionFilterRating : Real;
        attribute pressureFilterRating : Real;
        constraint {
            suctionFilterRating <= 10.0;
            pressureFilterRating <= 3.0;
        }
    }

    requirement def CirculationRequirement {
        doc :>> "Hydraulic fluid shall circulate through the complete circuit: reservoir, suction filter, pump, pressure filter, actuator, cooler, and back to reservoir.";
    }

    requirement def CoolerRequirement {
        doc :>> "The cooler shall maintain fluid temperature within safe operating limits.";
        attribute maxCoolingCapacity : PowerValue;
        attribute targetOperatingTemperature : TemperatureValue;
    }

    requirement def SystemRequirement {
        doc :>> "The complete hydraulic power system shall generate and control high-pressure fluid to power an external actuator.";

        requirement pumpPerfReq : PumpPerformanceRequirement {
            redefinition minDisplacement = 0.0;
            redefinition maxDisplacement = 1.0e-4;
            redefinition maxOperatingPressure = 3.0e7;
            redefinition pistonCount = 9;
        }
        requirement safetyReq : SafetyRequirement {
            redefinition reliefSetPressure = 2.8e7;
            redefinition maxSafePressure = 3.0e7;
        }
        requirement monitorReq : MonitoringRequirement {
            redefinition monitoringInterval = 0.1;
            redefinition pressureAlarmThreshold = 2.8e7;
            redefinition temperatureAlarmThreshold = 343.15;
            redefinition statusLevels = "normal, degraded, critical";
        }
        requirement eStopReq : EmergencyStopRequirement {
            redefinition responseTime = 0.5;
        }
        requirement filtrReq : FiltrationRequirement {
            redefinition suctionFilterRating = 10.0;
            redefinition pressureFilterRating = 3.0;
        }
        requirement circReq : CirculationRequirement;
        requirement coolerReq : CoolerRequirement {
            redefinition maxCoolingCapacity = 5000.0;
            redefinition targetOperatingTemperature = 333.15;
        }
    }

    satisfy requirement SystemRequirement by hydraulicPowerSystem;
}
