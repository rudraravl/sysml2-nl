package ScoopWheelSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value def Power :> Real {
        unit 'kW';
    }

    value def Torque :> Real {
        unit 'N*m';
    }

    value def AngularSpeed :> Real {
        unit 'rpm';
    }

    value def Diameter :> Real {
        unit 'm';
    }

    value def MassFlowRate :> Real {
        unit 'kg/s';
    }

    value def Volume :> Real {
        unit 'm**3';
    }

    value def Mass :> Real {
        unit 'kg';
    }

    value def Angle :> Real {
        unit 'deg';
    }

    value def Duration :> Real {
        unit 's';
    }

    // ===== Item Types =====

    item def BulkMaterial {
        attribute density : Real = 1500 [kg/m**3];
        attribute particleSize : Real;
    }

    item def Grain :> BulkMaterial {
        redef density = 780 [kg/m**3];
    }

    item def Sand :> BulkMaterial {
        redef density = 1600 [kg/m**3];
    }

    // ===== Enumerations =====

    enum def OperationalMode {
        stopped;
        starting;
        accelerating;
        running;
        stopping;
        emergencyStop;
    }

    enum def CommandKind {
        start;
        stop;
        emergencyStop;
        reset;
    }

    // ===== Port Definitions =====

    port def MaterialFlowPort {
        out item : BulkMaterial;
        attribute flowRate : MassFlowRate;
    }

    port def CommandPort {
        in command : CommandKind;
    }

    port def PowerPort {
        out power : Power;
        out torque : Torque;
        out speed : AngularSpeed;
    }

    port def ControlSignalPort {
        in speedSetpoint : AngularSpeed;
        in enable : Boolean;
        out actualSpeed : AngularSpeed;
        out status : OperationalMode;
    }

    // ===== Requirements =====

    requirement def SystemRequirements {

        requirement WheelDiameterRequirement {
            doc "The main wheel shall have a diameter of 4 meters."
            subject wheel : ScoopWheel;
            constraint { wheel.diameter == 4 [m] }
        }

        requirement BucketCountRequirement {
            doc "The wheel shall be equipped with twelve scoop buckets."
            subject wheel : ScoopWheel;
            constraint { wheel.bucketCount == 12 }
        }

        requirement MotorPowerRequirement {
            doc "The drive motor shall provide 22 kilowatts of power."
            subject motor : DriveMotor;
            constraint { motor.ratedPower == 22 [kW] }
        }

        requirement MaterialTransferRequirement {
            doc "The system shall continuously lift bulk material from a low point to a higher point."
            subject system : ScoopWheelSystem;
            constraint { system.inputHopper.position < system.dischargeChute.position }
        }

        requirement OperationalSafetyRequirement {
            doc "The system shall support emergency stop functionality."
            subject system : ScoopWheelSystem;
            constraint { system.controller.supportsEmergencyStop == true }
        }

        requirement StateTransitionRequirement {
            doc "The system shall transition through stopped, starting, accelerating, running, and stopping states."
            subject system : ScoopWheelSystem;
            constraint { system.controller.stateMachine.definedStates == 
                OperationalMode::stopped | OperationalMode::starting | 
                OperationalMode::accelerating | OperationalMode::running | 
                OperationalMode::stopping | OperationalMode::emergencyStop }
        }
    }

    // ===== Parts =====

    part def ScoopBucket {
        attribute capacity : Volume = 0.05 [m**3];
        attribute fillLevel : Real = 0.0;
        attribute position : Angle;
        attribute isFull : Boolean = false;
        
        action def FillAction {
            in material : BulkMaterial;
            out filled : Boolean;
        }
        
        action def DischargeAction {
            out material : BulkMaterial;
            out emptied : Boolean;
        }
    }

    part def ScoopWheel {
        attribute diameter : Diameter = 4 [m];
        attribute bucketCount : Integer = 12;
        attribute rotationalSpeed : AngularSpeed = 0 [rpm];
        attribute nominalSpeed : AngularSpeed = 12 [rpm];
        attribute buckets : ScoopBucket[12];
        
        port driveInput : PowerPort;
        port materialPickup : MaterialFlowPort;
        port materialDischarge : MaterialFlowPort;
        
        action def RotateAction {
            in power : Power;
            in torque : Torque;
            out speed : AngularSpeed;
            
            // Buckets fill at bottom of arc
            perform fillCycle {
                when rotationalSpeed > 0 [rpm] and bucketAtBottom();
                then buckets.fillLevel := 1.0;
            }
            
            // Buckets discharge at top of arc
            perform dischargeCycle {
                when bucketAtTop();
                then buckets.fillLevel := 0.0;
            }
        }
        
        private def bucketAtBottom() : Boolean {
            return true;
        }
        
        private def bucketAtTop() : Boolean {
            return true;
        }
    }

    part def DriveMotor {
        attribute ratedPower : Power = 22 [kW];
        attribute ratedTorque : Torque = 1750 [N*m];
        attribute currentSpeed : AngularSpeed = 0 [rpm];
        attribute targetSpeed : AngularSpeed = 0 [rpm];
        attribute enabled : Boolean = false;
        
        port powerOutput : PowerPort;
        port controlInput : ControlSignalPort;
        
        action def GenerateTorque {
            in setpoint : AngularSpeed;
            in enable : Boolean;
            out power : Power;
            out torque : Torque;
            out speed : AngularSpeed;
            
            if enable {
                power := ratedPower;
                torque := ratedTorque;
                speed := rampTo(setpoint);
            } else {
                power := 0 [kW];
                torque := 0 [N*m];
                speed := 0 [rpm];
            }
        }
        
        private def rampTo(target : AngularSpeed) : AngularSpeed {
            return target;
        }
    }

    part def InputHopper {
        attribute capacity : Volume = 2.0 [m**3];
        attribute currentLevel : Real = 0.0;
        attribute position : Real = 0.0;
        
        port materialInput : MaterialFlowPort;
        port materialOutput : MaterialFlowPort;
        
        action def ReceiveMaterial {
            in material : BulkMaterial;
            then currentLevel := currentLevel + material.density * 0.001;
        }
        
        action def DispenseMaterial {
            out material : BulkMaterial;
            then currentLevel := currentLevel - 0.001;
        }
    }

    part def DischargeChute {
        attribute inclination : Angle = 45 [deg];
        attribute position : Real = 4.0;
        
        port materialInput : MaterialFlowPort;
        port materialOutput : MaterialFlowPort;
        
        action def GuideMaterial {
            in material : BulkMaterial;
            out material : BulkMaterial;
        }
    }

    part def ControlUnit {
        attribute supportsEmergencyStop : Boolean = true;
        attribute currentState : OperationalMode = OperationalMode::stopped;
        attribute speedSetpoint : AngularSpeed = 12 [rpm];
        attribute accelerationRate : AngularSpeed = 2 [rpm/s];
        attribute decelerationRate : AngularSpeed = 3 [rpm/s];
        
        port operatorCommand : CommandPort;
        port motorControl : ControlSignalPort;
        port wheelFeedback : ControlSignalPort;
        
        state machine def OperationalStateMachine {
            
            state stopped {
                entry { then currentState := OperationalMode::stopped; }
            }
            
            state starting {
                entry { then currentState := OperationalMode::starting; }
            }
            
            state accelerating {
                entry { then currentState := OperationalMode::accelerating; }
            }
            
            state running {
                entry { then currentState := OperationalMode::running; }
            }
            
            state stopping {
                entry { then currentState := OperationalMode::stopping; }
            }
            
            state emergencyStop {
                entry { then currentState := OperationalMode::emergencyStop; }
            }
            
            transition initial to stopped;
            
            transition stopped to starting
                when operatorCommand.command == CommandKind::start;
            
            transition starting to accelerating
                after 2 [s];
            
            transition accelerating to running
                when wheelFeedback.actualSpeed >= speedSetpoint;
            
            transition running to stopping
                when operatorCommand.command == CommandKind::stop;
            
            transition stopping to stopped
                when wheelFeedback.actualSpeed == 0 [rpm];
            
            transition stopped, starting, accelerating, running, stopping to emergencyStop
                when operatorCommand.command == CommandKind::emergencyStop;
            
            transition emergencyStop to stopped
                when operatorCommand.command == CommandKind::reset;
        }
        
        action def ProcessCommand {
            in cmd : CommandKind;
            out speedSetpoint : AngularSpeed;
            out enable : Boolean;
            
            match cmd {
                when CommandKind::start {
                    speedSetpoint := 12 [rpm];
                    enable := true;
                }
                when CommandKind::stop {
                    speedSetpoint := 0 [rpm];
                    enable := false;
                }
                when CommandKind::emergencyStop {
                    speedSetpoint := 0 [rpm];
                    enable := false;
                }
                when CommandKind::reset {
                    speedSetpoint := 0 [rpm];
                    enable := false;
                }
            }
        }
    }

    part def OperatorInterface {
        port commandOutput : CommandPort;
        
        action def IssueCommand {
            out cmd : CommandKind;
        }
    }

    // ===== Top-Level System =====

    part def ScoopWheelSystem {
        
        part operatorInterface : OperatorInterface {
            port commandOutput : CommandPort;
        }
        
        part controller : ControlUnit {
            port operatorCommand : CommandPort;
            port motorControl : ControlSignalPort;
            port wheelFeedback : ControlSignalPort;
        }
        
        part motor : DriveMotor {
            port powerOutput : PowerPort;
            port controlInput : ControlSignalPort;
        }
        
        part wheel : ScoopWheel {
            port driveInput : PowerPort;
            port materialPickup : MaterialFlowPort;
            port materialDischarge : MaterialFlowPort;
        }
        
        part inputHopper : InputHopper {
            port materialInput : MaterialFlowPort;
            port materialOutput : MaterialFlowPort;
        }
        
        part dischargeChute : DischargeChute {
            port materialInput : MaterialFlowPort;
            port materialOutput : MaterialFlowPort;
        }
        
        // Connections
        connection operatorInterface.commandOutput to controller.operatorCommand;
        connection controller.motorControl to motor.controlInput;
        connection motor.powerOutput to wheel.driveInput;
        connection controller.wheelFeedback to motor.controlInput;
        connection inputHopper.materialOutput to wheel.materialPickup;
        connection wheel.materialDischarge to dischargeChute.materialInput;
        
        // System-level ports
        port systemMaterialInput : MaterialFlowPort;
        port systemMaterialOutput : MaterialFlowPort;
        
        connection systemMaterialInput to inputHopper.materialInput;
        connection dischargeChute.materialOutput to systemMaterialOutput;
        
        // Instantiate requirements
        satisfy SystemRequirements::WheelDiameterRequirement by wheel;
        satisfy SystemRequirements::BucketCountRequirement by wheel;
        satisfy SystemRequirements::MotorPowerRequirement by motor;
        satisfy SystemRequirements::MaterialTransferRequirement by self;
        satisfy SystemRequirements::OperationalSafetyRequirement by self;
        satisfy SystemRequirements::StateTransitionRequirement by self;
        
        // System behavior
        action def OperationalCycle {
            in material : BulkMaterial;
            
            // 1. Material enters hopper
            perform receive : inputHopper.ReceiveMaterial {
                in material = material;
            }
            
            // 2. Motor drives wheel
            perform drive : motor.GenerateTorque {
                in setpoint = controller.speedSetpoint;
                in enable = true;
            }
            
            // 3. Wheel rotates, buckets fill at bottom
            perform rotate : wheel.RotateAction {
                in power = drive.power;
                in torque = drive.torque;
            }
            
            // 4. Buckets discharge at top into chute
            perform guide : dischargeChute.GuideMaterial {
                in material = rotate.materialDischarge.item;
            }
            
            // 5. Material exits system
            then systemMaterialOutput.item := guide.material;
        }
    }

}
