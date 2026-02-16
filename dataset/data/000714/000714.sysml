package OperatingTableSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TablePosition {
        attribute height : LengthValue;
        attribute longitudinalTilt : PlaneAngleValue;
        attribute lateralTilt : PlaneAngleValue;
        attribute trendelenburgAngle : PlaneAngleValue;
    }
    
    attribute def PositionCommand {
        attribute targetHeight : LengthValue;
        attribute targetLongitudinalTilt : PlaneAngleValue;
        attribute targetLateralTilt : PlaneAngleValue;
        attribute targetTrendelenburg : PlaneAngleValue;
    }
    
    attribute def SafetyStatus {
        attribute emergencyStopActive : Boolean;
        attribute lockEngaged : Boolean;
        attribute overloadDetected : Boolean;
        attribute positionLimitsExceeded : Boolean;
    }
    
    port def ControlInterface {
        out positionCommand : PositionCommand;
        in currentPosition : TablePosition;
        in safetyStatus : SafetyStatus;
    }
    
    port def PowerInterface {
        in electricalPower : PowerValue;
        out powerConsumption : PowerValue;
    }
    
    port def HydraulicInterface {
        out hydraulicPressure : PressureValue;
        in flowRate : VolumeFlowRateValue;
    }
    
    port def MechanicalInterface {
        in appliedLoad : ForceValue;
        out supportForce : ForceValue;
    }
    
    part def ControlPanel {
        port controlOut : ~ControlInterface;
        
        attribute userCommand : PositionCommand;
        attribute displayedPosition : TablePosition;
        attribute displayedSafety : SafetyStatus;
    }
    
    part def HydraulicPump {
        port powerIn : PowerInterface;
        port hydraulicOut : HydraulicInterface;
        
        attribute maxPressure : PressureValue;
        attribute nominalFlowRate : VolumeFlowRateValue;
        attribute efficiency : Real;
    }
    
    part def HeightActuator {
        port hydraulicIn : HydraulicInterface;
        port mechanicalOut : MechanicalInterface;
        
        in heightCommand : LengthValue;
        out actualHeight : LengthValue;
        
        attribute maxExtension : LengthValue;
        attribute minExtension : LengthValue;
        attribute actuationSpeed : SpeedValue;
        attribute maxLoad : ForceValue;
    }
    
    part def TiltActuator {
        port hydraulicIn : HydraulicInterface;
        port mechanicalOut : MechanicalInterface;
        
        in tiltCommand : PlaneAngleValue;
        out actualTilt : PlaneAngleValue;
        
        attribute maxTiltAngle : PlaneAngleValue;
        attribute minTiltAngle : PlaneAngleValue;
        attribute rotationSpeed : AngularVelocityValue;
    }
    
    part def TableSurface {
        port mechanicalLoad : MechanicalInterface;
        
        attribute currentPosition : TablePosition;
        attribute patientWeight : MassValue;
        attribute maxLoadCapacity : MassValue;
        attribute surfaceArea : AreaValue;
    }
    
    part def LockingMechanism {
        attribute isLocked : Boolean;
        attribute lockingForce : ForceValue;
        
        action def EngageLock {
            in lockCommand : Boolean;
            out lockStatus : Boolean;
        }
        
        action def ReleaseLock {
            in unlockCommand : Boolean;
            out lockStatus : Boolean;
        }
    }
    
    part def SafetyMonitor {
        in weightSensor : MassValue;
        in positionSensor : TablePosition;
        in emergencyStop : Boolean;
        out safetyStatus : SafetyStatus;
        
        attribute maxSafeWeight : MassValue;
        attribute maxSafeTilt : PlaneAngleValue;
        attribute maxSafeHeight : LengthValue;
        attribute minSafeHeight : LengthValue;
        
        perform action monitorSafety;
    }
    
    part def PositionController {
        in commandedPosition : PositionCommand;
        in currentPosition : TablePosition;
        in safetyStatus : SafetyStatus;
        out heightControl : LengthValue;
        out longitudinalControl : PlaneAngleValue;
        out lateralControl : PlaneAngleValue;
        out trendelenburgControl : PlaneAngleValue;
        
        attribute controlGain : Real;
        attribute positionTolerance : LengthValue;
        attribute angleTolerance : PlaneAngleValue;
        
        perform action controlPosition;
    }
    
    part def OperatingTable {
        part controlPanel : ControlPanel;
        part hydraulicPump : HydraulicPump;
        part heightActuator : HeightActuator;
        part longitudinalTiltActuator : TiltActuator;
        part lateralTiltActuator : TiltActuator;
        part trendelenburgActuator : TiltActuator;
        part tableSurface : TableSurface;
        part lockingMech : LockingMechanism;
        part safetyMonitor : SafetyMonitor;
        part positionController : PositionController;
        
        connection connect controlPanel.controlOut to positionController.commandedPosition;
        connection connect positionController.heightControl to heightActuator.heightCommand;
        connection connect positionController.longitudinalControl to longitudinalTiltActuator.tiltCommand;
        connection connect positionController.lateralControl to lateralTiltActuator.tiltCommand;
        connection connect positionController.trendelenburgControl to trendelenburgActuator.tiltCommand;
        
        connection connect hydraulicPump.hydraulicOut to heightActuator.hydraulicIn;
        connection connect hydraulicPump.hydraulicOut to longitudinalTiltActuator.hydraulicIn;
        connection connect hydraulicPump.hydraulicOut to lateralTiltActuator.hydraulicIn;
        connection connect hydraulicPump.hydraulicOut to trendelenburgActuator.hydraulicIn;
        
        connection connect heightActuator.mechanicalOut to tableSurface.mechanicalLoad;
        connection connect longitudinalTiltActuator.mechanicalOut to tableSurface.mechanicalLoad;
        connection connect lateralTiltActuator.mechanicalOut to tableSurface.mechanicalLoad;
        connection connect trendelenburgActuator.mechanicalOut to tableSurface.mechanicalLoad;
        
        connection connect tableSurface.currentPosition to positionController.currentPosition;
        connection connect tableSurface.currentPosition to safetyMonitor.positionSensor;
        connection connect tableSurface.patientWeight to safetyMonitor.weightSensor;
        connection connect safetyMonitor.safetyStatus to positionController.safetyStatus;
        connection connect safetyMonitor.safetyStatus to controlPanel.controlOut;
        
        perform action positionPatient;
    }
    
    action def CheckSafety {
        in patientWeight : MassValue;
        in tablePosition : TablePosition;
        in maxWeight : MassValue;
        in maxTilt : PlaneAngleValue;
        out isSafe : Boolean;
    }
    
    action def AdjustHeight {
        in targetHeight : LengthValue;
        in currentHeight : LengthValue;
        in tolerance : LengthValue;
        out heightCommand : LengthValue;
        out positionReached : Boolean;
    }
    
    action def AdjustTilt {
        in targetTilt : PlaneAngleValue;
        in currentTilt : PlaneAngleValue;
        in tolerance : PlaneAngleValue;
        out tiltCommand : PlaneAngleValue;
        out positionReached : Boolean;
    }
    
    action def LockPosition {
        in lockCommand : Boolean;
        out lockStatus : Boolean;
    }
    
    action positionPatient {
        first start;
        then merge checkSafetyMerge;
        
        action checkSafetyAction : CheckSafety {
            in patientWeight;
            in tablePosition;
            in maxWeight;
            in maxTilt;
            out isSafe;
        }
        
        then decide;
            if checkSafetyAction.isSafe then unlockAndPosition;
            if not checkSafetyAction.isSafe then emergencyStopAction;
        
        action unlockAndPosition {
            first action releaseLock : LockPosition {
                in lockCommand = false;
                out lockStatus;
            }
            
            then action adjustHeight : AdjustHeight {
                in targetHeight;
                in currentHeight;
                in tolerance;
                out heightCommand;
                out positionReached;
            }
            
            then action adjustLongitudinal : AdjustTilt {
                in targetTilt;
                in currentTilt;
                in tolerance;
                out tiltCommand;
                out positionReached;
            }
            
            then action adjustLateral : AdjustTilt {
                in targetTilt;
                in currentTilt;
                in tolerance;
                out tiltCommand;
                out positionReached;
            }
            
            then action adjustTrendelenburg : AdjustTilt {
                in targetTilt;
                in currentTilt;
                in tolerance;
                out tiltCommand;
                out positionReached;
            }
            
            then decide;
                if adjustHeight.positionReached and adjustLongitudinal.positionReached and 
                   adjustLateral.positionReached and adjustTrendelenburg.positionReached 
                then lockPositionAction;
                if not (adjustHeight.positionReached and adjustLongitudinal.positionReached and 
                     adjustLateral.positionReached and adjustTrendelenburg.positionReached)
                then checkSafetyMerge;
            
            action lockPositionAction : LockPosition {
                in lockCommand = true;
                out lockStatus;
            }
            
            then done;
        }
        
        action emergencyStopAction {
            action activateEmergencyLock : LockPosition {
                in lockCommand = true;
                out lockStatus;
            }
            then done;
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The operating table shall ensure patient safety during all positioning operations 
                by monitoring load limits, position limits, and emergency conditions. */
        
        subject table : OperatingTable;
        
        require constraint weightLimit {
            table.tableSurface.patientWeight <= table.tableSurface.maxLoadCapacity
        }
        
        require constraint heightLimit {
            table.tableSurface.currentPosition.height >= table.safetyMonitor.minSafeHeight and
            table.tableSurface.currentPosition.height <= table.safetyMonitor.maxSafeHeight
        }
        
        require constraint tiltLimit {
            table.tableSurface.currentPosition.longitudinalTilt >= -table.safetyMonitor.maxSafeTilt and
            table.tableSurface.currentPosition.longitudinalTilt <= table.safetyMonitor.maxSafeTilt and
            table.tableSurface.currentPosition.lateralTilt >= -table.safetyMonitor.maxSafeTilt and
            table.tableSurface.currentPosition.lateralTilt <= table.safetyMonitor.maxSafeTilt
        }
        
        require constraint emergencyLock {
            table.safetyMonitor.safetyStatus.emergencyStopActive implies table.lockingMech.isLocked
        }
    }
    
    requirement def PositioningRequirement {
        doc /* The operating table shall provide precise and stable patient positioning 
                with adjustable height and multi-axis tilt capabilities. */
        
        subject table : OperatingTable;
        
        require constraint heightRange {
            doc /* Height adjustment range shall be 650mm to 1100mm from floor level. */
        }
        
        require constraint tiltRange {
            doc /* Tilt range shall be ±30 degrees for longitudinal, ±20 degrees for lateral, 
                    and ±30 degrees for Trendelenburg positioning. */
        }
        
        require constraint positionAccuracy {
            doc /* Positioning accuracy shall be within ±3mm for height and ±0.5 degrees for all tilt axes. */
        }
        
        require constraint stabilityUnderLoad {
            doc /* Table shall remain stable and maintain position under maximum rated load. */
        }
    }
    
    requirement def OperationalRequirement {
        doc /* The operating table shall provide reliable operation with appropriate 
                control interfaces and power management. */
        
        subject table : OperatingTable;
        
        require constraint controlResponse {
            doc /* Position adjustments shall respond to control inputs within 0.5 seconds. */
        }
        
        require constraint powerEfficiency {
            doc /* Hydraulic system shall operate at minimum 85% efficiency under normal load. */
        }
        
        require constraint lockingReliability {
            doc /* Locking mechanism shall engage within 1 second of command and withstand 
                    150% of maximum rated load. */
        }
    }
    
    requirement operatingTableMissionRequirement {
        doc /* The operating table system shall provide safe, precise, and adjustable patient positioning 
                to support surgical procedures by enabling controlled height adjustment and multi-axis tilt 
                positioning while maintaining patient safety through continuous monitoring, automatic locking, 
                and emergency stop capabilities. */
        
        assume constraint powerSupplyAvailable {
            doc /* Stable electrical power supply is available within specified voltage and frequency ranges. */
        }
        
        assume constraint hydraulicFluidMaintained {
            doc /* Hydraulic fluid is maintained at proper level and viscosity. */
        }
        
        require safetyReq : SafetyRequirement;
        require positioningReq : PositioningRequirement;
        require operationalReq : OperationalRequirement;
    }
}
