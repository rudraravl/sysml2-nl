package PeristalticPumpSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value type PressureValue :> Real {
        unit 'Pa';
    }

    value type FlowRateValue :> Real {
        unit 'mL/min';
    }

    value type RotationalSpeedValue :> Real {
        unit 'rpm';
    }

    value type VolumeValue :> Real {
        unit 'mL';
    }

    value type TorqueValue :> Real {
        unit 'N*m';
    }

    value type VoltageValue :> Real {
        unit 'V';
    }

    value type CurrentValue :> Real {
        unit 'A';
    }

    value type TemperatureValue :> Real {
        unit 'degC';
    }

    // ===== Item Types =====

    item def Fluid {
        attribute density : Real = 1.0; // g/cm^3 (water-like)
        attribute viscosity : Real = 1.0; // cP
    }

    item def MedicalFluid :> Fluid;

    // ===== Port Definitions =====

    port def FluidPort {
        in item fluid : Fluid;
        out attribute pressure : PressureValue;
    }

    port def FluidInPort :> FluidPort;

    port def FluidOutPort :> FluidPort;

    port def ElectricalPowerPort {
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }

    port def ControlSignalPort {
        in attribute commandSpeed : RotationalSpeedValue;
        out attribute actualSpeed : RotationalSpeedValue;
    }

    port def SensorDataPort {
        out attribute pressure : PressureValue;
        out attribute flowRate : FlowRateValue;
    }

    port def PressureSensorPort {
        out attribute pressure : PressureValue;
    }

    port def FlowSensorPort {
        out attribute flowRate : FlowRateValue;
    }

    // ===== Requirements =====

    requirement def PumpSystemRequirement {
        doc "The peristaltic pump system shall accurately transfer fluid from a source reservoir to a delivery line while maintaining sterility."
    }

    requirement PumpAccuracyRequirement :> PumpSystemRequirement {
        doc "The pump shall deliver fluid at the user-specified flow rate within +/- 5% accuracy."
        attribute targetFlowRate : FlowRateValue;
        constraint { flowRate >= targetFlowRate * 0.95 and flowRate <= targetFlowRate * 1.05 }
    }

    requirement SterilityRequirement :> PumpSystemRequirement {
        doc "The fluid shall never contact the pump's mechanical components."
    }

    requirement OcclusionDetectionRequirement :> PumpSystemRequirement {
        doc "The system shall detect a downstream occlusion if outlet pressure exceeds the threshold and enter a faulted state."
        attribute occlusionPressureThreshold : PressureValue = 300000.0; // 300 kPa
        constraint { outletPressure > occlusionPressureThreshold implies pumpState == 'faulted' }
    }

    requirement PrimingRequirement :> PumpSystemRequirement {
        doc "The pump shall execute a priming sequence to fill the tube with fluid before continuous operation."
    }

    requirement ReversingRequirement :> PumpSystemRequirement {
        doc "The pump shall support a reversing mode to change the direction of fluid flow."
    }

    // ===== Parts =====

    part def SourceReservoir {
        port fluidOut : FluidOutPort;
        attribute volume : VolumeValue = 500.0;
        attribute currentVolume : VolumeValue;
        item storedFluid : MedicalFluid;
        
        action def DispenseFluid {
            in amount : VolumeValue;
        }
    }

    part def DeliveryLine {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        attribute length : Real = 1.5; // meters
        attribute innerDiameter : Real = 0.004; // meters
        item flowingFluid : MedicalFluid;
    }

    part def FlexibleTube {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        attribute innerDiameter : Real = 0.003; // meters
        attribute wallThickness : Real = 0.001; // meters
        attribute elasticity : Real = 0.8;
        attribute tubeLength : Real = 0.3; // meters
        item tubeFluid : MedicalFluid;
        
        state def TubeState {
            entry; then Compressed;
            state Compressed;
            state Released;
            transition from Compressed to Released when rollerReleased;
            transition from Released to Compressed when rollerApplied;
        }
    }

    part def Roller {
        attribute diameter : Real = 0.012; // meters
        attribute position : Real; // angular position in radians
    }

    part def Rotor {
        part rollers : Roller[3];
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute rotorDiameter : Real = 0.06; // meters
        attribute currentAngle : Real = 0.0; // radians
        
        action def Rotate {
            in speed : RotationalSpeedValue;
            out angle : Real;
        }
    }

    part def DriveMotor {
        port powerIn : ElectricalPowerPort;
        port controlIn : ControlSignalPort;
        port mechanicalOut : ControlSignalPort;
        attribute nominalSpeed : RotationalSpeedValue = 200.0;
        attribute maxTorque : TorqueValue = 0.5;
        attribute currentSpeed : RotationalSpeedValue;
        attribute direction : Integer = 1; // 1 = forward, -1 = reverse
        
        action def DriveRotor {
            in targetSpeed : RotationalSpeedValue;
            in direction : Integer;
            out actualSpeed : RotationalSpeedValue;
        }
        
        state def MotorState {
            entry; then Stopped;
            state Stopped;
            state Running;
            state Reversing;
            transition from Stopped to Running when startCommand;
            transition from Running to Stopped when stopCommand;
            transition from Running to Reversing when reverseCommand;
            transition from Reversing to Running when forwardCommand;
        }
    }

    part def InletPressureSensor {
        port fluidPort : FluidInPort;
        port dataOut : PressureSensorPort;
        attribute measuredPressure : PressureValue;
        attribute samplingRate : Real = 100.0; // Hz
        
        action def MeasurePressure {
            in fluid : MedicalFluid;
            out pressure : PressureValue;
        }
    }

    part def OutletPressureSensor {
        port fluidPort : FluidInPort;
        port dataOut : PressureSensorPort;
        attribute measuredPressure : PressureValue;
        attribute samplingRate : Real = 100.0; // Hz
        
        action def MeasurePressure {
            in fluid : MedicalFluid;
            out pressure : PressureValue;
        }
    }

    part def FlowRateSensor {
        port fluidPort : FluidInPort;
        port dataOut : FlowSensorPort;
        attribute measuredFlowRate : FlowRateValue;
        attribute samplingRate : Real = 50.0; // Hz
        
        action def MeasureFlowRate {
            in fluid : MedicalFluid;
            out flowRate : FlowRateValue;
        }
    }

    part def PumpController {
        port inletPressureIn : PressureSensorPort;
        port outletPressureIn : PressureSensorPort;
        port flowRateIn : FlowSensorPort;
        port motorControlOut : ControlSignalPort;
        
        attribute userSetFlowRate : FlowRateValue = 50.0;
        attribute occlusionPressureThreshold : PressureValue = 300000.0;
        attribute currentInletPressure : PressureValue;
        attribute currentOutletPressure : PressureValue;
        attribute currentFlowRate : FlowRateValue;
        attribute computedMotorSpeed : RotationalSpeedValue;
        attribute pumpDirection : Integer = 1;
        
        action def RegulateFlow {
            in setFlowRate : FlowRateValue;
            in measuredFlowRate : FlowRateValue;
            in inletPressure : PressureValue;
            in outletPressure : PressureValue;
            out motorSpeed : RotationalSpeedValue;
            out direction : Integer;
            
            // PID-like control logic
            local flowError : Real;
            local pressureDelta : PressureValue;
            
            perform {
                flowError := setFlowRate - measuredFlowRate;
                pressureDelta := outletPressure - inletPressure;
                if outletPressure > occlusionPressureThreshold {
                    motorSpeed := 0.0;
                    direction := 0;
                } else {
                    motorSpeed := setFlowRate * 2.0; // simplified: rpm proportional to desired flow
                    direction := 1;
                }
            }
        }
        
        action def DetectOcclusion {
            in outletPressure : PressureValue;
            out occlusionDetected : Boolean;
            perform {
                occlusionDetected := (outletPressure > occlusionPressureThreshold);
            }
        }
        
        action def ExecutePriming {
            in primingSpeed : RotationalSpeedValue = 100.0;
            out motorSpeed : RotationalSpeedValue;
            out direction : Integer;
            perform {
                motorSpeed := primingSpeed;
                direction := 1;
            }
        }
        
        state def ControllerStateMachine {
            entry; then Idle;
            
            state Idle {
                entry;
                // No motor output, waiting for user command
            }
            
            state Priming {
                entry;
                // Run motor at priming speed to fill tube
            }
            
            state Running {
                entry;
                // Continuous operation with flow regulation
            }
            
            state Reversing {
                entry;
                // Reverse motor direction
            }
            
            state Faulted {
                entry;
                // Stop motor for safety
            }
            
            transition from Idle to Priming when primeCommandReceived;
            transition from Priming to Running when primingComplete;
            transition from Running to Reversing when reverseCommandReceived;
            transition from Reversing to Running when forwardCommandReceived;
            transition from Running to Faulted when occlusionDetected;
            transition from Priming to Faulted when occlusionDetected;
            transition from Reversing to Faulted when occlusionDetected;
            transition from Faulted to Idle when faultResetCommandReceived;
            transition from Running to Idle when stopCommandReceived;
        }
    }

    part def PumpHead {
        port tubeInlet : FluidInPort;
        port tubeOutlet : FluidOutPort;
        part flexibleTube : FlexibleTube;
        part rotor : Rotor;
        
        connection def TubeRouting {
            end from : FluidOutPort;
            end to : FluidInPort;
        }
        
        connection tubeInletConnection : TubeRouting connect tubeInlet to flexibleTube.inlet;
        connection tubeOutletConnection : TubeRouting connect flexibleTube.outlet to tubeOutlet;
    }

    part def PumpAssembly {
        port fluidInlet : FluidInPort;
        port fluidOutlet : FluidOutPort;
        port powerInput : ElectricalPowerPort;
        
        part pumpHead : PumpHead;
        part driveMotor : DriveMotor;
        part inletPressureSensor : InletPressureSensor;
        part outletPressureSensor : OutletPressureSensor;
        part flowRateSensor : FlowRateSensor;
        part controller : PumpController;
        
        connection def FluidConnection {
            end from : FluidOutPort;
            end to : FluidInPort;
        }
        
        connection inletFluidConn : FluidConnection connect fluidInlet to pumpHead.tubeInlet;
        connection inletSensorConn : FluidConnection connect fluidInlet to inletPressureSensor.fluidPort;
        connection outletFluidConn1 : FluidConnection connect pumpHead.tubeOutlet to outletPressureSensor.fluidPort;
        connection outletFluidConn2 : FluidConnection connect outletPressureSensor.fluidPort to flowRateSensor.fluidPort;
        connection outletFluidConn3 : FluidConnection connect flowRateSensor.fluidPort to fluidOutlet;
        
        connection def ControlConnection {
            end from : ControlSignalPort;
            end to : ControlSignalPort;
        }
        
        connection motorControlConn : ControlConnection connect controller.motorControlOut to driveMotor.controlIn;
        connection motorFeedbackConn : ControlConnection connect driveMotor.mechanicalOut to controller.motorControlOut;
        
        connection def SensorDataConnection {
            end from : PressureSensorPort;
            end to : PressureSensorPort;
        }
        
        connection def FlowDataConnection {
            end from : FlowSensorPort;
            end to : FlowSensorPort;
        }
        
        connection inletPressureDataConn : SensorDataConnection connect inletPressureSensor.dataOut to controller.inletPressureIn;
        connection outletPressureDataConn : SensorDataConnection connect outletPressureSensor.dataOut to controller.outletPressureIn;
        connection flowRateDataConn : FlowDataConnection connect flowRateSensor.dataOut to controller.flowRateIn;
        
        connection powerConn connect powerInput to driveMotor.powerIn;
    }

    // ===== Top-Level System =====

    part PeristalticPumpSystem {
        part sourceReservoir : SourceReservoir;
        part pumpAssembly : PumpAssembly;
        part deliveryLine : DeliveryLine;
        
        connection def SystemFluidConnection {
            end from : FluidOutPort;
            end to : FluidInPort;
        }
        
        connection reservoirToPump : SystemFluidConnection connect sourceReservoir.fluidOut to pumpAssembly.fluidInlet;
        connection pumpToDelivery : SystemFluidConnection connect pumpAssembly.fluidOutlet to deliveryLine.fluidIn;
        
        // System-level requirement satisfaction
        satisfy PumpAccuracyRequirement by pumpAssembly.controller;
        satisfy SterilityRequirement by pumpAssembly.pumpHead.flexibleTube;
        satisfy OcclusionDetectionRequirement by pumpAssembly.controller;
        satisfy PrimingRequirement by pumpAssembly.controller;
        satisfy ReversingRequirement by pumpAssembly.controller;
    }

}
