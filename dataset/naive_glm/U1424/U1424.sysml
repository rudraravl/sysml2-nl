package GravitationalEnergyStorageSystem {

    import ISQ::*;
    import ScalarValues::*;
    import SI::*;

    // ---- Value Types with Units ----
    attribute def MassValue :> Mass;
    attribute def HeightValue :> Length;
    attribute def VelocityValue :> Speed;
    attribute def PowerValue :> Power;
    attribute def EnergyValue :> EnergyValue;
    attribute def EfficiencyValue :> Real;
    attribute def ForceValue :> Force;
    attribute def TorqueValue :> Torque;
    attribute def VoltageValue :> ElectricPotential;
    attribute def CurrentValue :> ElectricCurrent;
    attribute def FrequencyValue :> Real;

    // ---- Item Definitions ----
    item def ElectricalEnergy;
    item def MechanicalEnergy;
    item def GridPower;
    item def ControlCommand {
        attribute commandType : String;
    }
    item def StatusReport {
        attribute massHeight : HeightValue;
        attribute systemState : String;
        attribute powerOutput : PowerValue;
    }

    // ---- Port Definitions ----
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
        out item energy : ElectricalEnergy;
    }

    port def MechanicalPowerPort {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : Real;
        out item mechEnergy : MechanicalEnergy;
    }

    port def LinearMotionPort {
        attribute force : ForceValue;
        attribute velocity : VelocityValue;
        attribute position : HeightValue;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : StatusReport;
    }

    // ---- Requirements ----
    requirement def StorageCapacityRequirement {
        doc /* The system shall store gravitational potential energy using a mass of approximately 500,000 kg lifted to 120 m. */
        attribute requiredMass : MassValue = 500000 [kg];
        attribute requiredHeight : HeightValue = 120 [m];
        subject storageSystem : GravitationalEnergyStorageSystem;
        require storageSystem.massBlock.mass == requiredMass;
        require storageSystem.maxLiftHeight == requiredHeight;
    }

    requirement def PowerDeliveryRequirement {
        doc /* The system shall deliver over 4 MW of continuous power during discharge. */
        attribute minContinuousPower : PowerValue = 4.0 [MW];
        subject storageSystem : GravitationalEnergyStorageSystem;
        require storageSystem.dischargePower >= minContinuousPower;
    }

    requirement def EfficiencyRequirement {
        doc /* The system shall achieve a round-trip efficiency of at least 75%. */
        attribute minEfficiency : EfficiencyValue = 0.75;
        subject storageSystem : GravitationalEnergyStorageSystem;
        require storageSystem.roundTripEfficiency >= minEfficiency;
    }

    requirement def SafetyRequirement {
        doc /* The system shall monitor mass block height and operate within safe limits. */
        attribute maxHeight : HeightValue = 120 [m];
        attribute minHeight : HeightValue = 0 [m];
        subject storageSystem : GravitationalEnergyStorageSystem;
        require storageSystem.massBlock.currentHeight <= maxHeight;
        require storageSystem.massBlock.currentHeight >= minHeight;
    }

    // ---- Part Definitions ----

    part def MassBlock {
        attribute mass : MassValue = 500000 [kg];
        attribute currentHeight : HeightValue = 0 [m];
        attribute maxHeight : HeightValue = 120 [m];
        attribute minHeight : HeightValue = 0 [m];
        port motionPort : LinearMotionPort;
        
        attribute storedEnergy : EnergyValue = mass * 9.81 [m/s^2] * currentHeight;
        
        action def Lift :> Action {
            in deltaHeight : HeightValue;
        }
        action def Lower :> Action {
            in deltaHeight : HeightValue;
        }
    }

    part def HoistingMechanism {
        attribute maxLiftForce : ForceValue = 5000000 [N];
        attribute liftSpeed : VelocityValue = 0.5 [m/s];
        attribute motorEfficiency : EfficiencyValue = 0.92;
        
        port mechanicalOutput : LinearMotionPort;
        port electricalInput : ElectricalPort;
        port controlInput : CommandPort;
        
        action def Hoist {
            in targetHeight : HeightValue;
        }
        action def Brake {
            attribute brakeEngaged : Boolean = true;
        }
        action def Release;
    }

    part def Generator {
        attribute ratedPower : PowerValue = 5.0 [MW];
        attribute generatorEfficiency : EfficiencyValue = 0.95;
        attribute outputVoltage : VoltageValue = 690 [V];
        attribute outputFrequency : FrequencyValue = 50.0;
        
        port mechanicalInput : LinearMotionPort;
        port electricalOutput : ElectricalPort;
        
        action def Generate {
            in descentSpeed : VelocityValue;
            out generatedPower : PowerValue;
        }
    }

    part def PowerConverter {
        attribute ratedPower : PowerValue = 5.0 [MW];
        attribute converterEfficiency : EfficiencyValue = 0.97;
        attribute gridVoltage : VoltageValue = 33000 [V];
        attribute gridFrequency : FrequencyValue = 50.0;
        
        port generatorInput : ElectricalPort;
        port gridOutput : ElectricalPort;
        port controlInput : CommandPort;
        
        action def Condition {
            in rawPower : PowerValue;
            out conditionedPower : PowerValue;
        }
        action def Rectify {
            in gridPower : PowerValue;
            out dcPower : PowerValue;
        }
        action def Invert {
            in dcPower : PowerValue;
            out acPower : PowerValue;
        }
    }

    part def SystemController {
        attribute mode : String = "Standby";
        attribute targetRoundTripEfficiency : EfficiencyValue = 0.75;
        attribute safeHeightMin : HeightValue = 0 [m];
        attribute safeHeightMax : HeightValue = 120 [m];
        
        port commandInput : CommandPort;
        port statusOutput : StatusPort;
        port hoistControl : CommandPort;
        port converterControl : CommandPort;
        
        // Monitoring attributes
        attribute monitoredHeight : HeightValue;
        attribute currentPowerFlow : PowerValue;
        attribute systemEfficiency : EfficiencyValue;
        
        state def ControllerStateMachine {
            entry; then Standby;
            
            state Standby {
                entry { mode = "Standby"; }
                on commandInput.command[commandType == "Charge"] then Charging;
                on commandInput.command[commandType == "Discharge"] then Discharging;
            }
            
            state Charging {
                entry { mode = "Charging"; }
                do { send ControlCommand{commandType = "Lift"} to hoistControl; }
                on commandInput.command[commandType == "Standby"] then Standby;
                on commandInput.command[commandType == "Discharge"] then Discharging;
                on monitoredHeight == safeHeightMax then Standby;
            }
            
            state Discharging {
                entry { mode = "Discharging"; }
                do { send ControlCommand{commandType = "Lower"} to hoistControl; }
                on commandInput.command[commandType == "Standby"] then Standby;
                on commandInput.command[commandType == "Charge"] then Charging;
                on monitoredHeight == safeHeightMin then Standby;
            }
        }
        
        port behavior stateMachine : ControllerStateMachine;
        
        action def MonitorHeight {
            in heightSignal : HeightValue;
            out statusUpdate : StatusReport;
        }
        
        action def ComputeEfficiency {
            in energyIn : EnergyValue;
            in energyOut : EnergyValue;
            out efficiency : EfficiencyValue;
        }
    }

    part def GridInterface {
        attribute gridVoltage : VoltageValue = 33000 [V];
        attribute gridFrequency : FrequencyValue = 50.0;
        attribute maxImportPower : PowerValue = 5.0 [MW];
        attribute maxExportPower : PowerValue = 5.0 [MW];
        
        port gridConnection : ElectricalPort;
        
        action def ImportPower {
            in amount : PowerValue;
        }
        action def ExportPower {
            in amount : PowerValue;
        }
    }

    // ---- Top-level System ----
    part def GravitationalEnergyStorageSystem {
        attribute maxLiftHeight : HeightValue = 120 [m];
        attribute dischargePower : PowerValue = 4.5 [MW];
        attribute roundTripEfficiency : EfficiencyValue = 0.78;
        attribute chargePower : PowerValue = 4.8 [MW];
        
        port gridPort : ElectricalPort;
        port externalCommand : CommandPort;
        port systemStatus : StatusPort;
        
        part massBlock : MassBlock {
            attribute mass = 500000 [kg];
        }
        
        part hoistingMechanism : HoistingMechanism;
        part generator : Generator;
        part powerConverter : PowerConverter;
        part controller : SystemController;
        part gridInterface : GridInterface;
        
        // Connections
        connection hoistToMass connect hoistingMechanism.mechanicalOutput to massBlock.motionPort;
        connection massToGenerator connect massBlock.motionPort to generator.mechanicalInput;
        connection generatorToConverter connect generator.electricalOutput to powerConverter.generatorInput;
        connection converterToGrid connect powerConverter.gridOutput to gridInterface.gridConnection;
        connection gridToSystem connect gridInterface.gridConnection to gridPort;
        
        connection controllerToHoist connect controller.hoistControl to hoistingMechanism.controlInput;
        connection controllerToConverter connect controller.converterControl to powerConverter.controlInput;
        connection externalCommandToController connect externalCommand to controller.commandInput;
        connection controllerStatus connect controller.statusOutput to systemStatus;
        
        // Requirements satisfaction
        satisfy StorageCapacityRequirement {
            subject storageSystem :>> self;
        }
        satisfy PowerDeliveryRequirement {
            subject storageSystem :>> self;
        }
        satisfy EfficiencyRequirement {
            subject storageSystem :>> self;
        }
        satisfy SafetyRequirement {
            subject storageSystem :>> self;
        }
        
        // System-level state machine
        state def SystemOperationStateMachine {
            entry; then Idle;
            
            state Idle {
                entry { /* System ready, no active operation */ }
                on externalCommand.command[commandType == "Charge"] then ChargingMode;
                on externalCommand.command[commandType == "Discharge"] then DischargingMode;
            }
            
            state ChargingMode {
                entry { /* Lifting mass block to store energy */ }
                do { hoistingMechanism.Hoist(maxLiftHeight); }
                on massBlock.currentHeight == maxLiftHeight then Idle;
                on externalCommand.command[commandType == "Standby"] then Idle;
            }
            
            state DischargingMode {
                entry { /* Lowering mass block to generate power */ }
                do { generator.Generate(massBlock.motionPort.velocity); }
                on massBlock.currentHeight == massBlock.minHeight then Idle;
                on externalCommand.command[commandType == "Standby"] then Idle;
            }
            
            state EmergencyStop {
                entry { hoistingMechanism.Brake(); }
            }
        }
        
        port behavior systemState : SystemOperationStateMachine;
    }

    // ---- Item Flow Definitions ----
    flow def EnergyFlow {
        end : ElectricalPort;
        end : ElectricalPort;
        item : ElectricalEnergy;
    }

    flow def MechanicalFlow {
        end : LinearMotionPort;
        end : LinearMotionPort;
        item : MechanicalEnergy;
    }

}
