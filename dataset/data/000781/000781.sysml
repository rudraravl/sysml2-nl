package StretcherSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientCondition;
    attribute def OperationalMode;
    
    item def Patient {
        attribute mass : MassValue;
        attribute condition : PatientCondition;
        attribute isSecured : Boolean;
    }
    
    item def LocationData {
        attribute position : LengthValue;
        attribute floor : Integer;
    }
    
    attribute def HeightValue :> LengthValue;
    
    attribute def AngleValue {
        attribute degrees : Real;
    }
    
    port def PatientSupportPort {
        out patientMass : MassValue;
        in supportActive : Boolean;
    }
    
    port def ControlPort {
        in heightCommand : HeightValue;
        in angleCommand : AngleValue;
        in lockCommand : Boolean;
        out currentHeight : HeightValue;
        out currentAngle : AngleValue;
        out lockStatus : Boolean;
    }
    
    part def Frame {
        attribute maxLoadCapacity : MassValue;
        attribute structuralIntegrity : Real;
        port frameSupport : PatientSupportPort;
    }
    
    part def Mattress {
        attribute thickness : LengthValue;
        attribute compressionRating : Real;
        port mattressSupport : PatientSupportPort;
    }
    
    part def WheelAssembly {
        attribute wheelDiameter : LengthValue;
        attribute isLocked : Boolean;
        
        part wheel[4] {
            attribute rotation : AngleValue;
        }
        
        part brakeMechanism {
            attribute engaged : Boolean;
        }
        
        action lockWheels {
            first start;
            then assign isLocked := true;
            then assign brakeMechanism.engaged := true;
            then done;
        }
        
        action unlockWheels {
            first start;
            then assign isLocked := false;
            then assign brakeMechanism.engaged := false;
            then done;
        }
    }
    
    part def HeightAdjustmentMechanism {
        attribute currentHeight : HeightValue;
        attribute minHeight : HeightValue;
        attribute maxHeight : HeightValue;
        
        part hydraulicActuator {
            attribute extension : LengthValue;
            attribute pressure : Real;
        }
        
        action adjustHeight {
            in targetHeight : HeightValue;
            out newHeight : HeightValue;
            
            first start;
            then decide;
                if targetHeight > currentHeight then raiseHeight;
                if targetHeight < currentHeight then lowerHeight;
                if targetHeight == currentHeight then maintainHeight;
            
            action raiseHeight {
                then assign newHeight := targetHeight;
                then assign currentHeight := newHeight;
            }
            
            action lowerHeight {
                then assign newHeight := targetHeight;
                then assign currentHeight := newHeight;
            }
            
            action maintainHeight {
                then assign newHeight := currentHeight;
            }
            
            then done;
        }
    }
    
    part def BackrestMechanism {
        attribute currentAngle : AngleValue;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        
        action adjustBackrest {
            in targetAngle : AngleValue;
            out newAngle : AngleValue;
            
            first start;
            then decide;
                if targetAngle.degrees > currentAngle.degrees then incline;
                if targetAngle.degrees < currentAngle.degrees then recline;
                if targetAngle.degrees == currentAngle.degrees then hold;
            
            action incline {
                then assign newAngle := targetAngle;
                then assign currentAngle := newAngle;
            }
            
            action recline {
                then assign newAngle := targetAngle;
                then assign currentAngle := newAngle;
            }
            
            action hold {
                then assign newAngle := currentAngle;
            }
            
            then done;
        }
    }
    
    part def SafetyRail {
        attribute isRaised : Boolean;
        attribute height : LengthValue;
        attribute lockEngaged : Boolean;
        
        action raiseRail {
            first start;
            then assign isRaised := true;
            then assign lockEngaged := true;
            then done;
        }
        
        action lowerRail {
            first start;
            then assign lockEngaged := false;
            then assign isRaised := false;
            then done;
        }
    }
    
    part def StretcherController {
        port controlInterface : ControlPort;
        
        action monitorSafety {
            in patientSecured : Boolean;
            in railsRaised : Boolean;
            in wheelsLocked : Boolean;
            out safetyStatus : Boolean;
            
            first start;
            then decide;
                if patientSecured and railsRaised and wheelsLocked then safe;
                else unsafe;
            
            action safe {
                then assign safetyStatus := true;
            }
            
            action unsafe {
                then assign safetyStatus := false;
            }
            
            then done;
        }
    }
    
    part def Stretcher {
        attribute stretcherId : String;
        attribute totalMass : MassValue;
        attribute operationalMode : OperationalMode;
        
        port patientInterface : PatientSupportPort;
        port operatorInterface : ControlPort;
        
        part mainFrame : Frame {
            port :>> frameSupport;
        }
        
        part patientMattress : Mattress {
            port :>> mattressSupport;
        }
        
        part wheels : WheelAssembly {
            perform action lockWheels[*] ordered;
            perform action unlockWheels[*] ordered;
        }
        
        part heightSystem : HeightAdjustmentMechanism {
            perform action adjustHeight[*] ordered;
        }
        
        part backrestSystem : BackrestMechanism {
            perform action adjustBackrest[*] ordered;
        }
        
        part leftRail : SafetyRail {
            perform action raiseRail[*] ordered;
            perform action lowerRail[*] ordered;
        }
        
        part rightRail : SafetyRail {
            perform action raiseRail[*] ordered;
            perform action lowerRail[*] ordered;
        }
        
        part controller : StretcherController {
            port :>> controlInterface;
            perform action monitorSafety[*] ordered;
        }
        
        connection frameToMattress connect mainFrame.frameSupport to patientMattress.mattressSupport;
    }
    
    action def SecurePatient {
        in patient : Patient;
        in stretcher : Stretcher;
        out secured : Boolean;
        
        first start;
        then assign patient.isSecured := true;
        then assign secured := true;
        then done;
    }
    
    action def PrepareForTransport {
        in stretcher : Stretcher;
        out ready : Boolean;
        
        first start;
        then perform stretcher.leftRail.raiseRail;
        then perform stretcher.rightRail.raiseRail;
        then perform stretcher.wheels.lockWheels;
        then assign ready := true;
        then done;
    }
    
    action def TransportPatient {
        in patient : Patient;
        in origin : LocationData;
        in destination : LocationData;
        out transportComplete : Boolean;
        
        first start;
        then action loadPatient : SecurePatient {
            in patient;
            out secured;
        }
        then action prepareTransport : PrepareForTransport {
            out ready;
        }
        then action unlockForMovement {
            first start;
            then done;
        }
        then action moveToDestination {
            in startLocation : LocationData = origin;
            in endLocation : LocationData = destination;
            out arrived : Boolean;
            
            first start;
            then assign arrived := true;
            then done;
        }
        then action lockAtDestination {
            first start;
            then done;
        }
        then action transferPatient {
            out transferred : Boolean;
            
            first start;
            then assign transferred := true;
            then done;
        }
        then assign transportComplete := transferPatient.transferred;
        then done;
    }
    
    part stretcherSystem : Stretcher {
        attribute :>> stretcherId = "STR-001";
        attribute :>> totalMass = 45.0[kg];
        
        part :>> mainFrame {
            attribute :>> maxLoadCapacity = 250.0[kg];
        }
        
        part :>> heightSystem {
            attribute :>> minHeight = 500.0[mm];
            attribute :>> maxHeight = 900.0[mm];
            attribute :>> currentHeight = 650.0[mm];
        }
        
        part :>> backrestSystem {
            attribute :>> minAngle {
                attribute :>> degrees = 0.0;
            }
            attribute :>> maxAngle {
                attribute :>> degrees = 75.0;
            }
            attribute :>> currentAngle {
                attribute :>> degrees = 0.0;
            }
        }
        
        perform action transportOperation[*] ordered : TransportPatient;
        
        part :>> controller {
            perform transportOperation.prepareTransport;
        }
        
        part :>> wheels {
            perform transportOperation.unlockForMovement;
            perform transportOperation.lockAtDestination;
        }
    }
    
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def FunctionalRequirement;
    
    requirement <'STR-REQ-001'> maxLoadCapacity : SafetyRequirement {
        doc /* The stretcher shall support a maximum patient mass of 250 kg without structural failure. */
        
        subject stretcher : Stretcher;
        
        require constraint {
            stretcher.mainFrame.maxLoadCapacity >= 250.0[kg]
        }
    }
    
    requirement <'STR-REQ-002'> heightAdjustmentRange : PerformanceRequirement {
        doc /* The stretcher shall provide height adjustment from 500 mm to 900 mm above ground level. */
        
        subject stretcher : Stretcher;
        
        require constraint {
            stretcher.heightSystem.minHeight == 500.0[mm] and
            stretcher.heightSystem.maxHeight == 900.0[mm]
        }
    }
    
    requirement <'STR-REQ-003'> backrestAdjustment : PerformanceRequirement {
        doc /* The backrest shall adjust from 0 to 75 degrees for patient positioning. */
        
        subject stretcher : Stretcher;
        
        require constraint {
            stretcher.backrestSystem.minAngle.degrees == 0.0 and
            stretcher.backrestSystem.maxAngle.degrees == 75.0
        }
    }
    
    requirement <'STR-REQ-004'> safetyRailRequirement : SafetyRequirement {
        doc /* Safety rails shall be raised and locked during patient transport. */
        
        subject stretcher : Stretcher;
        
        require constraint {
            stretcher.leftRail.isRaised and stretcher.rightRail.isRaised and
            stretcher.leftRail.lockEngaged and stretcher.rightRail.lockEngaged
        }
    }
    
    requirement <'STR-REQ-005'> wheelLockRequirement : SafetyRequirement {
        doc /* Wheels shall be locked when stretcher is stationary with patient. */
        
        subject stretcher : Stretcher;
        
        require constraint {
            stretcher.wheels.isLocked == true implies
            stretcher.wheels.brakeMechanism.engaged == true
        }
    }
    
    requirement <'STR-REQ-006'> primaryFunction : FunctionalRequirement {
        doc /* The stretcher system shall safely transport patients between locations while providing adjustable positioning and maintaining patient security. */
        
        assume constraint patientPresent {
            doc /* A patient is loaded onto the stretcher. */
        }
        
        require maxLoadCapacity;
        require heightAdjustmentRange;
        require backrestAdjustment;
        require safetyRailRequirement;
        require wheelLockRequirement;
    }
}
