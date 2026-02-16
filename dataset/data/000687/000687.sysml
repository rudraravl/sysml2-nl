package 'Meril Myval TAVR System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientID;
    attribute def DeviceSerialNumber;
    attribute def DeploymentCommand;
    attribute def NavigationCommand;
    attribute def SystemStatus;
    attribute def AlarmCode;
    
    enum def ValveState {
        crimped;
        loaded;
        navigating;
        positioned;
        partiallyDeployed;
        fullyDeployed;
        retrieved;
    }
    
    enum def ProcedurePhase {
        preparation;
        access;
        navigation;
        positioning;
        deployment;
        assessment;
        completion;
    }
    
    enum def LeakageGrade {
        none;
        trace;
        mild;
        moderate;
        severe;
    }
    
    item def PatientAnatomy {
        attribute aorticAnnulusDiameter : ISQ::LengthValue;
        attribute leftVentricleOutflowTractDiameter : ISQ::LengthValue;
        attribute aorticRootHeight : ISQ::LengthValue;
        attribute calcificationScore : Real;
    }
    
    item def HemodynamicData {
        attribute transvalvularGradient : ISQ::PressureValue;
        attribute cardiacOutput : ISQ::VolumeFlowValue;
        attribute paravalvularLeakage : LeakageGrade;
        attribute effectiveOrificeArea : ISQ::AreaValue;
    }
    
    item def ImagingData {
        attribute fluoroscopyView : String;
        attribute echocardiographicData : String;
        attribute valvePosition : ISQ::LengthValue;
        attribute deploymentDepth : ISQ::LengthValue;
    }
    
    port def FemoralAccessPort {
        in item guidewire;
        in item catheterSheath;
        out item deliverySystem;
    }
    
    port def ValveMountPort {
        in item valve;
        out item deployedValve;
    }
    
    port def ImagingPort {
        out flow imagingData : ImagingData;
    }
    
    port def HemodynamicPort {
        out flow hemodynamics : HemodynamicData;
    }
    
    port def ControlPort {
        in flow commands : DeploymentCommand;
        out flow status : SystemStatus;
    }
    
    part def MyvalBioprostheticValve {
        attribute valveSize : ISQ::LengthValue;
        attribute frameHeight : ISQ::LengthValue;
        attribute leafletMaterial : String := "bovine pericardium";
        attribute frameExpansionForce : ISQ::ForceValue;
        attribute currentState : ValveState := ValveState::crimped;
        
        port mountPort : ValveMountPort;
        
        attribute radialForce : ISQ::ForceValue;
        attribute axialForce : ISQ::ForceValue;
    }
    
    part def NavigatorDeliveryCatheter {
        attribute outerDiameter : ISQ::LengthValue;
        attribute workingLength : ISQ::LengthValue;
        attribute trackingMarkers : Integer := 3;
        attribute flexibilityRating : Real;
        
        port femoralAccess : FemoralAccessPort;
        port valveMount : ValveMountPort;
        port controlInterface : ControlPort;
        
        part noseCone {
            attribute taperAngle : Real;
        }
        
        part deliveryShaft {
            attribute stiffnessProfile : String;
        }
        
        part releaseHandle {
            attribute rotationMechanism : String;
        }
    }
    
    part def FluoroscopySystem {
        attribute frameRate : Real;
        attribute radiationDose : Real;
        
        port imagingOutput : ImagingPort;
    }
    
    part def EchocardiographySystem {
        attribute transducerType : String := "transesophageal";
        attribute imagingMode : String := "3D";
        
        port echoOutput : ImagingPort;
    }
    
    part def HemodynamicMonitor {
        attribute samplingRate : Real;
        
        port hemodynamicOutput : HemodynamicPort;
    }
    
    part def ControlConsole {
        attribute displayResolution : String;
        
        port controlOutput : ControlPort;
        port imagingInput : ImagingPort;
        port hemodynamicInput : HemodynamicPort;
    }
    
    action def PrepareValveAndCatheter {
        in valve : MyvalBioprostheticValve;
        in catheter : NavigatorDeliveryCatheter;
        out preparedSystem : Boolean;
        
        action inspectValve {
            in valve;
            out inspectionPassed : Boolean;
        }
        then action crimpValve {
            in valve;
        }
        then action loadValveOntoCatheter {
            in valve;
            in catheter;
        }
        then action flushCatheter {
            in catheter;
        }
        then assign preparedSystem := true;
    }
    
    action def EstablishVascularAccess {
        in patient : PatientAnatomy;
        in catheter : NavigatorDeliveryCatheter;
        out accessEstablished : Boolean;
        
        action performFemoralPuncture {
            in patient;
        }
        then action insertGuidewire;
        then action advanceSheath {
            in catheter;
        }
        then assign accessEstablished := true;
    }
    
    action def NavigateToAorticPosition {
        in catheter : NavigatorDeliveryCatheter;
        in imagingData : ImagingData;
        in patient : PatientAnatomy;
        out navigationComplete : Boolean;
        
        action crossAorticValve {
            in catheter;
            in imagingData;
        }
        then action positionInLeftVentricle {
            in catheter;
            in imagingData;
        }
        then action exchangeForStiffWire;
        then action advanceDeliverySystem {
            in catheter;
            in imagingData;
        }
        then assign navigationComplete := true;
    }
    
    action def PositionValve {
        in valve : MyvalBioprostheticValve;
        in catheter : NavigatorDeliveryCatheter;
        in imagingData : ImagingData;
        in patient : PatientAnatomy;
        out positioningComplete : Boolean;
        
        action alignWithAnnulus {
            in valve;
            in imagingData;
            in patient;
        }
        then action verifyCoaxialAlignment {
            in imagingData;
        }
        then action confirmImplantDepth {
            in imagingData;
            in patient;
        }
        then assign positioningComplete := true;
    }
    
    action def DeployValve {
        in valve : MyvalBioprostheticValve;
        in catheter : NavigatorDeliveryCatheter;
        in deploymentCmd : DeploymentCommand;
        out deploymentComplete : Boolean;
        
        action initiateRelease {
            in deploymentCmd;
        }
        then action monitorExpansion {
            in valve;
        }
        then action completeRelease {
            in catheter;
        }
        then action detachDeliverySystem {
            in catheter;
        }
        then assign deploymentComplete := true;
    }
    
    action def AssessValveFunction {
        in valve : MyvalBioprostheticValve;
        in hemodynamics : HemodynamicData;
        in imagingData : ImagingData;
        out assessmentResult : Boolean;
        
        action measureTransvalvularGradient {
            in hemodynamics;
            out gradient : ISQ::PressureValue;
        }
        then action evaluateParavalvularLeak {
            in imagingData;
            in hemodynamics;
            out leakageGrade : LeakageGrade;
        }
        then action checkValvePosition {
            in imagingData;
            out positionAcceptable : Boolean;
        }
        then decide;
            if checkValvePosition.positionAcceptable then acceptResult;
        action acceptResult {
            then assign assessmentResult := true;
        }
    }
    
    action def WithdrawDeliverySystem {
        in catheter : NavigatorDeliveryCatheter;
        out withdrawalComplete : Boolean;
        
        action removeDeliveryCatheter {
            in catheter;
        }
        then action removeGuidewire;
        then action achieveHemostasis;
        then assign withdrawalComplete := true;
    }
    
    action def PerformTAVRProcedure {
        in patient : PatientAnatomy;
        in valve : MyvalBioprostheticValve;
        in catheter : NavigatorDeliveryCatheter;
        out procedureSuccess : Boolean;
        
        action prepare : PrepareValveAndCatheter {
            in valve;
            in catheter;
        }
        then action access : EstablishVascularAccess {
            in patient;
            in catheter;
        }
        then action navigate : NavigateToAorticPosition {
            in catheter;
            in patient;
        }
        then action position : PositionValve {
            in valve;
            in catheter;
            in patient;
        }
        then action deploy : DeployValve {
            in valve;
            in catheter;
        }
        then action assess : AssessValveFunction {
            in valve;
        }
        then action withdraw : WithdrawDeliverySystem {
            in catheter;
        }
        then assign procedureSuccess := true;
    }
    
    state def TAVRProcedureStateMachine {
        entry; then preparation;
        
        state preparation;
        accept accessReady;
        then vascularAccess;
        
        state vascularAccess;
        accept navigationReady;
        then navigation;
        
        state navigation;
        accept positioningReady;
        then positioning;
        
        state positioning;
        accept deploymentReady;
        then deployment;
        
        state deployment;
        accept assessmentReady;
        then assessment;
        
        state assessment;
        accept completionReady;
        then completion;
        
        state completion;
        then done;
    }
    
    part def TAVRSystem;
    
    part tavrSystem : TAVRSystem {
        attribute deviceSerial : DeviceSerialNumber;
        attribute currentPhase : ProcedurePhase := ProcedurePhase::preparation;
        
        part myvalValve : MyvalBioprostheticValve {
            attribute :>> valveSize = 26.0 [SI::mm];
            attribute :>> frameHeight = 16.0 [SI::mm];
            attribute :>> radialForce = 8.5 [SI::N];
        }
        
        part navigatorCatheter : NavigatorDeliveryCatheter {
            attribute :>> outerDiameter = 14.0 [SI::mm];
            attribute :>> workingLength = 1100.0 [SI::mm];
        }
        
        part fluoroscopy : FluoroscopySystem {
            attribute :>> frameRate = 15.0;
        }
        
        part echo : EchocardiographySystem;
        
        part hemodynamicMonitor : HemodynamicMonitor {
            attribute :>> samplingRate = 100.0;
        }
        
        part controlConsole : ControlConsole;
        
        connection valveToCatheter connect myvalValve.mountPort to navigatorCatheter.valveMount;
        connection fluoroscopyToConsole connect fluoroscopy.imagingOutput to controlConsole.imagingInput;
        connection echoToConsole connect echo.echoOutput to controlConsole.imagingInput;
        connection hemodynamicsToConsole connect hemodynamicMonitor.hemodynamicOutput to controlConsole.hemodynamicInput;
        connection consoleToDelivery connect controlConsole.controlOutput to navigatorCatheter.controlInterface;
        
        perform action tavrProcedure : PerformTAVRProcedure {
            in valve = myvalValve;
            in catheter = navigatorCatheter;
        }
        
        state procedureStateMachine : TAVRProcedureStateMachine;
    }
    
    requirement <'REQ-001'> primaryMission {
        doc /* The Meril Myval TAVR System shall enable minimally invasive transcatheter 
                replacement of diseased aortic valves in patients with severe aortic stenosis, 
                restoring normal hemodynamic function through transfemoral delivery of a 
                bioprosthetic valve to the native aortic annulus. */
        
        subject tavrSystem;
    }
    
    requirement <'REQ-002'> hemodynamicPerformance {
        doc /* Post-implantation, the Myval valve shall achieve a mean transvalvular 
                pressure gradient of less than 20 mmHg and an effective orifice area 
                greater than 1.5 cm² to ensure adequate cardiac output. */
        
        subject tavrSystem.myvalValve;
    }
    
    requirement <'REQ-003'> paravalvularLeakage {
        doc /* The system shall achieve paravalvular leakage of none or trace grade 
                in at least 95% of successful implantations to prevent regurgitation. */
        
        subject tavrSystem;
    }
    
    requirement <'REQ-004'> deliverySystemPerformance {
        doc /* The Navigator delivery catheter shall enable precise positioning and 
                controlled deployment of the Myval valve with positional accuracy 
                within ±2 mm of the intended implantation depth. */
        
        subject tavrSystem.navigatorCatheter;
    }
    
    requirement <'REQ-005'> procedureSuccess {
        doc /* The TAVR procedure shall achieve successful valve implantation, defined 
                as proper positioning, full deployment, and acceptable hemodynamic 
                performance, in a single attempt without need for second valve. */
        
        subject tavrSystem;
        
        require primaryMission;
        require hemodynamicPerformance;
        require paravalvularLeakage;
        require deliverySystemPerformance;
    }
}
