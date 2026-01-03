package 'Protected PCI System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientID;
    attribute def BloodFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def BloodPressure :> ISQ::PressureValue;
    attribute def OxygenSaturation :> Real;
    attribute def HeartRate :> ISQ::FrequencyValue;
    attribute def PumpSpeed :> ISQ::FrequencyValue;
    attribute def StentDiameter :> ISQ::LengthValue;
    attribute def BalloonPressure :> ISQ::PressureValue;
    attribute def LesionSeverity :> Real;
    
    enum def SupportLevel {
        off;
        low;
        medium;
        high;
    }
    
    enum def ProcedurePhase {
        preparation;
        access;
        diagnostic;
        intervention;
        completion;
    }
    
    item def Blood {
        attribute oxygenLevel : OxygenSaturation;
        attribute flowRate : BloodFlowRate;
        attribute pressure : BloodPressure;
    }
    
    item def ContrastAgent {
        attribute volume : ISQ::VolumeValue;
        attribute concentration : Real;
    }
    
    part def Patient {
        attribute patientID : PatientID;
        
        part coronaryArteries {
            attribute leftMainStenosis : LesionSeverity;
            attribute ladStenosis : LesionSeverity;
            attribute lcxStenosis : LesionSeverity;
            port arterialLumen;
        }
        
        part leftVentricle {
            attribute ejectionFraction : Real;
            attribute endDiastolicPressure : BloodPressure;
            attribute strokeVolume : ISQ::VolumeValue;
            port ventricularChamber;
        }
        
        part aorta {
            attribute systolicPressure : BloodPressure;
            attribute diastolicPressure : BloodPressure;
            port aorticRoot;
        }
        
        part peripheralVasculature {
            port femoralArtery;
            port radialArtery;
        }
        
        attribute vitalSigns {
            attribute heartRate : HeartRate;
            attribute meanArterialPressure : BloodPressure;
            attribute oxygenSaturation : OxygenSaturation;
            attribute cardiacOutput : BloodFlowRate;
        }
    }
    
    part def MechanicalCirculatorySupport {
        attribute supportLevel : SupportLevel;
        attribute pumpSpeed : PumpSpeed;
        attribute flowRate : BloodFlowRate;
        attribute motorCurrent : ISQ::ElectricCurrentValue;
        
        port inletPort {
            in item bloodIn : Blood;
        }
        
        port outletPort {
            out item bloodOut : Blood;
        }
        
        port controlInterface {
            in attribute commandedSpeed : PumpSpeed;
            out attribute actualSpeed : PumpSpeed;
            out attribute deliveredFlow : BloodFlowRate;
        }
        
        state machine SupportOperation {
            initial state Standby;
            state Priming;
            state Ramping;
            state ActiveSupport;
            state Weaning;
            state Alarm;
            
            transition from Standby to Priming 
                when supportLevel == SupportLevel::low;
            
            transition from Priming to Ramping 
                when flowRate > 1.0 * ISQ::liter_per_second;
            
            transition from Ramping to ActiveSupport 
                when pumpSpeed >= 40000.0 * ISQ::hertz;
            
            transition from ActiveSupport to Weaning 
                when supportLevel == SupportLevel::off;
            
            transition from Weaning to Standby 
                when pumpSpeed < 10000.0 * ISQ::hertz;
            
            transition from ActiveSupport to Alarm 
                when motorCurrent > 2.0 * ISQ::ampere;
            
            transition from Alarm to Standby;
        }
    }
    
    part def GuideCatheter {
        attribute diameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        attribute tipShape : String;
        port proximalHub;
        port distalTip;
    }
    
    part def GuideWire {
        attribute diameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        attribute tipLoad : ISQ::ForceValue;
        attribute position : ISQ::LengthValue;
    }
    
    part def BalloonCatheter {
        attribute balloonDiameter : ISQ::LengthValue;
        attribute balloonLength : ISQ::LengthValue;
        attribute ratedBurstPressure : BalloonPressure;
        attribute currentPressure : BalloonPressure;
        attribute inflated : Boolean;
    }
    
    part def CoronaryStent {
        attribute nominalDiameter : StentDiameter;
        attribute length : ISQ::LengthValue;
        attribute expanded : Boolean;
        attribute appositionComplete : Boolean;
    }
    
    part def FluoroscopySystem {
        attribute frameRate : ISQ::FrequencyValue;
        attribute doseRate : ISQ::AbsorbedDoseRateValue;
        attribute contrastVisible : Boolean;
        port imageOutput;
    }
    
    part def HemodynamicMonitor {
        port ecgInput;
        port pressureInput;
        port displayOutput;
        
        in attribute heartRate : HeartRate;
        in attribute arterialPressure : BloodPressure;
        in attribute centralVenousPressure : BloodPressure;
        in attribute oxygenSaturation : OxygenSaturation;
        out attribute alarmActive : Boolean;
    }
    
    part def ControlConsole {
        port operatorInterface;
        port pumpControl;
        port monitoringInput;
        
        in attribute hemodynamicData;
        out attribute pumpCommands;
        out attribute alarmNotifications;
    }
    
    requirement def SafetyRequirement {
        doc /* All system operations shall maintain patient safety as the highest priority. */
    }
    
    requirement def HemodynamicStabilityRequirement :> SafetyRequirement {
        doc /* The mechanical circulatory support shall maintain mean arterial pressure 
             above 65 mmHg and cardiac output above 4 L/min during high-risk PCI to ensure 
             adequate organ perfusion and prevent hemodynamic collapse. */
        
        subject mcs : MechanicalCirculatorySupport;
        
        require constraint {
            doc /* Mean arterial pressure must remain above critical threshold */
            mcs.flowRate >= 4.0 * ISQ::liter_per_second
        }
    }
    
    requirement def RevascularizationRequirement {
        doc /* The system shall enable complete revascularization of target coronary lesions 
             with successful stent deployment and optimal apposition under fluoroscopic guidance. */
    }
    
    requirement def MonitoringRequirement :> SafetyRequirement {
        doc /* Continuous real-time monitoring of hemodynamic parameters shall be maintained 
             with immediate alarm notification for critical deviations from safe ranges. */
    }
    
    requirement def SupportDurationRequirement {
        doc /* Mechanical circulatory support duration shall be minimized to reduce vascular 
             complications while ensuring procedural success, typically not exceeding 90 minutes. */
    }
    
    action def EstablishVascularAccess {
        in patient : Patient;
        out accessEstablished : Boolean;
        out accessSite : String;
    }
    
    action def InsertMechanicalSupport {
        in patient : Patient;
        in accessSite : String;
        out supportDevice : MechanicalCirculatorySupport;
        out devicePositioned : Boolean;
    }
    
    action def ActivateHemodynamicSupport {
        in supportDevice : MechanicalCirculatorySupport;
        in targetLevel : SupportLevel;
        out supportActive : Boolean;
        out achievedFlow : BloodFlowRate;
    }
    
    action def PositionGuideCatheter {
        in patient : Patient;
        in catheter : GuideCatheter;
        in targetVessel : String;
        out catheterEngaged : Boolean;
    }
    
    action def PerformDiagnosticAngiography {
        in imaging : FluoroscopySystem;
        in contrast : ContrastAgent;
        out lesionIdentified : Boolean;
        out lesionSeverity : LesionSeverity;
        out vesselDiameter : ISQ::LengthValue;
    }
    
    action def CrossLesionWithWire {
        in wire : GuideWire;
        in lesionSeverity : LesionSeverity;
        out wireCrossed : Boolean;
        out distalFlow : Boolean;
    }
    
    action def PredilateLesion {
        in balloon : BalloonCatheter;
        in targetPressure : BalloonPressure;
        out lesionPrepared : Boolean;
    }
    
    action def DeployStent {
        in stent : CoronaryStent;
        in balloon : BalloonCatheter;
        in deploymentPressure : BalloonPressure;
        out stentExpanded : Boolean;
    }
    
    action def PostdilateStent {
        in balloon : BalloonCatheter;
        in highPressure : BalloonPressure;
        out optimalApposition : Boolean;
    }
    
    action def VerifyResult {
        in imaging : FluoroscopySystem;
        in contrast : ContrastAgent;
        out residualStenosis : LesionSeverity;
        out timiFlow : Integer;
        out procedureSuccess : Boolean;
    }
    
    action def WeanMechanicalSupport {
        in supportDevice : MechanicalCirculatorySupport;
        in monitoring : HemodynamicMonitor;
        out hemodynamicsStable : Boolean;
        out supportWeaned : Boolean;
    }
    
    action def RemoveSupport {
        in supportDevice : MechanicalCirculatorySupport;
        out deviceRemoved : Boolean;
    }
    
    action def AchieveHemostasis {
        in accessSite : String;
        out bleedingControlled : Boolean;
    }
    
    action def MonitorHemodynamics {
        in monitor : HemodynamicMonitor;
        in support : MechanicalCirculatorySupport;
        out stable : Boolean;
        out adjustmentNeeded : Boolean;
    }
    
    action def AdjustSupport {
        in currentLevel : SupportLevel;
        in hemodynamics;
        out newLevel : SupportLevel;
    }
    
    action def PerformProtectedPCI {
        doc /* Primary function: Perform percutaneous coronary intervention with active 
             mechanical circulatory support to enable safe revascularization in high-risk 
             patients with severe coronary artery disease and compromised left ventricular 
             function. The system maintains hemodynamic stability through continuous ventricular 
             unloading while complex coronary interventions are performed under fluoroscopic 
             guidance, preventing hemodynamic collapse and ensuring adequate organ perfusion 
             throughout the procedure. */
        
        in patient : Patient;
        in targetVessel : String;
        out procedureSuccess : Boolean;
        out finalTIMIFlow : Integer;
        
        first start;
        
        then action establishAccess : EstablishVascularAccess {
            in patient = PerformProtectedPCI::patient;
            out accessEstablished;
            out accessSite;
        }
        
        then action insertSupport : InsertMechanicalSupport {
            in patient = PerformProtectedPCI::patient;
            in accessSite = establishAccess.accessSite;
            out supportDevice;
            out devicePositioned;
        }
        
        then action activateSupport : ActivateHemodynamicSupport {
            in supportDevice = insertSupport.supportDevice;
            in targetLevel = SupportLevel::high;
            out supportActive;
            out achievedFlow;
        }
        
        then merge monitoringLoop;
        
        then action continuousMonitor : MonitorHemodynamics {
            in monitor;
            in support = insertSupport.supportDevice;
            out stable;
            out adjustmentNeeded;
        }
        
        then decide;
            if continuousMonitor.adjustmentNeeded then adjustSupportLevel;
            if continuousMonitor.stable then proceedWithIntervention;
        
        action adjustSupportLevel {
            action adjust : AdjustSupport {
                in currentLevel = SupportLevel::high;
                in hemodynamics;
                out newLevel;
            }
        }
        then monitoringLoop;
        
        action proceedWithIntervention {
            first action positionCatheter : PositionGuideCatheter {
                in patient = PerformProtectedPCI::patient;
                in catheter;
                in targetVessel = PerformProtectedPCI::targetVessel;
                out catheterEngaged;
            }
            
            then action diagnosticAngio : PerformDiagnosticAngiography {
                in imaging;
                in contrast;
                out lesionIdentified;
                out lesionSeverity;
                out vesselDiameter;
            }
            
            then action crossLesion : CrossLesionWithWire {
                in wire;
                in lesionSeverity = diagnosticAngio.lesionSeverity;
                out wireCrossed;
                out distalFlow;
            }
            
            then action predilatation : PredilateLesion {
                in balloon;
                in targetPressure;
                out lesionPrepared;
            }
            
            then action stentDeployment : DeployStent {
                in stent;
                in balloon = predilatation.balloon;
                in deploymentPressure;
                out stentExpanded;
            }
            
            then action postdilatation : PostdilateStent {
                in balloon;
                in highPressure;
                out optimalApposition;
            }
            
            then action finalAngio : VerifyResult {
                in imaging;
                in contrast;
                out residualStenosis;
                out timiFlow;
                out procedureSuccess;
            }
        }
        
        then action weanSupport : WeanMechanicalSupport {
            in supportDevice = insertSupport.supportDevice;
            in monitoring;
            out hemodynamicsStable;
            out supportWeaned;
        }
        
        then action removeDevice : RemoveSupport {
            in supportDevice = insertSupport.supportDevice;
            out deviceRemoved;
        }
        
        then action achieveHemostasis : AchieveHemostasis {
            in accessSite = establishAccess.accessSite;
            out bleedingControlled;
        }
        
        then assign procedureSuccess := 
            proceedWithIntervention.finalAngio.procedureSuccess && 
            weanSupport.hemodynamicsStable && 
            achieveHemostasis.bleedingControlled;
        
        then assign finalTIMIFlow := proceedWithIntervention.finalAngio.timiFlow;
        
        then done;
    }
    
    part protectedPCISystem {
        doc /* Protected PCI system integrating mechanical circulatory support with advanced 
             interventional cardiology equipment to enable safe coronary revascularization in 
             high-risk patients. The system provides active hemodynamic support through 
             ventricular unloading, maintaining adequate perfusion pressure and cardiac output 
             while complex coronary interventions are performed. This allows treatment of 
             patients with severe left ventricular dysfunction and extensive coronary disease 
             who would otherwise be at prohibitive risk for conventional PCI. */
        
        part highRiskPatient : Patient {
            attribute patientID;
            
            part coronaryArteries {
                attribute leftMainStenosis = 85.0;
                attribute ladStenosis = 90.0;
                attribute lcxStenosis = 75.0;
            }
            
            part leftVentricle {
                attribute ejectionFraction = 25.0;
                attribute endDiastolicPressure;
                attribute strokeVolume;
            }
            
            part aorta {
                attribute systolicPressure;
                attribute diastolicPressure;
            }
            
            attribute vitalSigns {
                attribute heartRate = 85.0 * ISQ::hertz;
                attribute meanArterialPressure;
                attribute oxygenSaturation = 96.0;
                attribute cardiacOutput;
            }
        }
        
        part mcs : MechanicalCirculatorySupport {
            attribute supportLevel = SupportLevel::high;
            attribute pumpSpeed = 45000.0 * ISQ::hertz;
            attribute flowRate = 4.5 * ISQ::liter_per_second;
            attribute motorCurrent = 1.2 * ISQ::ampere;
        }
        
        part guideCatheter : GuideCatheter {
            attribute diameter = 2.0 * ISQ::mm;
            attribute length = 100.0 * ISQ::mm;
            attribute tipShape = "JL4";
        }
        
        part guideWire : GuideWire {
            attribute diameter = 0.014 * ISQ::mm;
            attribute length = 300.0 * ISQ::mm;
            attribute tipLoad = 1.0 * ISQ::N;
        }
        
        part balloonCatheter : BalloonCatheter {
            attribute balloonDiameter = 3.0 * ISQ::mm;
            attribute balloonLength = 15.0 * ISQ::mm;
            attribute ratedBurstPressure;
            attribute currentPressure;
            attribute inflated = false;
        }
        
        part stent : CoronaryStent {
            attribute nominalDiameter = 3.5 * ISQ::mm;
            attribute length = 18.0 * ISQ::mm;
            attribute expanded = false;
            attribute appositionComplete = false;
        }
        
        part fluoroscopy : FluoroscopySystem {
            attribute frameRate = 15.0 * ISQ::hertz;
            attribute doseRate;
            attribute contrastVisible = true;
        }
        
        part monitor : HemodynamicMonitor {
            in attribute heartRate = highRiskPatient.vitalSigns.heartRate;
            in attribute arterialPressure;
            in attribute centralVenousPressure;
            in attribute oxygenSaturation = highRiskPatient.vitalSigns.oxygenSaturation;
            out attribute alarmActive = false;
        }
        
        part console : ControlConsole;
        
        connection supportInlet : Connect 
            connect mcs.inletPort to highRiskPatient.leftVentricle.ventricularChamber;
        
        connection supportOutlet : Connect 
            connect mcs.outletPort to highRiskPatient.aorta.aorticRoot;
        
        connection catheterAccess : Connect 
            connect guideCatheter.proximalHub to highRiskPatient.peripheralVasculature.femoralArtery;
        
        connection catheterTarget : Connect 
            connect guideCatheter.distalTip to highRiskPatient.coronaryArteries.arterialLumen;
        
        connection pumpControl : Connect 
            connect console.pumpControl to mcs.controlInterface;
        
        connection monitoringData : Connect 
            connect monitor.displayOutput to console.monitoringInput;
        
        perform action procedure : PerformProtectedPCI {
            in patient = highRiskPatient;
            in targetVessel = "Left Main";
            out procedureSuccess;
            out finalTIMIFlow;
        }
        
        assert constraint hemodynamicStability :> HemodynamicStabilityRequirement {
            doc /* Verify adequate hemodynamic support is maintained */
            mcs.flowRate >= 4.0 * ISQ::liter_per_second
        }
        
        assert constraint continuousMonitoring :> MonitoringRequirement {
            doc /* Verify continuous monitoring is active */
            monitor.alarmActive == false || console.alarmNotifications != null
        }
        
        satisfy HemodynamicStabilityRequirement by mcs;
        satisfy RevascularizationRequirement by procedure;
        satisfy MonitoringRequirement by monitor;
    }
}
