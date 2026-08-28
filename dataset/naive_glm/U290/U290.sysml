package Mammotome {

    package ValueTypes {
        value type PressureValue :> Real { unit 'Pa'; }
        value type VacuumLevelValue :> Real { unit 'mmHg'; }
        value type RotationalSpeedValue :> Real { unit 'rpm'; }
        value type DepthValue :> Real { unit 'mm'; }
        value type AngleValue :> Real { unit 'deg'; }
        value type VolumeValue :> Real { unit 'mL'; }
        value type DurationValue :> Real { unit 's'; }
        value type PowerValue :> Real { unit 'W'; }
        value type ForceValue :> Real { unit 'N'; }
        value type FrequencyValue :> Real { unit 'MHz'; }
    }

    package Items {
        item def BreastTissue {
            attribute locationDepth : Mammotome::ValueTypes::DepthValue;
            attribute locationAngle : Mammotome::ValueTypes::AngleValue;
        }

        item def TissueSample {
            attribute sampleId : String;
            attribute volume : Mammotome::ValueTypes::VolumeValue;
            attribute originDepth : Mammotome::ValueTypes::DepthValue;
            attribute originAngle : Mammotome::ValueTypes::AngleValue;
            attribute timestamp : String;
        }

        item def ImagingData {
            attribute targetDepth : Mammotome::ValueTypes::DepthValue;
            attribute targetAngle : Mammotome::ValueTypes::AngleValue;
            attribute lesionDiameter : Mammotome::ValueTypes::DepthValue;
            attribute confidence : Real;
        }

        item def ControlCommand {
            attribute commandType : String;
            attribute parameter : String;
        }

        item def StatusReport {
            attribute currentMode : String;
            attribute sampleCount : Integer;
            attribute vacuumLevel : Mammotome::ValueTypes::VacuumLevelValue;
            attribute cutterSpeed : Mammotome::ValueTypes::RotationalSpeedValue;
            attribute apertureAngle : Mammotome::ValueTypes::AngleValue;
            attribute faultFlag : Boolean;
        }
    }

    package Ports {
        port def ImagingOutPort {
            out imagingData : Mammotome::Items::ImagingData;
        }

        port def ImagingInPort {
            in imagingData : Mammotome::Items::ImagingData;
        }

        port def ControlOutPort {
            out command : Mammotome::Items::ControlCommand;
        }

        port def ControlInPort {
            in command : Mammotome::Items::ControlCommand;
        }

        port def StatusOutPort {
            out status : Mammotome::Items::StatusReport;
        }

        port def StatusInPort {
            in status : Mammotome::Items::StatusReport;
        }

        port def VacuumOutPort {
            out vacuumPressure : Mammotome::ValueTypes::VacuumLevelValue;
        }

        port def VacuumInPort {
            in vacuumPressure : Mammotome::ValueTypes::VacuumLevelValue;
        }

        port def CutterDriveOutPort {
            out cutterSpeed : Mammotome::ValueTypes::RotationalSpeedValue;
        }

        port def CutterDriveInPort {
            in cutterSpeed : Mammotome::ValueTypes::RotationalSpeedValue;
        }

        port def RotationOutPort {
            out apertureAngle : Mammotome::ValueTypes::AngleValue;
        }

        port def RotationInPort {
            in apertureAngle : Mammotome::ValueTypes::AngleValue;
        }

        port def SampleFlowOutPort {
            out sample : Mammotome::Items::TissueSample;
        }

        port def SampleFlowInPort {
            in sample : Mammotome::Items::TissueSample;
        }

        port def TissueInterfacePort {
            in tissue : Mammotome::Items::BreastTissue;
        }
    }

    package Requirements {

        requirement def BiopsySystemRequirement {
            doc /* The Mammotome system shall perform minimally invasive, vacuum-assisted breast biopsy under real-time imaging guidance. */
            attribute maxIncisionSize : Mammotome::ValueTypes::DepthValue = 4 [mm];
        }

        requirement def MultiSampleRequirement {
            doc /* The system shall acquire multiple tissue samples through a single incision without removing the probe. */
            attribute minSamplesPerProcedure : Integer = 12;
            attribute maxApertureRotation : Mammotome::ValueTypes::AngleValue = 360 [deg];
        }

        requirement def VacuumPerformanceRequirement {
            doc /* The vacuum subsystem shall generate sufficient negative pressure to draw tissue into the probe aperture and transport excised samples. */
            attribute minVacuum : Mammotome::ValueTypes::VacuumLevelValue = 400 [mmHg];
            attribute maxVacuum : Mammotome::ValueTypes::VacuumLevelValue = 600 [mmHg];
            attribute responseTime : Mammotome::ValueTypes::DurationValue = 2 [s];
        }

        requirement def CutterPerformanceRequirement {
            doc /* The cutter subsystem shall excise tissue samples using a high-speed rotating blade. */
            attribute minCutterSpeed : Mammotome::ValueTypes::RotationalSpeedValue = 3000 [rpm];
            attribute maxCutterSpeed : Mammotome::ValueTypes::RotationalSpeedValue = 5000 [rpm];
        }

        requirement def ImagingGuidanceRequirement {
            doc /* The imaging subsystem shall provide real-time ultrasound guidance to locate target tissue and determine insertion depth. */
            attribute maxDepthError : Mammotome::ValueTypes::DepthValue = 1 [mm];
            attribute minFrequency : Mammotome::ValueTypes::FrequencyValue = 7 [MHz];
        }

        requirement def ApertureRotationRequirement {
            doc /* The probe aperture shall be rotatable to multiple angular positions around the biopsy site to enable multi-sample collection. */
            attribute rotationIncrement : Mammotome::ValueTypes::AngleValue = 30 [deg];
        }

        requirement def SafetyRequirement {
            doc /* The system shall operate only in defined modes and shall prevent unsafe state transitions. */
            attribute emergencyStopTime : Mammotome::ValueTypes::DurationValue = 0.5 [s];
        }

        requirement def SampleIntegrityRequirement {
            doc /* Excised tissue samples shall be transported intact to the sample collector for pathological examination. */
            attribute maxTransportTime : Mammotome::ValueTypes::DurationValue = 5 [s];
        }

        requirement biopsySystemRequirement : BiopsySystemRequirement;
        requirement multiSampleRequirement : MultiSampleRequirement;
        requirement vacuumPerformanceRequirement : VacuumPerformanceRequirement;
        requirement cutterPerformanceRequirement : CutterPerformanceRequirement;
        requirement imagingGuidanceRequirement : ImagingGuidanceRequirement;
        requirement apertureRotationRequirement : ApertureRotationRequirement;
        requirement safetyRequirement : SafetyRequirement;
        requirement sampleIntegrityRequirement : SampleIntegrityRequirement;
    }

    package Subsystems {

        part def ImagingSubsystem {
            port imagingOut : Mammotome::Ports::ImagingOutPort;
            port controlIn : Mammotome::Ports::ControlInPort;

            attribute frequency : Mammotome::ValueTypes::FrequencyValue = 10 [MHz];
            attribute resolution : Mammotome::ValueTypes::DepthValue = 0.5 [mm];
            attribute power : Mammotome::ValueTypes::PowerValue = 15 [W];
            attribute active : Boolean = false;

            perform action def LocateTarget {
                in tissue : Mammotome::Items::BreastTissue;
                out data : Mammotome::Items::ImagingData;
            }

            perform action def AcquireImage {
                out data : Mammotome::Items::ImagingData;
            }
        }

        part def ControlConsole {
            port imagingIn : Mammotome::Ports::ImagingInPort;
            port controlOut : Mammotome::Ports::ControlOutPort;
            port statusIn : Mammotome::Ports::StatusInPort;
            port statusOut : Mammotome::Ports::StatusOutPort;

            attribute sampleCount : Integer = 0;
            attribute targetSampleCount : Integer = 12;
            attribute currentMode : String = "standby";
            attribute procedureActive : Boolean = false;
            attribute emergencyStop : Boolean = false;

            perform action def ManageProcedure {
                in imagingData : Mammotome::Items::ImagingData;
                in status : Mammotome::Items::StatusReport;
                out command : Mammotome::Items::ControlCommand;
            }

            perform action def IssueCommand {
                in commandType : String;
                out command : Mammotome::Items::ControlCommand;
            }

            perform action def EvaluateStatus {
                in status : Mammotome::Items::StatusReport;
                out nextMode : String;
            }
        }

        part def ProbeAssembly {
            port tissuePort : Mammotome::Ports::TissueInterfacePort;
            port vacuumIn : Mammotome::Ports::VacuumInPort;
            port cutterDriveIn : Mammotome::Ports::CutterDriveInPort;
            port rotationIn : Mammotome::Ports::RotationInPort;
            port sampleOut : Mammotome::Ports::SampleFlowOutPort;

            attribute probeLength : Mammotome::ValueTypes::DepthValue = 120 [mm];
            attribute apertureDiameter : Mammotome::ValueTypes::DepthValue = 3 [mm];
            attribute currentApertureAngle : Mammotome::ValueTypes::AngleValue = 0 [deg];
            attribute inserted : Boolean = false;
            attribute sterile : Boolean = true;

            part aperture {
                attribute angle : Mammotome::ValueTypes::AngleValue = 0 [deg];
                attribute open : Boolean = false;
            }

            part cutterChamber {
                attribute volume : Mammotome::ValueTypes::VolumeValue = 0.5 [mL];
                attribute occupied : Boolean = false;
            }

            part rotatingCutter {
                attribute speed : Mammotome::ValueTypes::RotationalSpeedValue = 0 [rpm];
                attribute engaged : Boolean = false;
            }

            part probeShaft {
                attribute diameter : Mammotome::ValueTypes::DepthValue = 4 [mm];
                attribute material : String = "StainlessSteel";
            }

            perform action def InsertProbe {
                in targetDepth : Mammotome::ValueTypes::DepthValue;
                out insertedFlag : Boolean;
            }

            perform action def ExciseTissue {
                in vacuum : Mammotome::ValueTypes::VacuumLevelValue;
                in cutterSpeed : Mammotome::ValueTypes::RotationalSpeedValue;
                out sample : Mammotome::Items::TissueSample;
            }

            perform action def RotateAperture {
                in targetAngle : Mammotome::ValueTypes::AngleValue;
                out newAngle : Mammotome::ValueTypes::AngleValue;
            }

            perform action def TransportSample {
                in vacuum : Mammotome::ValueTypes::VacuumLevelValue;
                out sample : Mammotome::Items::TissueSample;
            }
        }

        part def VacuumSubsystem {
            port vacuumOut : Mammotome::Ports::VacuumOutPort;
            port controlIn : Mammotome::Ports::ControlInPort;
            port statusOut : Mammotome::Ports::StatusOutPort;

            attribute maxVacuum : Mammotome::ValueTypes::VacuumLevelValue = 550 [mmHg];
            attribute currentVacuum : Mammotome::ValueTypes::VacuumLevelValue = 0 [mmHg];
            attribute power : Mammotome::ValueTypes::PowerValue = 120 [W];
            attribute active : Boolean = false;

            part vacuumPump {
                attribute flowRate : Mammotome::ValueTypes::VolumeValue = 20 [mL];
                attribute running : Boolean = false;
            }

            part pressureSensor {
                attribute reading : Mammotome::ValueTypes::VacuumLevelValue = 0 [mmHg];
            }

            perform action def GenerateVacuum {
                in command : Mammotome::Items::ControlCommand;
                out pressure : Mammotome::ValueTypes::VacuumLevelValue;
            }

            perform action def RegulatePressure {
                in target : Mammotome::ValueTypes::VacuumLevelValue;
                out actual : Mammotome::ValueTypes::VacuumLevelValue;
            }
        }

        part def CutterSubsystem {
            port cutterDriveOut : Mammotome::Ports::CutterDriveOutPort;
            port controlIn : Mammotome::Ports::ControlInPort;
            port statusOut : Mammotome::Ports::StatusOutPort;

            attribute maxSpeed : Mammotome::ValueTypes::RotationalSpeedValue = 5000 [rpm];
            attribute currentSpeed : Mammotome::ValueTypes::RotationalSpeedValue = 0 [rpm];
            attribute power : Mammotome::ValueTypes::PowerValue = 80 [W];
            attribute active : Boolean = false;

            part cutterMotor {
                attribute torque : Mammotome::ValueTypes::ForceValue = 1.5 [N];
                attribute running : Boolean = false;
            }

            perform action def DriveCutter {
                in command : Mammotome::Items::ControlCommand;
                out speed : Mammotome::ValueTypes::RotationalSpeedValue;
            }

            perform action def EngageCutter {
                in targetSpeed : Mammotome::ValueTypes::RotationalSpeedValue;
                out actualSpeed : Mammotome::ValueTypes::RotationalSpeedValue;
            }
        }

        part def RotationSubsystem {
            port rotationOut : Mammotome::Ports::RotationOutPort;
            port controlIn : Mammotome::Ports::ControlInPort;
            port statusOut : Mammotome::Ports::StatusOutPort;

            attribute maxTorque : Mammotome::ValueTypes::ForceValue = 2 [N];
            attribute currentAngle : Mammotome::ValueTypes::AngleValue = 0 [deg];
            attribute active : Boolean = false;

            part rotationMotor {
                attribute stepIncrement : Mammotome::ValueTypes::AngleValue = 30 [deg];
                attribute running : Boolean = false;
            }

            perform action def RotateToPosition {
                in command : Mammotome::Items::ControlCommand;
                out angle : Mammotome::ValueTypes::AngleValue;
            }
        }

        part def SampleCollector {
            port sampleIn : Mammotome::Ports::SampleFlowInPort;
            port statusOut : Mammotome::Ports::StatusOutPort;

            attribute capacity : Integer = 24;
            attribute collectedCount : Integer = 0;
            attribute samples : Mammotome::Items::TissueSample[0..24];

            part collectionChamber {
                attribute volume : Mammotome::ValueTypes::VolumeValue = 12 [mL];
                attribute filled : Boolean = false;
            }

            perform action def CollectSample {
                in sample : Mammotome::Items::TissueSample;
                out status : Mammotome::Items::StatusReport;
            }

            perform action def ReportStatus {
                out status : Mammotome::Items::StatusReport;
            }
        }
    }

    part def MammotomeSystem {
        satisfy Mammotome::Requirements::biopsySystemRequirement;
        satisfy Mammotome::Requirements::multiSampleRequirement;
        satisfy Mammotome::Requirements::safetyRequirement;
        satisfy Mammotome::Requirements::sampleIntegrityRequirement;

        port userInterface : Mammotome::Ports::ControlOutPort;
        port patientInterface : Mammotome::Ports::TissueInterfacePort;
        port systemStatus : Mammotome::Ports::StatusOutPort;

        attribute systemId : String = "Mammotome-01";
        attribute systemMode : String = "standby";
        attribute procedureActive : Boolean = false;
        attribute totalSamplesCollected : Integer = 0;
        attribute emergencyStopEngaged : Boolean = false;

        part imagingSubsystem : Mammotome::Subsystems::ImagingSubsystem {
            attribute frequency = 10 [MHz];
        }
        part controlConsole : Mammotome::Subsystems::ControlConsole;
        part probeAssembly : Mammotome::Subsystems::ProbeAssembly;
        part vacuumSubsystem : Mammotome::Subsystems::VacuumSubsystem;
        part cutterSubsystem : Mammotome::Subsystems::CutterSubsystem;
        part rotationSubsystem : Mammotome::Subsystems::RotationSubsystem;
        part sampleCollector : Mammotome::Subsystems::SampleCollector;

        state machine procedureStateMachine {
            state standby {
                entry attribute systemMode = "standby";
            }
            state imaging {
                entry attribute systemMode = "imaging";
            }
            state positioning {
                entry attribute systemMode = "positioning";
            }
            state sampling {
                entry attribute systemMode = "sampling";
            }
            state retrieving {
                entry attribute systemMode = "retrieving";
            }
            state fault {
                entry attribute systemMode = "fault";
            }

            transition standby_to_imaging
                first standby then imaging
                when controlConsole.currentMode == "imaging";

            transition imaging_to_positioning
                first imaging then positioning
                when imagingSubsystem.active == false and probeAssembly.inserted == false;

            transition positioning_to_sampling
                first positioning then sampling
                when probeAssembly.inserted == true and vacuumSubsystem.active == true;

            transition sampling_to_retrieving
                first sampling then retrieving
                when probeAssembly.cutterChamber.occupied == true;

            transition retrieving_to_sampling
                first retrieving then sampling
                when controlConsole.sampleCount < controlConsole.targetSampleCount and emergencyStopEngaged == false;

            transition retrieving_to_standby
                first retrieving then standby
                when controlConsole.sampleCount >= controlConsole.targetSampleCount;

            transition any_to_fault
                first standby then fault
                when emergencyStopEngaged == true;
            transition imaging_to_fault
                first imaging then fault
                when emergencyStopEngaged == true;
            transition positioning_to_fault
                first positioning then fault
                when emergencyStopEngaged == true;
            transition sampling_to_fault
                first sampling then fault
                when emergencyStopEngaged == true;
            transition retrieving_to_fault
                first retrieving then fault
                when emergencyStopEngaged == true;

            transition fault_to_standby
                first fault then standby
                when emergencyStopEngaged == false and controlConsole.currentMode == "reset";
        }

        connection imagingDataFlow
            connect imagingSubsystem.imagingOut to controlConsole.imagingIn;

        connection controlToImaging
            connect controlConsole.controlOut to imagingSubsystem.controlIn;

        connection controlToVacuum
            connect controlConsole.controlOut to vacuumSubsystem.controlIn;

        connection controlToCutter
            connect controlConsole.controlOut to cutterSubsystem.controlIn;

        connection controlToRotation
            connect controlConsole.controlOut to rotationSubsystem.controlIn;

        connection vacuumToProbe
            connect vacuumSubsystem.vacuumOut to probeAssembly.vacuumIn;

        connection cutterToProbe
            connect cutterSubsystem.cutterDriveOut to probeAssembly.cutterDriveIn;

        connection rotationToProbe
            connect rotationSubsystem.rotationOut to probeAssembly.rotationIn;

        connection probeToCollector
            connect probeAssembly.sampleOut to sampleCollector.sampleIn;

        connection collectorStatusToConsole
            connect sampleCollector.statusOut to controlConsole.statusIn;

        connection vacuumStatusToConsole
            connect vacuumSubsystem.statusOut to controlConsole.statusIn;

        connection cutterStatusToConsole
            connect cutterSubsystem.statusOut to controlConsole.statusIn;

        connection rotationStatusToConsole
            connect rotationSubsystem.statusOut to controlConsole.statusIn;

        connection consoleStatusToSystem
            connect controlConsole.statusOut to systemStatus;

        connection patientToProbe
            connect patientInterface to probeAssembly.tissuePort;

        connection userToConsole
            connect userInterface to controlConsole.controlOut;
    }

    part def MammotomeProcedureContext {
        part system : Mammotome::MammotomeSystem;

        perform action def ConductBiopsy {
            in patientTissue : Mammotome::Items::BreastTissue;
            out collectedSamples : Mammotome::Items::TissueSample[*];

            perform locateTarget {
                out imagingData : Mammotome::Items::ImagingData;
            }
            then perform insertProbe {
                in imagingData : Mammotome::Items::ImagingData;
                out inserted : Boolean;
            }
            then perform applyVacuum {
                out vacuumLevel : Mammotome::ValueTypes::VacuumLevelValue;
            }
            then perform exciseSample {
                in vacuumLevel : Mammotome::ValueTypes::VacuumLevelValue;
                out sample : Mammotome::Items::TissueSample;
            }
            then perform retrieveSample {
                in sample : Mammotome::Items::TissueSample;
                out retrieved : Boolean;
            }
            then perform rotateAperture {
                out newAngle : Mammotome::ValueTypes::AngleValue;
            }
            then decide if system.controlConsole.sampleCount < system.controlConsole.targetSampleCount
                then loop exciseSample
                else done;
        }
    }
}
