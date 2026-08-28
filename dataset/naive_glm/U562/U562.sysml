package SlipFactorControlSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    value type AngularVelocity > Real { unit 'rad/s'; }
    value type LinearVelocity > Real { unit 'm/s'; }
    value type SlipRatio > Real { unit '1'; min 0.0; max 10.0; }
    value type TargetSlipRatio :> SlipRatio { default 0.1; }
    value type Torque > Real { unit 'N*m'; min 0.0; }
    value type TorqueReduction > Real { unit 'N*m'; min 0.0; }
    value type Temperature > Real { unit 'degC'; }
    value type Frequency > Real { unit 'Hz'; }
    value type TimeMs > Real { unit 'ms'; }
    value type Power > Real { unit 'W'; }
    value type Pressure > Real { unit 'Pa'; }
    value type BooleanStatus :> Boolean;
    
    // ===== Item Types =====
    item def WheelSpeedSignal {
        attribute wheelId : Integer;
        attribute value : AngularVelocity;
        attribute timestamp : TimeMs;
    }
    
    item def VehicleSpeedSignal {
        attribute value : LinearVelocity;
        attribute timestamp : TimeMs;
    }
    
    item def SlipRatioSignal {
        attribute wheelId : Integer;
        attribute value : SlipRatio;
        attribute timestamp : TimeMs;
    }
    
    item def TorqueCommand {
        attribute wheelId : Integer;
        attribute reduction : TorqueReduction;
        attribute timestamp : TimeMs;
    }
    
    item def TemperatureReading {
        attribute sourceId : String;
        attribute value : Temperature;
        attribute timestamp : TimeMs;
    }
    
    item def FaultAlert {
        attribute componentId : String;
        attribute code : Integer;
        attribute severity : Integer;
        attribute timestamp : TimeMs;
    }
    
    // ===== Port Definitions =====
    port def WheelSpeedOutPort { out item wheelSpeed : WheelSpeedSignal; }
    port def VehicleSpeedOutPort { out item vehicleSpeed : VehicleSpeedSignal; }
    port def SlipRatioOutPort { out item slipRatio : SlipRatioSignal; }
    port def SlipRatioInPort { in item slipRatio : SlipRatioSignal; }
    port def TorqueCmdOutPort { out item command : TorqueCommand; }
    port def TorqueCmdInPort { in item command : TorqueCommand; }
    port def TempOutPort { out item reading : TemperatureReading; }
    port def TempInPort { in item reading : TemperatureReading; }
    port def FaultOutPort { out item alert : FaultAlert; }
    port def FaultInPort { in item alert : FaultAlert; }
    port def MechanicalPowerPort { in item torque : Torque; }
    
    // ===== Velocity Sensor =====
    part def VelocitySensor {
        attribute samplingRate : Frequency = 100.0;
        attribute operatingTempMax : Temperature = 125.0;
        
        port wheelSpeedOut : WheelSpeedOutPort;
        port vehicleSpeedOut : VehicleSpeedOutPort;
        port tempOut : TempOutPort;
        
        attribute currentWheelSpeed : AngularVelocity;
        attribute currentVehicleSpeed : LinearVelocity;
        attribute sensorTemp : Temperature;
        
        action def SampleWheelSpeed {
            out sampledValue : AngularVelocity;
            done when samplingRate cycles elapsed;
        }
        
        action def SampleVehicleSpeed {
            out sampledValue : LinearVelocity;
        }
        
        action def TransmitSignals {
            in wheel : AngularVelocity;
            in vehicle : LinearVelocity;
            then wheelSpeedOut.wheelSpeed;
            then vehicleSpeedOut.vehicleSpeed;
        }
        
        composite action SensorOperation {
            action sampleWheel : SampleWheelSpeed;
            action sampleVehicle : SampleVehicleSpeed;
            action transmit : TransmitSignals {
                in wheel = sampleWheel.sampledValue;
                in vehicle = sampleVehicle.sampledValue;
            }
        }
    }
    
    // ===== Slip Estimator =====
    part def SlipEstimator {
        attribute wheelRadius : Real = 0.3 { unit 'm'; }
        attribute numWheels : Integer = 4;
        
        port wheelSpeedIn : WheelSpeedOutPort;
        port vehicleSpeedIn : VehicleSpeedOutPort;
        port slipRatioOut : SlipRatioOutPort;
        port tempOut : TempOutPort;
        
        attribute estimatorTemp : Temperature;
        attribute slipValues : SlipRatio[4];
        
        action def ComputeSlipRatio {
            in wheelSpeed : AngularVelocity;
            in vehicleSpeed : LinearVelocity;
            in radius : Real;
            out ratio : SlipRatio;
            
            // slip = (omega * r - v) / max(v, epsilon)
            compute {
                let theoreticalSpeed = wheelSpeed * radius;
                let denom = if vehicleSpeed > 0.1 then vehicleSpeed else 0.1;
                ratio := (theoreticalSpeed - vehicleSpeed) / denom;
            }
        }
        
        action def EstimateAllWheels {
            in wheelSpeeds : AngularVelocity[4];
            in vehicleSpeed : LinearVelocity;
            out ratios : SlipRatio[4];
            
            for i in 1..4 {
                action compute : ComputeSlipRatio {
                    in wheelSpeed = wheelSpeeds(i);
                    in vehicleSpeed = vehicleSpeed;
                    in radius = wheelRadius;
                    out ratio = ratios(i);
                }
            }
        }
        
        composite action EstimationLoop {
            action estimate : EstimateAllWheels;
            then slipRatioOut.slipRatio;
        }
    }
    
    // ===== Traction Controller =====
    part def TractionController {
        attribute targetSlip : TargetSlipRatio = 0.1;
        attribute maxReduction : TorqueReduction = 500.0;
        attribute controlLoopPeriod : TimeMs = 5.0;
        attribute controllerTemp : Temperature;
        
        port slipRatioIn : SlipRatioInPort;
        port torqueCmdOut : TorqueCmdOutPort;
        port tempOut : TempOutPort;
        port faultOut : FaultOutPort;
        
        attribute activeWheel : Integer;
        attribute currentReduction : TorqueReduction;
        
        action def CalculateTorqueReduction {
            in measured : SlipRatio;
            in target : SlipRatio;
            in maxRed : TorqueReduction;
            out reduction : TorqueReduction;
            
            compute {
                let error := measured - target;
                let proportional := error * 1000.0;
                reduction := if proportional > maxRed then maxRed 
                              else if proportional < 0.0 then 0.0 
                              else proportional;
            }
        }
        
        action def IssueCommand {
            in wheelId : Integer;
            in reduction : TorqueReduction;
            then torqueCmdOut.command;
        }
        
        composite action ControlCycle {
            action calc : CalculateTorqueReduction {
                in measured = slipRatioIn.slipRatio.value;
                in target = targetSlip;
                in maxRed = maxReduction;
            }
            action issue : IssueCommand {
                in wheelId = slipRatioIn.slipRatio.wheelId;
                in reduction = calc.reduction;
            }
        }
        
        state def ControllerStates {
            attribute status : String;
            
            initial state Inactive {
                entry action { status := "inactive"; }
                transition to Monitoring 
                    when slipRatioIn.slipRatio.timestamp > 0 
                    and controllerTemp < 85.0;
            }
            
            state Monitoring {
                entry action { status := "monitoring"; }
                transition to ActiveControlling 
                    when slipRatioIn.slipRatio.value > targetSlip;
                transition to EmergencyMode 
                    when controllerTemp > 100.0;
            }
            
            state ActiveControlling {
                entry action { status := "active"; }
                do ControlCycle;
                transition to Monitoring 
                    when slipRatioIn.slipRatio.value <= targetSlip;
                transition to EmergencyMode 
                    when controllerTemp > 100.0;
            }
            
            state EmergencyMode {
                entry action { 
                    status := "emergency"; 
                    faultOut.alert := FaultAlert{componentId="TractionController", code=1, severity=3};
                }
                transition to Inactive 
                    when controllerTemp < 60.0;
            }
        }
    }
    
    // ===== Torque Actuator =====
    part def TorqueActuator {
        attribute maxTorque : Torque = 400.0;
        attribute responseTime : TimeMs = 2.0;
        attribute actuatorTemp : Temperature;
        attribute actuatorPressure : Pressure;
        
        port torqueCmdIn : TorqueCmdInPort;
        port powerIn : MechanicalPowerPort;
        port powerOut : MechanicalPowerPort;
        port tempOut : TempOutPort;
        port faultOut : FaultOutPort;
        
        attribute appliedReduction : TorqueReduction;
        attribute outputTorque : Torque;
        
        action def ApplyTorqueReduction {
            in command : TorqueCommand;
            in inputTorque : Torque;
            out outputTorque : Torque;
            out applied : TorqueReduction;
            
            compute {
                applied := command.reduction;
                outputTorque := if inputTorque > applied then inputTorque - applied else 0.0;
            }
        }
        
        composite action ActuationLoop {
            action apply : ApplyTorqueReduction {
                in command = torqueCmdIn.command;
                in inputTorque = powerIn.torque;
            }
            then powerOut.torque;
        }
        
        state def ActuatorStates {
            attribute status : String;
            
            initial state Idle {
                entry action { status := "idle"; }
                transition to Engaged 
                    when torqueCmdIn.command.reduction > 0.0;
            }
            
            state Engaged {
                entry action { status := "engaged"; }
                do ActuationLoop;
                transition to Idle 
                    when torqueCmdIn.command.reduction == 0.0;
                transition to Faulted 
                    when actuatorTemp > 110.0 
                    or actuatorPressure > 2.0e7;
            }
            
            state Faulted {
                entry action { 
                    status := "faulted"; 
                    faultOut.alert := FaultAlert{componentId="TorqueActuator", code=2, severity=3};
                }
                transition to Idle 
                    when actuatorTemp < 70.0 
                    and actuatorPressure < 1.5e7;
            }
        }
    }
    
    // ===== Powertrain =====
    part def Powertrain {
        attribute enginePower : Power = 200000.0;
        attribute maxTorque : Torque = 350.0;
        attribute powertrainTemp : Temperature;
        
        port powerOut : MechanicalPowerPort;
        port tempOut : TempOutPort;
        
        part engine {
            attribute outputTorque : Torque;
        }
        part gearbox {
            attribute gearRatio : Real = 3.5;
        }
        part differential {
            attribute torqueSplit : Real = 0.5;
        }
        
        action def GenerateTorque {
            out torque : Torque;
            compute { torque := maxTorque; }
        }
        
        composite action PowerGeneration {
            action gen : GenerateTorque;
            then powerOut.torque;
        }
    }
    
    // ===== Wheel Assembly =====
    part def WheelAssembly {
        attribute wheelId : Integer;
        attribute wheelRadius : Real = 0.3 { unit 'm'; }
        attribute hubTemp : Temperature;
        attribute rotationalSpeed : AngularVelocity;
        attribute slipState : SlipRatio;
        
        port powerIn : MechanicalPowerPort;
        port speedOut : WheelSpeedOutPort;
        port tempOut : TempOutPort;
        
        part tire {
            attribute gripCoefficient : Real = 0.9;
        }
        part rim {
            attribute mass : Real = 15.0 { unit 'kg'; }
        }
        part hub {
            attribute bearingTemp : Temperature;
        }
        
        action def RotateWheel {
            in inputTorque : Torque;
            out speed : AngularVelocity;
            compute { speed := inputTorque / 2.0; }
        }
        
        composite action WheelDynamics {
            action rotate : RotateWheel {
                in inputTorque = powerIn.torque;
            }
            then speedOut.wheelSpeed;
        }
    }
    
    // ===== Slip Factor Control System (Top-Level) =====
    part def SlipFactorControlSystem {
        attribute systemId : String = "SFCS-001";
        attribute numWheels : Integer = 4;
        attribute systemStatus : String;
        
        // Components
        part velocitySensor : VelocitySensor;
        part slipEstimator : SlipEstimator;
        part tractionController : TractionController;
        part torqueActuator : TorqueActuator;
        part powertrain : Powertrain;
        part wheels : WheelAssembly[4];
        
        // Connections - signal flow
        connection wheelSpeedFlow 
            from velocitySensor.wheelSpeedOut 
            to slipEstimator.wheelSpeedIn;
        connection vehicleSpeedFlow 
            from velocitySensor.vehicleSpeedOut 
            to slipEstimator.vehicleSpeedIn;
        connection slipRatioFlow 
            from slipEstimator.slipRatioOut 
            to tractionController.slipRatioIn;
        connection torqueCmdFlow 
            from tractionController.torqueCmdOut 
            to torqueActuator.torqueCmdIn;
        
        // Connections - mechanical power flow
        connection powertrainToActuator 
            from powertrain.powerOut 
            to torqueActuator.powerIn;
        connection actuatorToWheel1 
            from torqueActuator.powerOut 
            to wheels(1).powerIn;
        connection actuatorToWheel2 
            from torqueActuator.powerOut 
            to wheels(2).powerIn;
        connection actuatorToWheel3 
            from torqueActuator.powerOut 
            to wheels(3).powerIn;
        connection actuatorToWheel4 
            from torqueActuator.powerOut 
            to wheels(4).powerIn;
        
        // Connections - wheel speed feedback
        connection wheel1Speed 
            from wheels(1).speedOut 
            to velocitySensor.wheelSpeedOut;
        connection wheel2Speed 
            from wheels(2).speedOut 
            to velocitySensor.wheelSpeedOut;
        connection wheel3Speed 
            from wheels(3).speedOut 
            to velocitySensor.wheelSpeedOut;
        connection wheel4Speed 
            from wheels(4).speedOut 
            to velocitySensor.wheelSpeedOut;
        
        // Connections - temperature monitoring
        connection wheelTempFlow 
            from wheels.tempOut 
            to tractionController.tempOut;
        connection powertrainTempFlow 
            from powertrain.tempOut 
            to tractionController.tempOut;
        connection actuatorTempFlow 
            from torqueActuator.tempOut 
            to tractionController.tempOut;
        connection controllerTempFlow 
            from tractionController.tempOut 
            to torqueActuator.tempOut;
        
        // Connections - fault reporting
        connection actuatorFaultFlow 
            from torqueActuator.faultOut 
            to tractionController.faultOut;
        
        // System-level state machine
        state def SystemOperatingStates {
            attribute mode : String;
            
            initial state PoweredOff {
                entry action { mode := "off"; systemStatus := "inactive"; }
                transition to Initializing 
                    when true;
            }
            
            state Initializing {
                entry action { mode := "init"; systemStatus := "initializing"; }
                transition to Monitoring 
                    when velocitySensor.sensorTemp < 85.0 
                    and powertrain.powertrainTemp < 90.0;
                transition to EmergencyShutdown 
                    when velocitySensor.sensorTemp > 120.0;
            }
            
            state Monitoring {
                entry action { mode := "monitor"; systemStatus := "monitoring"; }
                transition to ActiveControl 
                    when slipEstimator.slipValues > tractionController.targetSlip;
                transition to EmergencyShutdown 
                    when tractionController.controllerTemp > 100.0 
                    or torqueActuator.actuatorTemp > 110.0;
            }
            
            state ActiveControl {
                entry action { mode := "control"; systemStatus := "active_control"; }
                transition to Monitoring 
                    when slipEstimator.slipValues <= tractionController.targetSlip;
                transition to EmergencyShutdown 
                    when torqueActuator.actuatorTemp > 110.0;
            }
            
            state EmergencyShutdown {
                entry action { 
                    mode := "emergency"; 
                    systemStatus := "emergency_shutdown";
                    torqueActuator.appliedReduction := torqueActuator.maxTorque;
                }
                transition to PoweredOff 
                    when tractionController.controllerTemp < 50.0 
                    and torqueActuator.actuatorTemp < 60.0;
            }
        }
        
        // System-level action for coordinated control
        action def CoordinateSlipControl {
            in wheelSpeeds : AngularVelocity[4];
            in vehicleSpeed : LinearVelocity;
            out commands : TorqueCommand[4];
            
            compute {
                for i in 1..4 {
                    let theoreticalSpeed := wheelSpeeds(i) * 0.3;
                    let denom := if vehicleSpeed > 0.1 then vehicleSpeed else 0.1;
                    let slip := (theoreticalSpeed - vehicleSpeed) / denom;
                    let error := slip - 0.1;
                    let red := if error > 0.0 then error * 1000.0 else 0.0;
                    commands(i) := TorqueCommand{wheelId=i, reduction=red};
                }
            }
        }
    }
    
    // ===== Requirements =====
    requirement def SlipDetectionRequirement {
        doc /* The system shall detect wheel slip within 5 milliseconds of occurrence. */
        attribute maxDetectionTime : TimeMs = 5.0;
        subject :> SlipFactorControlSystem;
        objective :> Boolean = true;
        require constraint { 
            velocitySensor.samplingRate >= 100.0 
            and tractionController.controlLoopPeriod <= 5.0 
        }
    }
    
    requirement def SlipRatioAccuracyRequirement {
        doc /* The slip estimator shall compute slip ratio with accuracy of +/- 0.02. */
        attribute maxError : SlipRatio = 0.02;
        subject :> SlipEstimator;
        require constraint { 
            slipEstimator.wheelRadius > 0.0 
        }
    }
    
    requirement def TorqueReductionRequirement {
        doc /* The controller shall reduce torque by the calculated amount within 2 milliseconds. */
        attribute maxResponseTime : TimeMs = 2.0;
        subject :> TractionController;
        require constraint { 
            tractionController.maxReduction > 0.0 
            and torqueActuator.responseTime <= 2.0 
        }
    }
    
    requirement def TemperatureMonitoringRequirement {
        doc /* The system shall monitor temperatures at wheel hubs, powertrain, and actuator. */
        subject :> SlipFactorControlSystem;
        require constraint { 
            wheels.hub.bearingTemp > 0.0 
            and powertrain.powertrainTemp > 0.0 
            and torqueActuator.actuatorTemp > 0.0 
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall enter emergency mode if any component temperature exceeds safe limits. */
        attribute controllerTempLimit : Temperature = 100.0;
        attribute actuatorTempLimit : Temperature = 110.0;
        attribute sensorTempLimit : Temperature = 120.0;
        subject :> SlipFactorControlSystem;
        require constraint { 
            tractionController.controllerTemp <= controllerTempLimit 
            or torqueActuator.actuatorTemp <= actuatorTempLimit 
            or velocitySensor.operatingTempMax <= sensorTempLimit 
        }
    }
    
    requirement def StabilityEnhancementRequirement {
        doc /* By preventing wheel spin, the system shall maximize acceleration and enhance vehicle stability. */
        attribute targetSlipMax : SlipRatio = 0.15;
        subject :> SlipFactorControlSystem;
        require constraint { 
            tractionController.targetSlip <= targetSlipMax 
        }
    }
    
    // ===== Requirement Satisfaction =====
    satisfaction slipDetectionSatisfies : SlipDetectionRequirement {
    }
    
    satisfaction slipAccuracySatisfies : SlipRatioAccuracyRequirement {
    }
    
    satisfaction torqueReductionSatisfies : TorqueReductionRequirement {
    }
    
    satisfaction tempMonitoringSatisfies : TemperatureMonitoringRequirement {
    }
    
    satisfaction safetySatisfies : SafetyRequirement {
    }
    
    satisfaction stabilitySatisfies : StabilityEnhancementRequirement {
    }
}
