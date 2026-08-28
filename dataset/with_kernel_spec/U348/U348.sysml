package PatientLiftSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def SigRaise;
    attribute def SigLower;
    attribute def SigStop;
    attribute def SigEmergencyStop;
    attribute def SigLockElevated;
    attribute def SigReleaseLock;
    
    enum def ActuatorCommandKind {
        enum raise;
        enum lower;
        enum stop;
    }
    
    part def CasterWheel {
        attribute hasBrake : Boolean;
    }
    
    part def BaseFrame {
        part frontCasters[2] : CasterWheel;
        part rearCasters[2] : CasterWheel;
    }
    
    part def Mast {
        attribute height : LengthValue;
    }
    
    part def ElectricActuator {
        port commandPort {
            in attribute command : ActuatorCommandKind;
        }
        port powerPort;
        perform action actuate {
            in attribute command : ActuatorCommandKind;
        }
    }
    
    part def LiftingArm {
        part actuator : ElectricActuator;
        port slingAttachmentPort;
    }
    
    part def PendantControl {
        port commandPort {
            out attribute raiseCmd : SigRaise;
            out attribute lowerCmd : SigLower;
            out attribute stopCmd : SigStop;
        }
    }
    
    part def ControlModule {
        port pendantPort {
            in attribute raiseCmd : SigRaise;
            in attribute lowerCmd : SigLower;
            in attribute stopCmd : SigStop;
        }
        port loadCellPort {
            in attribute weight : MassValue;
        }
        port heightSensorPort {
            in attribute height : LengthValue;
        }
        port emergencyStopPort {
            in attribute estopCmd : SigEmergencyStop;
        }
        port actuatorPort {
            out attribute command : ActuatorCommandKind;
        }
        port powerPort;
        
        attribute maxLoad : MassValue = 200 [kg];
        attribute maxHeight : LengthValue = 2 [m];
        attribute actuatorCommand : ActuatorCommandKind;
        
        state controlStates {
            entry; then standby;
            state standby;
            accept SigRaise then raising;
            accept SigLower then lowering;
            accept SigEmergencyStop then standby;
            
            state raising;
            accept SigStop then standby;
            accept SigEmergencyStop then standby;
            accept SigLockElevated then lockedElevated;
            
            state lowering;
            accept SigStop then standby;
            accept SigEmergencyStop then standby;
            
            state lockedElevated;
            accept SigReleaseLock then standby;
            accept SigEmergencyStop then standby;
        }
    }
    
    part def PatientSling {
        attribute material : String = "Polyester Mesh";
        attribute type : String = "Full-Body";
        port attachPort;
    }
    
    part def Battery {
        port powerPort;
        attribute capacity : ElectricChargeValue = 10 [A*h];
        attribute chargeLevel : Real = 1.0;
    }
    
    part def LoadCell {
        attribute weight : MassValue;
        port weightPort {
            out attribute weight : MassValue;
        }
        perform action measureWeight {
            out attribute weight : MassValue;
        }
    }
    
    part def HeightSensor {
        attribute height : LengthValue;
        port heightPort {
            out attribute height : LengthValue;
        }
        perform action measureHeight {
            out attribute height : LengthValue;
        }
    }
    
    part def EmergencyStopButton {
        attribute estopActive : Boolean;
        port estopPort {
            out attribute estopCmd : SigEmergencyStop;
        }
    }
    
    part def PatientLift {
        part baseFrame : BaseFrame {
            part redefines frontCasters {
                :>> hasBrake = false;
            }
            part redefines rearCasters {
                :>> hasBrake = true;
            }
        }
        part mast : Mast;
        part liftingArm : LiftingArm;
        part pendantControl : PendantControl;
        part controlModule : ControlModule;
        part patientSling : PatientSling;
        part battery : Battery;
        part loadCell : LoadCell;
        part heightSensor : HeightSensor;
        part emergencyStopButton : EmergencyStopButton;
        
        connect pendantControl.commandPort to controlModule.pendantPort;
        connect loadCell.weightPort to controlModule.loadCellPort;
        connect heightSensor.heightPort to controlModule.heightSensorPort;
        connect emergencyStopButton.estopPort to controlModule.emergencyStopPort;
        connect controlModule.actuatorPort to liftingArm.actuator.commandPort;
        connect battery.powerPort to controlModule.powerPort;
        connect battery.powerPort to liftingArm.actuator.powerPort;
        connect patientSling.attachPort to liftingArm.slingAttachmentPort;
    }
    
    part patientLift : PatientLift;
    
    requirement def SafeTransferRequirement {
        doc /*
         * The patient lift must safely transfer individuals with limited mobility
         * without exceeding the maximum load capacity.
         */
        subject lift : PatientLift;
        assert lift.loadCell.weight <= lift.controlModule.maxLoad;
    }
    
    requirement def EmergencyStopRequirement {
        doc /*
         * The emergency stop button must immediately halt all movement.
         */
        subject lift : PatientLift;
        assert lift.emergencyStopButton.estopActive implies lift.controlModule.actuatorCommand == ActuatorCommandKind::stop;
    }
}
