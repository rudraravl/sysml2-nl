package DirectOphthalmoscope {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    item def LightBeam {
        attribute intensity : Illuminance;
        attribute flux : LuminousFlux;
        attribute wavelength : Length;
    }

    item def RetinalImage {
        attribute magnification : Real;
        attribute clarity : Real;
    }

    port def ElectricalPort {
        out power : ElectricalPower;
    }

    port def LightPort {
        out beam : LightBeam;
    }

    port def ImagePort {
        out image : RetinalImage;
    }

    port def ControlPort {
        out command : String;
    }

    requirement def MagnificationRequirement {
        doc "The viewing optics shall provide adequate magnification of retinal structures for diagnostic purposes.";
        attribute minMagnification : Real = 5;
        attribute maxMagnification : Real = 15;
        constraint { magnification >= minMagnification and magnification <= maxMagnification }
    }

    requirement def WorkingDistanceRequirement {
        doc "The device shall maintain a safe working distance from the patient's eye.";
        attribute minDistance : Length = 0.01 [m];
        attribute maxDistance : Length = 0.025 [m];
        constraint { workingDistance >= minDistance and workingDistance <= maxDistance }
    }

    requirement def IlluminationRequirement {
        doc "The illumination source shall provide sufficient light intensity for retinal examination while ensuring patient safety.";
        attribute minIntensity : Illuminance = 500 [lx];
        attribute maxIntensity : Illuminance = 2000 [lx];
        constraint { illuminationIntensity >= minIntensity and illuminationIntensity <= maxIntensity }
    }

    requirement def PatientSafetyRequirement {
        doc "The device shall not expose the patient's retina to harmful light levels.";
        attribute maxExposureTime : Time = 30 [s];
        constraint { exposureTime <= maxExposureTime }
    }

    requirement def BatteryLifeRequirement {
        doc "The battery shall provide sufficient operating time for a typical examination session.";
        attribute minOperatingTime : Time = 7200 [s];
        constraint { operatingTime >= minOperatingTime }
    }

    requirement def OphthalmoscopeRequirements {
        requirement magReq : MagnificationRequirement;
        requirement wdReq : WorkingDistanceRequirement;
        requirement illReq : IlluminationRequirement;
        requirement safetyReq : PatientSafetyRequirement;
        requirement batteryReq : BatteryLifeRequirement;
    }

    part def PowerSupply {
        attribute nominalVoltage : ElectricPotential = 3.7 [V];
        attribute capacity : Real = 1500;
        attribute chargeLevel : Real = 100;
        port electricalOut : ElectricalPort;

        action def SupplyPower {
            out power : ElectricalPower;
        }
    }

    part def IlluminationSource {
        attribute powerConsumption : Power = 1.0 [W];
        attribute outputIntensity : Illuminance;
        attribute isActivated : Boolean = false;
        port electricalIn : ElectricalPort;
        port lightOut : LightPort;

        action def GenerateLight {
            in power : ElectricalPower;
            out beam : LightBeam;
        }
    }

    part def CondensingLens {
        attribute focalLength : Length = 0.020 [m];
        attribute aperture : Length = 0.005 [m];
        port lightIn : LightPort;
        port lightOut : LightPort;

        action def FocusLight {
            in beamIn : LightBeam;
            out beamOut : LightBeam;
        }
    }

    part def ReflectingMirror {
        attribute reflectance : Real = 0.95;
        attribute angle : Angle = 0.785 [rad];
        port lightIn : LightPort;
        port lightOut : LightPort;

        action def ReflectLight {
            in beamIn : LightBeam;
            out beamOut : LightBeam;
        }
    }

    part def ObjectiveLens {
        attribute focalLength : Length = 0.025 [m];
        attribute aperture : Length = 0.008 [m];
        port lightIn : LightPort;
        port lightOut : LightPort;

        action def CaptureLight {
            in beamIn : LightBeam;
            out beamOut : LightBeam;
        }
    }

    part def ViewingOptics {
        attribute magnification : Real = 15;
        attribute fieldOfView : Angle = 0.175 [rad];
        port lightIn : LightPort;
        port imageOut : ImagePort;

        action def FormImage {
            in beamIn : LightBeam;
            out image : RetinalImage;
        }
    }

    part def Controller {
        attribute currentState : String;
        attribute powerButtonPressed : Boolean = false;
        attribute examineTrigger : Boolean = false;
        attribute examineComplete : Boolean = false;
        attribute emergencyStop : Boolean = false;
        port controlOut : ControlPort;
    }

    part def PatientEye {
        attribute pupilDiameter : Length = 0.004 [m];
        port lightIn : LightPort;
        port lightOut : LightPort;
    }

    part def Clinician {
        port imageIn : ImagePort;

        action def ObserveRetina {
            in image : RetinalImage;
            out findings : String;
        }

        action def DocumentFindings {
            in findings : String;
            out report : String;
        }
    }

    part def DirectOphthalmoscopeSystem {
        requirement ophthReqs : OphthalmoscopeRequirements;

        part powerSupply : PowerSupply;
        part illuminationSource : IlluminationSource;
        part condensingLens : CondensingLens;
        part reflectingMirror : ReflectingMirror;
        part objectiveLens : ObjectiveLens;
        part viewingOptics : ViewingOptics;
        part controller : Controller;
        part patientEye : PatientEye;
        part clinician : Clinician;

        connection powerConn connect powerSupply.electricalOut to illuminationSource.electricalIn;
        connection illumConn connect illuminationSource.lightOut to condensingLens.lightIn;
        connection condenserConn connect condensingLens.lightOut to reflectingMirror.lightIn;
        connection mirrorConn connect reflectingMirror.lightOut to patientEye.lightIn;
        connection eyeConn connect patientEye.lightOut to objectiveLens.lightIn;
        connection objectiveConn connect objectiveLens.lightOut to viewingOptics.lightIn;
        connection viewingConn connect viewingOptics.imageOut to clinician.imageIn;

        action examinationProcedure {
            action preparePatientAndRoom {
                out roomReady : Boolean;
            }
            action activateLight {
                in roomReady : Boolean;
                out beam : LightBeam;
            }
            action alignWithEye {
                in beam : LightBeam;
                out alignedBeam : LightBeam;
            }
            action adjustFocus {
                in alignedBeam : LightBeam;
                out focusedBeam : LightBeam;
            }
            action observeRetina {
                in focusedBeam : LightBeam;
                out findings : String;
            }
            action documentFindings {
                in findings : String;
                out report : String;
            }

            succession first preparePatientAndRoom then activateLight;
            succession first activateLight then alignWithEye;
            succession first alignWithEye then adjustFocus;
            succession first adjustFocus then observeRetina;
            succession first observeRetina then documentFindings;

            flow from preparePatientAndRoom.roomReady to activateLight.roomReady;
            flow from activateLight.beam to alignWithEye.beam;
            flow from alignWithEye.alignedBeam to adjustFocus.alignedBeam;
            flow from adjustFocus.focusedBeam to observeRetina.focusedBeam;
            flow from observeRetina.findings to documentFindings.findings;
        }

        state DeviceStates {
            initial Off;
            state Off;
            state Standby;
            state Examining;

            transition offToStandby first Off if controller.powerButtonPressed then Standby;
            transition standbyToExamining first Standby if controller.examineTrigger then Examining;
            transition examiningToStandby first Examining if controller.examineComplete then Standby;
            transition standbyToOff first Standby if controller.powerButtonPressed then Off;
            transition emergencyOff first Examining if controller.emergencyStop then Off;
        }
    }
}
