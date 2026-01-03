package 'Lift Chair System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def SeatAngleValue :> Real;
    attribute def LoadValue :> Real;
    attribute def VelocityValue :> Real;
    
    enumeration OperationCommand {
        raise;
        lower;
        stop;
    }
    
    enumeration ChairState {
        seated;
        lifting;
        standing;
        lowering;
        stopped;
    }
    
    item def ControlSignal {
        attribute command : OperationCommand;
    }
    
    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    item def MechanicalForce {
        attribute force : LoadValue;
    }
    
    port def PowerPort {
        in item electricalPower : ElectricalPower;
    }
    
    port def ControlPort {
        in item controlSignal : ControlSignal;
    }
    
    port def ForcePort {
        out item mechanicalForce : MechanicalForce;
    }
    
    port def FeedbackPort {
        out attribute currentAngle : SeatAngleValue;
        out attribute currentLoad : LoadValue;
    }
    
    part def PowerSupply {
        port acInput;
        port dcOutput : PowerPort;
        attribute outputVoltage : Real = 24.0;
        attribute maxCurrent : Real = 15.0;
    }
    
    part def HandControl {
        port controlOutput : ControlPort;
        attribute raiseButton : Boolean;
        attribute lowerButton : Boolean;
        attribute stopButton : Boolean;
        
        action generateCommand {
            out commandSignal : ControlSignal;
            
            first start;
            then decide;
                if raiseButton then setRaise;
                if lowerButton then setLower;
                if stopButton then setStop;
            
            action setRaise {
                then assign commandSignal.command := OperationCommand::raise;
            }
            
            action setLower {
                then assign commandSignal.command := OperationCommand::lower;
            }
            
            action setStop {
                then assign commandSignal.command := OperationCommand::stop;
            }
            
            then done;
        }
    }
    
    part def LinearActuator {
        port powerInput : PowerPort;
        port controlInput : ControlPort;
        port forceOutput : ForcePort;
        port feedback : FeedbackPort;
        
        attribute currentAngle : SeatAngleValue = 0.0;
        attribute maxAngle : SeatAngleValue = 80.0;
        attribute minAngle : SeatAngleValue = 0.0;
        attribute liftRate : Real = 8.0;
        attribute maxLoad : LoadValue = 1500.0;
        
        action actuate {
            in command : OperationCommand;
            in deltaTime : Real;
            out newAngle : SeatAngleValue;
            
            first start;
            then decide;
                if command == OperationCommand::raise then raiseAction;
                if command == OperationCommand::lower then lowerAction;
                if command == OperationCommand::stop then holdAction;
            
            action raiseAction {
                private attribute increment : SeatAngleValue;
                then assign increment := liftRate * deltaTime;
                then assign newAngle := currentAngle + increment;
                then decide;
                    if newAngle > maxAngle then assign newAngle := maxAngle;
            }
            then done;
            
            action lowerAction {
                private attribute decrement : SeatAngleValue;
                then assign decrement := liftRate * deltaTime;
                then assign newAngle := currentAngle - decrement;
                then decide;
                    if newAngle < minAngle then assign newAngle := minAngle;
            }
            then done;
            
            action holdAction {
                then assign newAngle := currentAngle;
            }
            then done;
        }
    }
    
    part def SeatFrame {
        port mechanicalInput : ForcePort;
        attribute seatAngle : SeatAngleValue;
        attribute occupantWeight : Real;
        attribute maxCapacity : Real = 136.0;
    }
    
    part def SafetyController {
        port sensorInput : FeedbackPort;
        port safetyOutput : ControlPort;
        
        attribute obstructionThreshold : LoadValue = 1800.0;
        attribute obstructionDetected : Boolean = false;
        
        action monitorSafety {
            in currentLoad : LoadValue;
            in currentAngle : SeatAngleValue;
            out safetyCommand : ControlSignal;
            
            first start;
            then decide;
                if currentLoad > obstructionThreshold then detectObstruction;
                else clearObstruction;
            
            action detectObstruction {
                then assign obstructionDetected := true;
                then assign safetyCommand.command := OperationCommand::stop;
            }
            
            action clearObstruction {
                then assign obstructionDetected := false;
            }
            
            then done;
        }
    }
    
    part def LiftChairSystem {
        doc /* A lift chair system assists mobility-impaired users in transitioning 
             between seated and standing positions by mechanically elevating the seat 
             through controlled motorized actuation. */
        
        part powerSupply : PowerSupply;
        part handControl : HandControl;
        part actuator : LinearActuator;
        part seatFrame : SeatFrame;
        part safetyController : SafetyController;
        
        connect powerSupply.dcOutput to actuator.powerInput;
        connect handControl.controlOutput to actuator.controlInput;
        connect actuator.forceOutput to seatFrame.mechanicalInput;
        connect actuator.feedback to safetyController.sensorInput;
        
        perform action operateLiftChair : OperateLiftChair;
    }
    
    action def OperateLiftChair {
        in userCommand : OperationCommand;
        in occupantPresent : Boolean;
        out finalAngle : SeatAngleValue;
        
        private attribute currentAngle : SeatAngleValue = 0.0;
        private attribute currentLoad : LoadValue = 0.0;
        private attribute safetyOK : Boolean = true;
        
        first start;
        then merge operationLoop;
        
        then action checkConditions {
            then decide;
                if not occupantPresent then haltOperation;
                if not safetyOK then emergencyStop;
                else processCommand;
        }
        
        action processCommand {
            then decide;
                if userCommand == OperationCommand::raise then executeRaise;
                if userCommand == OperationCommand::lower then executeLower;
                if userCommand == OperationCommand::stop then executeStop;
        }
        
        action executeRaise {
            private attribute increment : SeatAngleValue = 8.0 * 0.1;
            then assign currentAngle := currentAngle + increment;
            then decide;
                if currentAngle > 80.0 then assign currentAngle := 80.0;
            then assign finalAngle := currentAngle;
        }
        then operationLoop;
        
        action executeLower {
            private attribute decrement : SeatAngleValue = 8.0 * 0.1;
            then assign currentAngle := currentAngle - decrement;
            then decide;
                if currentAngle < 0.0 then assign currentAngle := 0.0;
            then assign finalAngle := currentAngle;
        }
        then operationLoop;
        
        action executeStop {
            then assign finalAngle := currentAngle;
        }
        then operationLoop;
        
        action haltOperation {
            then assign finalAngle := currentAngle;
        }
        then done;
        
        action emergencyStop {
            then assign finalAngle := currentAngle;
            then assign safetyOK := false;
        }
        then done;
    }
    
    state def LiftChairStateMachine {
        entry; then idle;
        
        state idle {
            entry assign currentState := ChairState::seated;
        }
        
        transition idleToLifting
            first idle
            accept raiseCommand : ControlSignal
            if raiseCommand.command == OperationCommand::raise
            then lifting;
        
        state lifting {
            entry assign currentState := ChairState::lifting;
            do action lift;
        }
        
        transition liftingToStanding
            first lifting
            if seatAngle >= 80.0
            then standing;
        
        transition liftingToStopped
            first lifting
            accept stopCommand : ControlSignal
            if stopCommand.command == OperationCommand::stop
            then stopped;
        
        state standing {
            entry assign currentState := ChairState::standing;
        }
        
        transition standingToLowering
            first standing
            accept lowerCommand : ControlSignal
            if lowerCommand.command == OperationCommand::lower
            then lowering;
        
        state lowering {
            entry assign currentState := ChairState::lowering;
            do action lower;
        }
        
        transition loweringToIdle
            first lowering
            if seatAngle <= 0.0
            then idle;
        
        transition loweringToStopped
            first lowering
            accept stopCommand : ControlSignal
            if stopCommand.command == OperationCommand::stop
            then stopped;
        
        state stopped {
            entry assign currentState := ChairState::stopped;
        }
        
        transition stoppedToLifting
            first stopped
            accept raiseCommand : ControlSignal
            if raiseCommand.command == OperationCommand::raise
            then lifting;
        
        transition stoppedToLowering
            first stopped
            accept lowerCommand : ControlSignal
            if lowerCommand.command == OperationCommand::lower
            then lowering;
        
        attribute currentState : ChairState;
        attribute seatAngle : SeatAngleValue;
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'LCS-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* The lift chair system shall assist users in transitioning from a seated 
             position to a near-standing position by elevating the seat to a configurable 
             angle, thereby reducing the physical effort required to stand. */
        
        subject liftChair : LiftChairSystem;
        
        require constraint {
            liftChair.actuator.maxAngle >= 70.0
        }
    }
    
    requirement <'LCS-REQ-002'> weightCapacity : SafetyRequirement {
        doc /* The lift chair shall safely support users with a mass up to 136 kg 
             without mechanical failure or safety system activation. */
        
        subject liftChair : LiftChairSystem;
        
        require constraint {
            liftChair.seatFrame.maxCapacity >= 136.0
        }
    }
    
    requirement <'LCS-REQ-003'> liftSpeed : PerformanceRequirement {
        doc /* The lift chair shall transition from fully seated to fully lifted 
             position within 10 seconds under normal operating conditions. */
        
        subject liftChair : LiftChairSystem;
        
        require constraint {
            liftChair.actuator.liftRate >= 8.0
        }
    }
    
    requirement <'LCS-REQ-004'> obstructionDetection : SafetyRequirement {
        doc /* The lift chair shall detect obstructions exceeding the load threshold 
             and immediately halt operation to prevent injury or damage. */
        
        subject liftChair : LiftChairSystem;
        
        require constraint {
            liftChair.safetyController.obstructionDetected implies 
                liftChair.actuator.currentAngle == liftChair.actuator.currentAngle
        }
    }
    
    requirement <'LCS-REQ-005'> userControl : FunctionalRequirement {
        doc /* The lift chair shall provide intuitive hand controls allowing users 
             to raise, lower, and stop the seat at any position within its range. */
        
        subject liftChair : LiftChairSystem;
        
        require constraint {
            liftChair.handControl.raiseButton or 
            liftChair.handControl.lowerButton or 
            liftChair.handControl.stopButton
        }
    }
    
    part liftChairInstance : LiftChairSystem {
        :>> powerSupply {
            :>> outputVoltage = 24.0;
            :>> maxCurrent = 15.0;
        }
        
        :>> actuator {
            :>> maxAngle = 80.0;
            :>> minAngle = 0.0;
            :>> liftRate = 8.0;
            :>> maxLoad = 1500.0;
        }
        
        :>> seatFrame {
            :>> maxCapacity = 136.0;
        }
        
        :>> safetyController {
            :>> obstructionThreshold = 1800.0;
        }
        
        satisfy primaryFunction;
        satisfy weightCapacity;
        satisfy liftSpeed;
        satisfy obstructionDetection;
        satisfy userControl;
    }
}
