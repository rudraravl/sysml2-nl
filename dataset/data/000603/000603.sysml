package 'Examination Table System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TableHeight :> LengthValue;
    attribute def TableAngle :> PlaneAngleValue;
    attribute def PatientMass :> MassValue;
    attribute def MotorVoltage :> ElectricPotentialValue;
    attribute def MotorCurrent :> ElectricCurrentValue;
    attribute def ActuatorForce :> ForceValue;
    
    enum def PositionPreset {
        flat;
        seated;
        trendelenburg;
        reverseTrendelenburg;
    }
    
    enum def SystemState {
        idle;
        adjusting;
        locked;
        emergency;
    }
    
    item def PositionCommand {
        attribute targetHeight : TableHeight;
        attribute targetAngle : TableAngle;
        attribute preset : PositionPreset;
    }
    
    item def SafetyAlert {
        attribute overload : Boolean;
        attribute mechanicalFailure : Boolean;
    }
    
    port def PowerPort {
        attribute voltage : MotorVoltage;
        attribute current : MotorCurrent;
    }
    
    port def ControlPort {
        in positionCmd : PositionCommand;
        out currentHeight : TableHeight;
        out currentAngle : TableAngle;
    }
    
    port def SensorPort {
        out measuredLoad : PatientMass;
        out heightFeedback : TableHeight;
        out angleFeedback : TableAngle;
    }
    
    port def SafetyPort {
        out alert : SafetyAlert;
        in emergencyStop : Boolean;
    }
    
    part def TableSurface {
        attribute length : LengthValue = 2000.0 [SI::mm];
        attribute width : LengthValue = 800.0 [SI::mm];
        attribute maxLoad : PatientMass = 250.0 [SI::kg];
        attribute padding : LengthValue = 50.0 [SI::mm];
    }
    
    part def HeightActuator {
        attribute minHeight : TableHeight = 500.0 [SI::mm];
        attribute maxHeight : TableHeight = 1000.0 [SI::mm];
        attribute currentHeight : TableHeight = 700.0 [SI::mm];
        attribute liftForce : ActuatorForce = 3000.0 [SI::N];
        attribute speed : SpeedValue = 50.0 [SI::mm]/[SI::s];
        port power : PowerPort;
        port control : ControlPort;
    }
    
    part def TiltActuator {
        attribute minAngle : TableAngle = -30.0 [SI::'°'];
        attribute maxAngle : TableAngle = 85.0 [SI::'°'];
        attribute currentAngle : TableAngle = 0.0 [SI::'°'];
        attribute torque : TorqueValue = 500.0 [SI::'N·m'];
        attribute angularSpeed : AngularVelocityValue = 5.0 [SI::'°']/[SI::s];
        port power : PowerPort;
        port control : ControlPort;
    }
    
    part def LoadCell {
        attribute sensitivity : Real = 0.1;
        attribute maxCapacity : PatientMass = 300.0 [SI::kg];
        attribute measuredWeight : PatientMass;
        port sensor : SensorPort;
    }
    
    part def PositionSensor {
        attribute heightAccuracy : LengthValue = 1.0 [SI::mm];
        attribute angleAccuracy : PlaneAngleValue = 0.5 [SI::'°'];
        port sensor : SensorPort;
    }
    
    part def SafetyController {
        attribute overloadThreshold : PatientMass = 250.0 [SI::kg];
        attribute emergencyStopActive : Boolean = false;
        attribute motionEnabled : Boolean = true;
        port safetyIn : SensorPort;
        port safetyOut : SafetyPort;
    }
    
    part def MotionController {
        attribute heightSetpoint : TableHeight = 700.0 [SI::mm];
        attribute angleSetpoint : TableAngle = 0.0 [SI::'°'];
        attribute positionTolerance : LengthValue = 2.0 [SI::mm];
        attribute angleTolerance : PlaneAngleValue = 1.0 [SI::'°'];
        port controlIn : ControlPort;
        port sensorIn : SensorPort;
        port actuatorOut : ControlPort;
        port safetyLink : SafetyPort;
    }
    
    part def OperatorPanel {
        attribute selectedPreset : PositionPreset;
        attribute manualHeightCmd : TableHeight;
        attribute manualAngleCmd : TableAngle;
        port commandOut : ControlPort;
    }
    
    part def PowerSupply {
        attribute inputVoltage : MotorVoltage = 230.0 [SI::V];
        attribute outputVoltage : MotorVoltage = 24.0 [SI::V];
        attribute maxCurrent : MotorCurrent = 20.0 [SI::A];
        port powerOut : PowerPort;
    }
    
    action def MonitorPatientLoad {
        in currentLoad : PatientMass;
        in maxLoad : PatientMass;
        out safeToOperate : Boolean;
        out overloadDetected : Boolean;
    }
    
    action def AdjustTableHeight {
        in targetHeight : TableHeight;
        in currentHeight : TableHeight;
        in safetyStatus : Boolean;
        out commandedHeight : TableHeight;
        out heightReached : Boolean;
    }
    
    action def AdjustTableAngle {
        in targetAngle : TableAngle;
        in currentAngle : TableAngle;
        in safetyStatus : Boolean;
        out commandedAngle : TableAngle;
        out angleReached : Boolean;
    }
    
    action def ApplyPositionPreset {
        in preset : PositionPreset;
        out targetHeight : TableHeight;
        out targetAngle : TableAngle;
    }
    
    state def TableOperationStateMachine {
        entry; then idle;
        
        state idle;
        
        state checkingSafety {
            do action checkLoad : MonitorPatientLoad;
        }
        
        state adjustingPosition {
            parallel state heightAndTiltAdjustment {
                state adjustingHeight {
                    do action adjustHeight : AdjustTableHeight;
                }
                state adjustingTilt {
                    do action adjustTilt : AdjustTableAngle;
                }
            }
        }
        
        state positionLocked;
        
        state emergencyStop;
        
        transition idle_to_checkingSafety
            first idle
            accept commandReceived : PositionCommand
            then checkingSafety;
        
        transition checkingSafety_to_adjusting
            first checkingSafety
            if checkLoad.safeToOperate
            then adjustingPosition;
        
        transition checkingSafety_to_emergency
            first checkingSafety
            if checkLoad.overloadDetected
            then emergencyStop;
        
        transition adjusting_to_locked
            first adjustingPosition
            if adjustHeight.heightReached and adjustTilt.angleReached
            then positionLocked;
        
        transition locked_to_idle
            first positionLocked
            accept unlockCommand
            then idle;
        
        transition any_to_emergency
            first idle, checkingSafety, adjustingPosition, positionLocked
            accept emergencyStopSignal
            then emergencyStop;
        
        transition emergency_to_idle
            first emergencyStop
            accept resetCommand
            then idle;
    }
    
    part def ExaminationTable {
        doc /* 
            An examination table is a medical device that provides an adjustable platform 
            for positioning patients during clinical examinations and medical procedures. 
            Its primary function is to enable healthcare providers to safely and ergonomically 
            position patients by adjusting the table height and tilt angle, while continuously 
            monitoring patient weight to ensure safe operation within specified load limits.
            
            The system integrates motorized actuators for height and tilt adjustment, load 
            sensing for patient safety, and automated control logic to achieve preset positions 
            or respond to manual commands. Safety interlocks prevent operation when patient 
            weight exceeds capacity or when emergency conditions are detected.
        */
        
        part surface : TableSurface;
        part heightActuator : HeightActuator;
        part tiltActuator : TiltActuator;
        part loadCell : LoadCell;
        part positionSensor : PositionSensor;
        part safetyController : SafetyController;
        part motionController : MotionController;
        part operatorPanel : OperatorPanel;
        part powerSupply : PowerSupply;
        
        connect powerSupply.powerOut to heightActuator.power;
        connect powerSupply.powerOut to tiltActuator.power;
        connect operatorPanel.commandOut to motionController.controlIn;
        connect loadCell.sensor to safetyController.safetyIn;
        connect positionSensor.sensor to motionController.sensorIn;
        connect safetyController.safetyOut to motionController.safetyLink;
        connect motionController.actuatorOut to heightActuator.control;
        connect motionController.actuatorOut to tiltActuator.control;
        
        perform action operateTable : OperateExaminationTable;
    }
    
    action def OperateExaminationTable {
        in commandedPreset : PositionPreset;
        in patientWeight : PatientMass;
        out positioningComplete : Boolean;
        out systemSafe : Boolean;
        
        first start;
        then merge continuousOperation;
        
        action continuousOperation {
            first action monitorLoad : MonitorPatientLoad {
                in currentLoad = operateTable::patientWeight;
                in maxLoad = 250.0 [SI::kg];
                out safeToOperate;
                out overloadDetected;
            }
            
            then decide;
                if monitorLoad.overloadDetected then emergencyShutdown;
                if monitorLoad.safeToOperate then processCommand;
            
            action processCommand {
                first action applyPreset : ApplyPositionPreset {
                    in preset = operateTable::commandedPreset;
                    out targetHeight;
                    out targetAngle;
                }
                
                then parallel adjustments {
                    action adjustHeight : AdjustTableHeight {
                        in targetHeight = applyPreset.targetHeight;
                        in currentHeight = 700.0 [SI::mm];
                        in safetyStatus = monitorLoad.safeToOperate;
                        out commandedHeight;
                        out heightReached;
                    }
                    
                    action adjustAngle : AdjustTableAngle {
                        in targetAngle = applyPreset.targetAngle;
                        in currentAngle = 0.0 [SI::'°'];
                        in safetyStatus = monitorLoad.safeToOperate;
                        out commandedAngle;
                        out angleReached;
                    }
                }
                
                then assign positioningComplete := 
                    adjustments.adjustHeight.heightReached and 
                    adjustments.adjustAngle.angleReached;
            }
            
            then continuousOperation;
            
            action emergencyShutdown {
                assign systemSafe := false;
                assign positioningComplete := false;
            }
            then done;
        }
    }
    
    requirement def FunctionalRequirement {
        doc /* The examination table shall provide motorized height and tilt adjustment 
                to position patients for clinical examination and procedures. */
        subject table : ExaminationTable;
    }
    
    requirement def HeightRangeRequirement {
        doc /* The examination table shall adjust height from 500mm to 1000mm 
                to accommodate various clinical workflows and user ergonomics. */
        subject actuator : HeightActuator;
        require constraint {
            actuator.currentHeight >= actuator.minHeight and
            actuator.currentHeight <= actuator.maxHeight
        }
    }
    
    requirement def TiltRangeRequirement {
        doc /* The examination table shall provide tilt adjustment from -30 degrees 
                to +85 degrees to enable Trendelenburg, reverse Trendelenburg, 
                and seated positioning. */
        subject actuator : TiltActuator;
        require constraint {
            actuator.currentAngle >= actuator.minAngle and
            actuator.currentAngle <= actuator.maxAngle
        }
    }
    
    requirement def LoadCapacityRequirement {
        doc /* The examination table shall safely support patients up to 250kg 
                and prevent operation when this limit is exceeded. */
        subject table : ExaminationTable;
        require constraint {
            table.loadCell.measuredWeight <= table.surface.maxLoad
        }
    }
    
    requirement def SafetyInterlockRequirement {
        doc /* The examination table shall immediately halt all motion and enter 
                emergency stop state when patient weight exceeds capacity or 
                emergency stop is activated. */
        subject controller : SafetyController;
        require constraint {
            controller.emergencyStopActive implies not controller.motionEnabled
        }
    }
    
    requirement def PositionAccuracyRequirement {
        doc /* The examination table shall achieve commanded height within ±2mm 
                and angle within ±1 degree. */
        subject controller : MotionController;
        require constraint {
            controller.positionTolerance <= 2.0 [SI::mm] and
            controller.angleTolerance <= 1.0 [SI::'°']
        }
    }
    
    requirement examinationTableSystemRequirements {
        doc /* Top-level requirements for examination table system encompassing 
                functional capabilities, safety, and performance specifications. */
        
        require functionalReq : FunctionalRequirement;
        require heightReq : HeightRangeRequirement;
        require tiltReq : TiltRangeRequirement;
        require loadReq : LoadCapacityRequirement;
        require safetyReq : SafetyInterlockRequirement;
        require accuracyReq : PositionAccuracyRequirement;
    }
    
    part examinationTableSystem : ExaminationTable {
        :>> surface {
            :>> maxLoad = 250.0 [SI::kg];
        }
        :>> heightActuator {
            :>> minHeight = 500.0 [SI::mm];
            :>> maxHeight = 1000.0 [SI::mm];
        }
        :>> tiltActuator {
            :>> minAngle = -30.0 [SI::'°'];
            :>> maxAngle = 85.0 [SI::'°'];
        }
        :>> safetyController {
            :>> overloadThreshold = 250.0 [SI::kg];
        }
    }
}
