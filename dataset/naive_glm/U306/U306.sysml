package TAVRSystem {
    import ScalarValues::*;
    
    // ---- Units ----
    unit mm;
    unit cm;
    unit N;
    unit mmHg;
    unit L_per_min;
    unit MHz;
    
    // ---- Value Types ----
    attribute def Length :> Real { unit mm; }
    attribute def Force :> Real { unit N; }
    attribute def Pressure :> Real { unit mmHg; }
    attribute def FlowRate :> Real { unit L_per_min; }
    attribute def Frequency :> Real { unit MHz; }
    
    // ---- Items ----
    item def Blood;
    item def ImagingData;
    item def ControlSignal;
    item def HemodynamicData;
    
    // ---- Ports ----
    port def ControlPort {
        in item command : ControlSignal;
        out item status : ControlSignal;
    }
    
    port def ImagingDataPort {
        out item imagingData : ImagingData;
    }
    
    port def HemodynamicDataPort {
        out item hemodynamicData : HemodynamicData;
    }
    
    port def BloodFlowPort {
        in item bloodIn : Blood;
        out item bloodOut : Blood;
    }
    
    // ---- Valve ----
    part def MyvalBioprostheticValve {
        attribute crimpedDiameter : Length = 5.0 [mm];
        attribute expandedDiameter : Length = 23.0 [mm];
        attribute radialForce : Force = 2.5 [N];
        attribute leafletMaterial : String = "Bovine pericardium";
        
        port crimpingInterface;
        port annulusInterface;
        port leafletFlowPort : BloodFlowPort;
        
        part leaflets[3] {
            attribute material : String = "Bovine pericardium";
        }
        
        state machine ValveLifecycle {
            initial; then Crimped;
            state Crimped;
            transition from Crimped to Deployed when deploySignal;
            state Deployed;
        }
    }
    
    // ---- Delivery Catheter ----
    part def NavigatorDeliveryCatheter {
        attribute catheterLength : Length = 90.0 [cm];
        attribute outerDiameter : Length = 6.0 [mm];
        
        port distalTip;
        port proximalHandle;
        port controlInterface : ControlPort;
        
        part releaseHandle {
            attribute actuationForce : Force = 5.0 [N];
        }
        
        part tip {
            port valveHolder;
        }
        
        state machine CatheterState {
            initial; then Empty;
            state Empty;
            transition from Empty to Loaded when valveLoaded;
            state Loaded;
            transition from Loaded to Navigating when insertionStarted;
            state Navigating;
            transition from Navigating to Deploying when atTarget;
            state Deploying;
            transition from Deploying to Withdrawn when valveReleased;
            state Withdrawn;
        }
    }
    
    // ---- Fluoroscopy ----
    part def FluoroscopySystem {
        attribute radiationDose : Real = 0.0;
        port imagingDataPort : ImagingDataPort;
        
        action def AcquireFluoroscopy {
            out item fluoroscopyImage : ImagingData;
        }
    }
    
    // ---- Echocardiography ----
    part def EchocardiographySystem {
        port imagingDataPort : ImagingDataPort;
        
        part teeProbe {
            attribute frequency : Frequency = 5.0 [MHz];
        }
        
        action def AcquireEcho {
            out item echoImage : ImagingData;
        }
    }
    
    // ---- Hemodynamic Monitor ----
    part def HemodynamicMonitor {
        port hemodynamicDataPort : HemodynamicDataPort;
        attribute pressureGradient : Pressure = 0.0 [mmHg];
        attribute flowRate : FlowRate = 0.0 [L_per_min];
        
        action def MeasureHemodynamics {
            out item hemodynamicData : HemodynamicData;
        }
    }
    
    // ---- Control Console ----
    part def ControlConsole {
        port catheterControlPort : ControlPort;
        port fluoroscopyPort : ImagingDataPort;
        port echoPort : ImagingDataPort;
        port hemodynamicPort : HemodynamicDataPort;
        
        part display {
            attribute resolution : String = "1920x1080";
        }
        
        action def IntegrateData {
            in item fluoroscopyData : ImagingData;
            in item echoData : ImagingData;
            in item hemodynamicData : HemodynamicData;
        }
    }
    
    // ---- Patient ----
    part def Patient {
        port femoralArteryAccess;
        port aorticValveAnnulus;
        
        part heart {
            part aorticValve;
        }
        
        part vascularSystem {
            part femoralArtery;
            part aorta;
        }
    }
    
    // ---- Top-Level System ----
    part def TAVRSystem {
        part valve : MyvalBioprostheticValve;
        part catheter : NavigatorDeliveryCatheter;
        part fluoroscopy : FluoroscopySystem;
        part echo : EchocardiographySystem;
        part hemodynamic : HemodynamicMonitor;
        part console : ControlConsole;
        part patient : Patient;
        
        connection valveHolding connect catheter.tip.valveHolder to valve.crimpingInterface;
        connection catheterInsertion connect catheter.distalTip to patient.femoralArteryAccess;
        connection valveDeployment connect valve.annulusInterface to patient.aorticValveAnnulus;
        connection controlLink connect catheter.controlInterface to console.catheterControlPort;
        connection fluoroscopyLink connect fluoroscopy.imagingDataPort to console.fluoroscopyPort;
        connection echoLink connect echo.imagingDataPort to console.echoPort;
        connection hemodynamicLink connect hemodynamic.hemodynamicDataPort to console.hemodynamicPort;
        
        state machine ProcedureLifecycle {
            initial; then Preparation;
            state Preparation;
            transition from Preparation to VascularAccess when accessGained;
            state VascularAccess;
            transition from VascularAccess to Navigation when catheterInserted;
            state Navigation;
            transition from Navigation to Positioning when valveAtTarget;
            state Positioning;
            transition from Positioning to Deployment when positionConfirmed;
            state Deployment;
            transition from Deployment to Assessment when valveDeployed;
            state Assessment;
            transition from Assessment to Withdrawal when assessmentComplete;
            state Withdrawal;
            transition from Withdrawal to Done when catheterRemoved;
            state Done;
        }
    }
    
    // ---- Procedure Actions ----
    action def TAVRProcedureActions {
        in valve : MyvalBioprostheticValve;
        in catheter : NavigatorDeliveryCatheter;
        in patient : Patient;
        
        action PrepareValveAndCatheter;
        action GainVascularAccess;
        action NavigateToHeart;
        action PositionValve;
        action DeployValve;
        action AssessValvePerformance;
        action WithdrawDeliverySystem;
        
        succession PrepareValveAndCatheter then GainVascularAccess;
        succession GainVascularAccess then NavigateToHeart;
        succession NavigateToHeart then PositionValve;
        succession PositionValve then DeployValve;
        succession DeployValve then AssessValvePerformance;
        succession AssessValvePerformance then WithdrawDeliverySystem;
    }
    
    // ---- Requirements ----
    requirement def TAVRSystemRequirements {
        subject system : TAVRSystem;
        
        requirement ValveReplacement {
            doc "The system shall replace a diseased aortic valve without open-heart surgery."
        }
        
        requirement ValveCrimping {
            subject valve : MyvalBioprostheticValve;
            doc "The valve shall be crimped to a diameter of less than 6 mm."
        }
        
        requirement ValveExpansion {
            subject valve : MyvalBioprostheticValve;
            doc "The valve shall expand with a radial force of at least 2 N to anchor within the native valve."
        }
        
        requirement CatheterNavigation {
            subject catheter : NavigatorDeliveryCatheter;
            doc "The catheter shall navigate from femoral artery to the heart."
        }
        
        requirement ImagingGuidance {
            subject fluoroscopy : FluoroscopySystem;
            doc "Fluoroscopy shall provide live X-ray imaging."
        }
        
        requirement EchoAssessment {
            subject echo : EchocardiographySystem;
            doc "Echocardiography shall provide real-time ultrasound images."
        }
        
        requirement HemodynamicMonitoring {
            subject hemodynamic : HemodynamicMonitor;
            doc "Hemodynamic monitor shall measure blood pressure gradients and flow."
        }
        
        requirement ConsoleIntegration {
            subject console : ControlConsole;
            doc "Console shall display integrated imaging and vital signs."
        }
    }
}
