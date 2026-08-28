package MammotomeBiopsySystem {
    private import ISQ::*;
    private import SI::*;

    item def Breast;
    item def TissueSample;
    item def UltrasoundImage;
    item def ControlCommand;
    item def SystemStatus;

    attribute def VacuumPressure :> PressureValue;
    attribute def CutterSpeed :> AngularVelocityValue;
    attribute def InsertionDepth :> LengthValue;
    attribute def ApertureAngle :> PlaneAngleValue;

    unit def deg;
    unit def rpm;

    requirement MinimallyInvasiveBiopsyRequirement {
        doc /* The system shall acquire multiple tissue samples through a single small incision. */
    }
    requirement VacuumAssistedSamplingRequirement {
        doc /* The vacuum subsystem shall provide negative pressure to draw tissue into the aperture. */
    }
    requirement MultiSampleRequirement {
        doc /* The system shall acquire multiple samples without removing the probe by rotating the aperture. */
    }

    part def Mammotome;
    part def ImagingSubsystem;
    part def ControlConsole;
    part def ProbeAssembly;
    part def VacuumSubsystem;
    part def CutterSubsystem;
    part def SampleCollector;
    part def Clinician;

    port def ImagingOutPort {
        out item image : UltrasoundImage;
        out depth : InsertionDepth;
    }
    port def ConsoleInPort {
        in item image : UltrasoundImage;
        in depth : InsertionDepth;
        in item status : SystemStatus;
    }
    port def ConsoleOutPort {
        out item command : ControlCommand;
    }
    port def VacuumInPort {
        in item command : ControlCommand;
    }
    port def VacuumOutPort {
        out pressure : VacuumPressure;
    }
    port def CutterInPort {
        in item command : ControlCommand;
    }
    port def CutterOutPort {
        out rotation : CutterSpeed;
    }
    port def ProbeInPort {
        in item command : ControlCommand;
        in pressure : VacuumPressure;
        in rotation : CutterSpeed;
    }
    port def ProbeOutPort {
        out item sample : TissueSample;
        out item status : SystemStatus;
    }
    port def CollectorInPort {
        in item sample : TissueSample;
    }

    part mammotome : Mammotome {
        satisfy MinimallyInvasiveBiopsyRequirement;
        satisfy VacuumAssistedSamplingRequirement;
        satisfy MultiSampleRequirement;

        ref item breast : Breast;
        item samples : TissueSample[*];
        ref part clinician : Clinician;

        part imagingSubsystem : ImagingSubsystem {
            in ref item breast : Breast = mammotome::breast;
            port imagingOut : ImagingOutPort;
            action locateTarget {
                out targetDepth : InsertionDepth;
                out item image : UltrasoundImage;
            }
        }

        part controlConsole : ControlConsole {
            port consoleIn : ConsoleInPort;
            port consoleOut : ConsoleOutPort;
            ref part clinician : Clinician = mammotome::clinician;
            action processImage {
                in item image : UltrasoundImage;
                in depth : InsertionDepth;
                out item command : ControlCommand;
            }
        }

        part probeAssembly : ProbeAssembly {
            port probeIn : ProbeInPort;
            port probeOut : ProbeOutPort;
            in ref item breast : Breast = mammotome::breast;
            attribute aperturePosition : ApertureAngle = 0 [deg];
            part aperture;
            part cutter;
            action insertProbe {
                in depth : InsertionDepth;
            }
            action rotateAperture {
                in angle : ApertureAngle;
            }
            action exciseTissue {
                in pressure : VacuumPressure;
                in rotation : CutterSpeed;
                out item sample : TissueSample;
            }
        }

        part vacuumSubsystem : VacuumSubsystem {
            port vacuumIn : VacuumInPort;
            port vacuumOut : VacuumOutPort;
            action generateVacuum {
                in setpoint : VacuumPressure;
                out pressure : VacuumPressure;
            }
        }

        part cutterSubsystem : CutterSubsystem {
            port cutterIn : CutterInPort;
            port cutterOut : CutterOutPort;
            action driveCutter {
                in setpoint : CutterSpeed;
                out rotation : CutterSpeed;
            }
        }

        part sampleCollector : SampleCollector {
            port collectorIn : CollectorInPort;
            item collectedSamples : TissueSample[*] :> mammotome::samples;
            action storeSample {
                in item sample : TissueSample;
                out item stored : TissueSample :> collectedSamples;
            }
        }

        flow imagingSubsystem.imagingOut.image to controlConsole.consoleIn.image;
        flow imagingSubsystem.imagingOut.depth to controlConsole.consoleIn.depth;
        flow controlConsole.consoleOut.command to probeAssembly.probeIn.command;
        flow controlConsole.consoleOut.command to vacuumSubsystem.vacuumIn.command;
        flow controlConsole.consoleOut.command to cutterSubsystem.cutterIn.command;
        flow vacuumSubsystem.vacuumOut.pressure to probeAssembly.probeIn.pressure;
        flow cutterSubsystem.cutterOut.rotation to probeAssembly.probeIn.rotation;
        flow probeAssembly.probeOut.sample to sampleCollector.collectorIn.sample;
        flow probeAssembly.probeOut.status to controlConsole.consoleIn.status;

        state machine biopsyProcedure {
            state standby;
            state imaging;
            state positioning;
            state sampling;
            state retrieving;
            transition standby to imaging;
            transition imaging to positioning;
            transition positioning to sampling;
            transition sampling to retrieving;
            transition retrieving to positioning;
            transition retrieving to standby;
        }

        action performBiopsy {
            in targetDepth : InsertionDepth;
            in vacuumSetpoint : VacuumPressure = -65 [kPa];
            in cutterSetpoint : CutterSpeed = 1200 [rpm];
            in apertureStep : ApertureAngle = 45 [deg];
            out item biopsySamples : TissueSample[*];

            perform locateTargetAction {
                out :>> targetDepth;
            }
            then perform insertProbeAction {
                in depth = targetDepth;
            }
            then perform generateVacuumAction {
                in setpoint = vacuumSetpoint;
            }
            then perform driveCutterAction {
                in setpoint = cutterSetpoint;
            }
            then perform exciseTissueAction {
                in pressure = vacuumSetpoint;
                in rotation = cutterSetpoint;
                out item sample : TissueSample :> biopsySamples;
            }
            then perform storeSampleAction {
                in item sample : TissueSample = exciseTissueAction.sample;
            }
            then perform rotateApertureAction {
                in angle = apertureStep;
            }
        }

        action locateTargetAction {
            out targetDepth : InsertionDepth;
        }
        action insertProbeAction {
            in depth : InsertionDepth;
        }
        action generateVacuumAction {
            in setpoint : VacuumPressure;
        }
        action driveCutterAction {
            in setpoint : CutterSpeed;
        }
        action exciseTissueAction {
            in pressure : VacuumPressure;
            in rotation : CutterSpeed;
            out item sample : TissueSample;
        }
        action storeSampleAction {
            in item sample : TissueSample;
        }
        action rotateApertureAction {
            in angle : ApertureAngle;
        }
    }

    individual def ClinicalProcedure :> Mammotome;
    individual clinicalProcedure : ClinicalProcedure :> mammotome {
        timeslice sample1 {
            perform action :>> performBiopsy {
                in targetDepth = 20 [mm];
                in apertureStep = 0 [deg];
            }
        }
        then timeslice sample2 {
            perform action :>> performBiopsy {
                in targetDepth = 20 [mm];
                in apertureStep = 45 [deg];
            }
        }
        then timeslice sample3 {
            perform action :>> performBiopsy {
                in targetDepth = 20 [mm];
                in apertureStep = 90 [deg];
            }
        }
    }
}
