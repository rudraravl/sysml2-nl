package ProtectedPercutaneousCoronaryInterventionModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Pressure {
        :> ScalarQuantityValue;
        unit = "mmHg";
    }

    attribute def FlowRate {
        :> ScalarQuantityValue;
        unit = "L/min";
    }

    attribute def Volume {
        :> ScalarQuantityValue;
        unit = "mL";
    }

    attribute def TimeDuration {
        :> ScalarQuantityValue;
        unit = "s";
    }

    attribute def ElectricalPower {
        :> ScalarQuantityValue;
        unit = "W";
    }

    attribute def Percent {
        :> ScalarQuantityValue;
        unit = "%";
    }

    attribute def Length {
        :> ScalarQuantityValue;
        unit = "mm";
    }

    attribute def DoseRate {
        :> ScalarQuantityValue;
        unit = "mL/s";
    }

    item def Blood {
        attribute oxygenSaturation : Percent;
        attribute arterialPressure : Pressure;
        attribute flow : FlowRate;
    }

    item def ContrastAgent {
        attribute injectedVolume : Volume;
        attribute injectionRate : DoseRate;
    }

    item def Guidewire {
        attribute diameter : Length;
        attribute positionInVessel : Length;
    }

    item def BalloonCatheter {
        attribute balloonDiameter : Length;
        attribute inflationPressure : Pressure;
        attribute inflationDuration : TimeDuration;
    }

    item def CoronaryStent {
        attribute nominalDiameter : Length;
        attribute deployedLength : Length;
        attribute expansionPressure : Pressure;
    }

    item def HemodynamicSignal {
        attribute meanArterialPressure : Pressure;
        attribute cardiacOutput : FlowRate;
        attribute supportFlow : FlowRate;
        attribute leftVentricularPressure : Pressure;
    }

    item def ImagingData {
        attribute stenosisSeverity : Percent;
        attribute lesionLength : Length;
        attribute vesselDiameter : Length;
    }

    item def ElectricalEnergy {
        attribute suppliedPower : ElectricalPower;
    }

    port def VascularAccessPort {
        inout blood : Blood;
        inout device : Guidewire;
        inout catheter : BalloonCatheter;
        inout stent : CoronaryStent;
    }

    port def HemodynamicSupportPort {
        in bloodIn : Blood;
        out bloodOut : Blood;
        out supportSignal : HemodynamicSignal;
    }

    port def ImagingPort {
        in contrast : ContrastAgent;
        out image : ImagingData;
    }

    port def MonitoringPort {
        in signal : HemodynamicSignal;
        out alert : HemodynamicSignal;
    }

    port def PowerPort {
        in energy : ElectricalEnergy;
    }

    port def OperatorCommandPort {
        in command : String;
        out status : String;
    }

    part def Patient {
        port femoralAccess : VascularAccessPort;
        port radialAccess : VascularAccessPort;
        port aorticFlowInterface : HemodynamicSupportPort;
        attribute baselineMeanArterialPressure : Pressure = 75 [mmHg];
        attribute baselineCardiacOutput : FlowRate = 3.2 [L/min];
        attribute targetCoronaryPerfusionPressure : Pressure = 65 [mmHg];

        part leftMainCoronaryArtery {
            attribute lesionSeverity : Percent = 85 [%];
            attribute lesionLength : Length = 18 [mm];
            attribute referenceDiameter : Length = 3.5 [mm];
        }

        part myocardium {
            attribute ischemicBurden : Percent = 28 [%];
            attribute perfusionReserve : Percent = 45 [%];
        }
    }

    part def MechanicalCirculatorySupportPump {
        port vascularInterface : HemodynamicSupportPort;
        port powerInput : PowerPort;
        port operatorInterface : OperatorCommandPort;
        attribute maximumSupportFlow : FlowRate = 4.0 [L/min];
        attribute minimumSupportFlow : FlowRate = 0.5 [L/min];
        attribute activeSupportFlow : FlowRate = 2.8 [L/min];
        attribute purgePressure : Pressure = 450 [mmHg];

        state def PumpOperatingState {
            state Off;
            state Priming;
            state Standby;
            state Supporting;
            state Weaning;
            state Fault;

            transition first Off then Priming
                accept command == "prime";

            transition Priming then Standby
                accept command == "primeComplete";

            transition Standby then Supporting
                accept command == "startSupport";

            transition Supporting then Weaning
                accept command == "reduceSupport";

            transition Weaning then Standby
                accept command == "supportStopped";

            transition Supporting then Fault
                accept command == "faultDetected";

            transition Fault then Standby
                accept command == "faultCleared";
        }
    }

    part def CoronaryInterventionSet {
        port access : VascularAccessPort;
        port imaging : ImagingPort;
        port operatorInterface : OperatorCommandPort;

        part guidingCatheter {
            attribute internalDiameter : Length = 2.1 [mm];
            attribute engagedOstium : Boolean = false;
        }

        part workhorseGuidewire : Guidewire {
            attribute diameter = 0.36 [mm];
            attribute positionInVessel = 0 [mm];
        }

        part predilationBalloon : BalloonCatheter {
            attribute balloonDiameter = 2.5 [mm];
            attribute inflationPressure = 12 [mmHg];
            attribute inflationDuration = 15 [s];
        }

        part drugElutingStent : CoronaryStent {
            attribute nominalDiameter = 3.5 [mm];
            attribute deployedLength = 24 [mm];
            attribute expansionPressure = 16 [mmHg];
        }

        part postDilationBalloon : BalloonCatheter {
            attribute balloonDiameter = 3.75 [mm];
            attribute inflationPressure = 18 [mmHg];
            attribute inflationDuration = 12 [s];
        }
    }

    part def ImagingAndMonitoringSubsystem {
        port imagingPort : ImagingPort;
        port monitorPort : MonitoringPort;
        port powerInput : PowerPort;
        attribute contrastLimit : Volume = 180 [mL];
        attribute minimumAcceptableMAP : Pressure = 65 [mmHg];
        attribute maximumFluoroscopyTime : TimeDuration = 3600 [s];

        action acquireCoronaryImage {
            in contrastBolus : ContrastAgent;
            out coronaryImage : ImagingData;
        }

        action evaluateHemodynamics {
            in measuredSignal : HemodynamicSignal;
            out stableSignal : HemodynamicSignal;
        }
    }

    part def ProtectedPCISystem {
        port operatorConsole : OperatorCommandPort;
        port facilityPower : PowerPort;

        part patient : Patient;
        part supportPump : MechanicalCirculatorySupportPump;
        part interventionSet : CoronaryInterventionSet;
        part imagingAndMonitoring : ImagingAndMonitoringSubsystem;

        connect facilityPower to supportPump.powerInput;
        connect facilityPower to imagingAndMonitoring.powerInput;
        connect patient.femoralAccess to interventionSet.access;
        connect patient.aorticFlowInterface to supportPump.vascularInterface;
        connect interventionSet.imaging to imagingAndMonitoring.imagingPort;
        connect supportPump.vascularInterface.supportSignal to imagingAndMonitoring.monitorPort.signal;
        connect operatorConsole to supportPump.operatorInterface;
        connect operatorConsole to interventionSet.operatorInterface;

        action performProtectedPCI {
            in patientReady : Boolean;
            out revascularizationComplete : Boolean;

            action establishVascularAccess {
                out accessSecured : Boolean;
            }

            action initiateHemodynamicSupport {
                in accessSecured : Boolean;
                out supportStable : Boolean;
            }

            action crossCoronaryLesion {
                in supportStable : Boolean;
                out lesionCrossed : Boolean;
            }

            action dilateLesion {
                in lesionCrossed : Boolean;
                out lumenPrepared : Boolean;
            }

            action deployStent {
                in lumenPrepared : Boolean;
                out stentExpanded : Boolean;
            }

            action verifyPerfusion {
                in stentExpanded : Boolean;
                out residualStenosisAcceptable : Boolean;
            }

            action weanSupport {
                in residualStenosisAcceptable : Boolean;
                out patientStableWithoutSupport : Boolean;
            }

            flow establishVascularAccess.accessSecured to initiateHemodynamicSupport.accessSecured;
            flow initiateHemodynamicSupport.supportStable to crossCoronaryLesion.supportStable;
            flow crossCoronaryLesion.lesionCrossed to dilateLesion.lesionCrossed;
            flow dilateLesion.lumenPrepared to deployStent.lumenPrepared;
            flow deployStent.stentExpanded to verifyPerfusion.stentExpanded;
            flow verifyPerfusion.residualStenosisAcceptable to weanSupport.residualStenosisAcceptable;
            flow weanSupport.patientStableWithoutSupport to revascularizationComplete;
        }

        state def ProcedureState {
            state PreProcedureAssessment;
            state AccessEstablished;
            state SupportActivated;
            state LesionTreatment;
            state StentOptimization;
            state PerfusionVerification;
            state SupportWeaning;
            state ProcedureComplete;
            state AbortForInstability;

            transition first PreProcedureAssessment then AccessEstablished
                accept command == "accessSecured";

            transition AccessEstablished then SupportActivated
                accept command == "supportStarted";

            transition SupportActivated then LesionTreatment
                accept command == "lesionCrossed";

            transition LesionTreatment then StentOptimization
                accept command == "stentDeployed";

            transition StentOptimization then PerfusionVerification
                accept command == "optimizeComplete";

            transition PerfusionVerification then SupportWeaning
                accept command == "perfusionAdequate";

            transition SupportWeaning then ProcedureComplete
                accept command == "stableWithoutSupport";

            transition SupportActivated then AbortForInstability
                accept command == "persistentHypotension";

            transition LesionTreatment then AbortForInstability
                accept command == "lossOfPerfusion";
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Protected PCI system shall enable high-risk coronary revascularization by maintaining systemic and coronary perfusion while interventional devices cross, dilate, stent, and optimize a severe coronary lesion. */
        subject system : ProtectedPCISystem;
        require constraint {
            system.supportPump.activeSupportFlow >= 2.0 [L/min]
        }
    }

    requirement def PerfusionSupportRequirement {
        doc /* During lesion treatment, the system shall maintain mean arterial pressure at or above 65 mmHg using mechanical circulatory support and continuous hemodynamic monitoring. */
        subject system : ProtectedPCISystem;
        require constraint {
            system.patient.baselineMeanArterialPressure >= 65 [mmHg]
        }
    }

    requirement def LesionTreatmentRequirement {
        doc /* The intervention subsystem shall support guidewire crossing, balloon predilation, drug eluting stent deployment, and post-dilation for a severe coronary stenosis. */
        subject set : CoronaryInterventionSet;
        require constraint {
            set.drugElutingStent.nominalDiameter >= 3.0 [mm] and
            set.drugElutingStent.deployedLength >= 18 [mm]
        }
    }

    requirement def ContrastSafetyRequirement {
        doc /* The imaging subsystem shall limit total contrast use while producing sufficient lesion and stent optimization data. */
        subject monitor : ImagingAndMonitoringSubsystem;
        require constraint {
            monitor.contrastLimit <= 180 [mL]
        }
    }

    requirement def SupportWeaningRequirement {
        doc /* The system shall permit controlled reduction of mechanical support after successful revascularization and hemodynamic stability verification. */
        subject pump : MechanicalCirculatorySupportPump;
        require constraint {
            pump.minimumSupportFlow <= 0.5 [L/min]
        }
    }

    satisfy PrimaryFunctionRequirement by ProtectedPCISystem;
    satisfy PerfusionSupportRequirement by ProtectedPCISystem;
    satisfy LesionTreatmentRequirement by CoronaryInterventionSet;
    satisfy ContrastSafetyRequirement by ImagingAndMonitoringSubsystem;
    satisfy SupportWeaningRequirement by MechanicalCirculatorySupportPump;
}