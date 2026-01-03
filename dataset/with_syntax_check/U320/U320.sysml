package NanoneedleSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def VoltageCommand;
    attribute def PressureCommand;
    attribute def PositionCommand;
    
    value def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    item def BiologicalCell {
        attribute diameter : LengthValue;
        attribute membraneThickness : LengthValue;
        attribute viability : Real;
    }
    
    item def TherapeuticPayload {
        attribute moleculeType : String;
        attribute concentration : Real;
        attribute volume : VolumeValue;
    }
    
    port def FluidPort {
        in flowCommand : PressureCommand;
        out flowRate : VolumeFlowRateValue;
    }
    
    port def MotionPort {
        in positionCommand : PositionCommand;
        out currentPosition : Position3D;
    }
    
    port def SensingPort {
        out impedance : ResistanceValue;
        out force : ForceValue;
    }
    
    port def ControlPort {
        in voltageCommand : VoltageCommand;
        out status : String;
    }
    
    part def NanoneedleTip {
        attribute tipDiameter : LengthValue;
        attribute length : LengthValue;
        attribute material : String;
        port sensing : SensingPort;
    }
    
    part def PiezoelectricPositioner {
        attribute resolution : LengthValue;
        attribute maxTravel : LengthValue;
        port motion : MotionPort;
        port control : ControlPort;
    }
    
    part def MicrofluidicInjector {
        attribute maxPressure : PressureValue;
        attribute minVolume : VolumeValue;
        port fluid : FluidPort;
    }
    
    part def ImagingSystem {
        attribute magnification : Real;
        attribute resolution : LengthValue;
    }
    
    part def FeedbackController {
        attribute controlGain : Real;
        attribute samplingRate : FrequencyValue;
        port sensorInput : SensingPort;
        port actuatorOutput : ControlPort;
    }
    
    action def LocateCell {
        out targetPosition : Position3D;
        out cellIdentified : BiologicalCell;
    }
    
    action def ApproachCell {
        in targetPosition : Position3D;
        in approachSpeed : SpeedValue;
        out finalPosition : Position3D;
    }
    
    action def DetectContact {
        in impedanceThreshold : ResistanceValue;
        out contactDetected : Boolean;
        out contactForce : ForceValue;
    }
    
    action def PenetrateCell {
        in penetrationDepth : LengthValue;
        in penetrationRate : SpeedValue;
        out penetrationComplete : Boolean;
    }
    
    action def InjectPayload {
        in payload : TherapeuticPayload;
        in injectionPressure : PressureValue;
        out volumeDelivered : VolumeValue;
    }
    
    action def WithdrawNeedle {
        in withdrawalSpeed : SpeedValue;
        out needleRetracted : Boolean;
    }
    
    action def PerformCellularDelivery {
        in therapeuticPayload : TherapeuticPayload;
        in targetCell : BiologicalCell;
        out deliverySuccess : Boolean;
        
        first start;
        
        then action locate : LocateCell {
            out targetPosition : Position3D;
            out cellIdentified : BiologicalCell;
        }
        
        then action approach : ApproachCell {
            in targetPosition = locate.targetPosition;
            in approachSpeed : SpeedValue;
            out finalPosition : Position3D;
        }
        
        then action detectContact : DetectContact {
            in impedanceThreshold : ResistanceValue;
            out contactDetected : Boolean;
            out contactForce : ForceValue;
        }
        
        then decide;
            if detectContact.contactDetected then penetrate;
            if not detectContact.contactDetected then abortSequence;
        
        action penetrate : PenetrateCell {
            in penetrationDepth : LengthValue;
            in penetrationRate : SpeedValue;
            out penetrationComplete : Boolean;
        }
        
        then action inject : InjectPayload {
            in payload = therapeuticPayload;
            in injectionPressure : PressureValue;
            out volumeDelivered : VolumeValue;
        }
        
        then action withdraw : WithdrawNeedle {
            in withdrawalSpeed : SpeedValue;
            out needleRetracted : Boolean;
        }
        
        then assign deliverySuccess := withdraw.needleRetracted;
        then done;
        
        action abortSequence {
            then assign deliverySuccess := false;
        }
        then done;
    }
    
    part def NanoneedleDeliverySystem {
        
        perform action delivery[*] ordered references PerformCellularDelivery;
        
        part needle : NanoneedleTip {
            attribute tipDiameter : LengthValue;
            attribute length : LengthValue;
            attribute material : String;
            perform delivery.detectContact;
        }
        
        part positioner : PiezoelectricPositioner {
            attribute resolution : LengthValue;
            attribute maxTravel : LengthValue;
            perform delivery.approach;
            perform delivery.penetrate;
            perform delivery.withdraw;
        }
        
        part injector : MicrofluidicInjector {
            attribute maxPressure : PressureValue;
            attribute minVolume : VolumeValue;
            perform delivery.inject;
        }
        
        part imaging : ImagingSystem {
            attribute magnification : Real;
            attribute resolution : LengthValue;
            perform delivery.locate;
        }
        
        part controller : FeedbackController {
            attribute controlGain : Real;
            attribute samplingRate : FrequencyValue;
        }
        
        connection needleSensing connect needle.sensing to controller.sensorInput;
        connection positionerControl connect controller.actuatorOutput to positioner.control;
    }
    
    requirement def SystemGoal;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'NNS-R-001'> primaryFunction : SystemGoal {
        doc /* The Nanoneedle Delivery System shall deliver therapeutic payloads 
               into individual biological cells with nanometer-scale precision 
               while maintaining cell viability. */
        subject nanoneedleSystem : NanoneedleDeliverySystem;
    }
    
    requirement <'NNS-R-002'> deliveryPrecision : PerformanceRequirement {
        doc /* The system shall position the nanoneedle tip with accuracy 
               better than 100 nm in all three spatial dimensions. */
        refines primaryFunction;
    }
    
    requirement <'NNS-R-003'> cellViability : SafetyRequirement {
        doc /* Cell viability shall remain above 85% following payload delivery 
               to ensure minimal invasiveness of the procedure. */
        refines primaryFunction;
    }
    
    requirement <'NNS-R-004'> needleDimension : PerformanceRequirement {
        doc /* The nanoneedle tip diameter shall be less than 100 nm to enable 
               membrane penetration with minimal mechanical disruption. */
        refines primaryFunction;
    }
    
    requirement <'NNS-R-005'> deliveryVolume : PerformanceRequirement {
        doc /* The system shall deliver payload volumes in the range of 
               1 to 1000 picoliters with 5% accuracy. */
        refines primaryFunction;
    }
    
    part nanoneedleSystem : NanoneedleDeliverySystem;
}
