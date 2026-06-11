package HeadMirrorSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real;
    attribute def LuminousFlux {
        attribute value : Real;
        attribute unit : String = "lm";
    }

    attribute def Illuminance {
        attribute value : Real;
        attribute unit : String = "lx";
    }

    attribute def Angle {
        attribute value : Real;
        attribute unit : String = "deg";
    }

    attribute def Diameter {
        attribute value : Real;
        attribute unit : String = "mm";
    }

    attribute def Mass {
        attribute value : Real;
        attribute unit : String = "g";
    }

    attribute def Force {
        attribute value : Real;
        attribute unit : String = "N";
    }

    item def IncidentLight {
        attribute luminousFlux : LuminousFlux;
        attribute beamDiameter : Diameter;
        attribute incidenceAngle : Angle;
    }

    item def ReflectedLight {
        attribute luminousFlux : LuminousFlux;
        attribute beamDiameter : Diameter;
        attribute reflectionAngle : Angle;
        attribute centralApertureShadowDiameter : Diameter;
    }

    item def HeadPosition {
        attribute tiltAngle : Angle;
        attribute rotationAngle : Angle;
        attribute verticalOffset : Diameter;
    }

    port def LightInputPort {
        in item incident : IncidentLight;
    }

    port def LightOutputPort {
        out item reflected : ReflectedLight;
    }

    port def HeadInterfacePort {
        in item headPosition : HeadPosition;
        out attribute retentionForce : Force;
    }

    port def ClinicianViewPort {
        out item reflectedView : ReflectedLight;
    }

    action def AlignMirror {
        in item desiredTargetLight : ReflectedLight;
        in item currentHeadPosition : HeadPosition;
        out attribute mirrorTiltCommand : Angle;
        out attribute mirrorRotationCommand : Angle;
    }

    action def ReflectExternalLight {
        in item sourceLight : IncidentLight;
        in attribute mirrorTilt : Angle;
        out item directedLight : ReflectedLight;

        satisfy requirement OpticalReflectionRequirement;
    }

    action def MaintainHeadFit {
        in item headPosition : HeadPosition;
        out attribute appliedRetentionForce : Force;

        satisfy requirement WearabilityRequirement;
    }

    action def ExamineTargetArea {
        in item reflectedIllumination : ReflectedLight;
        out attribute targetIlluminated : Boolean;
        out attribute clinicianLineOfSightClear : Boolean;

        satisfy requirement PrimaryFunctionRequirement;
    }

    state def HeadMirrorOperatingState {
        state stowed;
        state fitted;
        state aligned;
        state illuminating;
        state readjusting;

        transition first stowed;
        transition stowed_to_fitted
            first stowed then fitted;

        transition fitted_to_aligned
            first fitted then aligned;

        transition aligned_to_illuminating
            first aligned then illuminating;

        transition illuminating_to_readjusting
            first illuminating then readjusting;

        transition readjusting_to_illuminating
            first readjusting then illuminating;
    }

    part def ConcaveMirror {
        attribute outerDiameter : Diameter = (value = 90.0, unit = "mm");
        attribute centralApertureDiameter : Diameter = (value = 18.0, unit = "mm");
        attribute focalLength : Diameter = (value = 180.0, unit = "mm");
        attribute reflectivity : Percent = 88.0;
        attribute mass : Mass = (value = 42.0, unit = "g");

        port lightIn : LightInputPort;
        port lightOut : LightOutputPort;

        perform action reflectLight : ReflectExternalLight;
    }

    part def MirrorMount {
        attribute tiltRangeMin : Angle = (value = -35.0, unit = "deg");
        attribute tiltRangeMax : Angle = (value = 35.0, unit = "deg");
        attribute rotationRangeMin : Angle = (value = -25.0, unit = "deg");
        attribute rotationRangeMax : Angle = (value = 25.0, unit = "deg");
        attribute locked : Boolean;

        port mirrorLightIn : LightInputPort;
        port mirrorLightOut : LightOutputPort;
    }

    part def AdjustableHeadBand {
        attribute circumferenceMin : Diameter = (value = 520.0, unit = "mm");
        attribute circumferenceMax : Diameter = (value = 640.0, unit = "mm");
        attribute strapWidth : Diameter = (value = 28.0, unit = "mm");
        attribute retentionForceNominal : Force = (value = 8.0, unit = "N");
        attribute mass : Mass = (value = 85.0, unit = "g");

        port headInterface : HeadInterfacePort;

        perform action maintainFit : MaintainHeadFit;
    }

    part def ApertureViewPath {
        attribute fieldOfViewDiameter : Diameter = (value = 22.0, unit = "mm");
        attribute opticalAxisOffset : Diameter = (value = 0.0, unit = "mm");

        port clinicianView : ClinicianViewPort;
    }

    part def ExternalLampInterface {
        attribute recommendedLampFlux : LuminousFlux = (value = 650.0, unit = "lm");
        attribute recommendedDistance : Diameter = (value = 300.0, unit = "mm");

        port emittedLight : LightInputPort;
    }

    part def HeadMirrorSystem {
        attribute totalMass : Mass = (value = 155.0, unit = "g");
        attribute intendedUse : String = "Hands-free reflection of external light toward an examination target while preserving clinician line of sight through the central aperture.";

        part mirror : ConcaveMirror;
        part mount : MirrorMount;
        part headband : AdjustableHeadBand;
        part viewPath : ApertureViewPath;
        part lampInterface : ExternalLampInterface;

        port externalLightReceiver : LightInputPort;
        port directedIlluminationEmitter : LightOutputPort;
        port wearerInterface : HeadInterfacePort;
        port clinicianOpticalView : ClinicianViewPort;

        connect externalLightReceiver.incident to mirror.lightIn.incident;
        connect mirror.lightOut.reflected to directedIlluminationEmitter.reflected;
        connect wearerInterface.headPosition to headband.headInterface.headPosition;
        connect headband.headInterface.retentionForce to wearerInterface.retentionForce;
        connect mirror.lightOut.reflected to viewPath.clinicianView.reflectedView;
        connect viewPath.clinicianView.reflectedView to clinicianOpticalView.reflectedView;

        perform action alignMirror : AlignMirror;
        perform action examineTarget : ExamineTargetArea;

        exhibit state operatingState : HeadMirrorOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The head mirror system shall provide hands-free, head-mounted optical redirection of an external light source toward an examination area while allowing the clinician to view the illuminated target through the mirror aperture.
         */

        subject system : HeadMirrorSystem;

        require constraint {
            system.mirror.reflectivity >= 80.0
        }
    }

    requirement def OpticalReflectionRequirement {
        doc
        /*
         * The concave mirror shall receive incident light from an external lamp and reflect a concentrated beam toward the examination target along an axis controllable by head position and mirror adjustment.
         */

        subject mirror : ConcaveMirror;

        require constraint {
            mirror.outerDiameter.value >= 75.0 and
            mirror.centralApertureDiameter.value >= 12.0 and
            mirror.focalLength.value >= 120.0
        }
    }

    requirement def WearabilityRequirement {
        doc
        /*
         * The headband shall support stable hands-free positioning of the mirror on the clinician's head without requiring continuous manual support during examination.
         */

        subject headband : AdjustableHeadBand;

        require constraint {
            headband.retentionForceNominal.value >= 5.0 and
            headband.retentionForceNominal.value <= 12.0 and
            headband.mass.value <= 120.0
        }
    }

    requirement def AdjustabilityRequirement {
        doc
        /*
         * The mirror mount shall permit angular adjustment sufficient to align reflected light with the clinician's line of sight for common seated and standing examination postures.
         */

        subject mount : MirrorMount;

        require constraint {
            mount.tiltRangeMin.value <= -30.0 and
            mount.tiltRangeMax.value >= 30.0 and
            mount.rotationRangeMin.value <= -20.0 and
            mount.rotationRangeMax.value >= 20.0
        }
    }

    requirement def ViewingRequirement {
        doc
        /*
         * The central aperture shall provide an unobstructed optical viewing path through the mirror so the clinician can inspect the illuminated target area.
         */

        subject viewPath : ApertureViewPath;

        require constraint {
            viewPath.fieldOfViewDiameter.value >= 18.0
        }
    }

    satisfy PrimaryFunctionRequirement by HeadMirrorSystem;
    satisfy OpticalReflectionRequirement by ConcaveMirror;
    satisfy WearabilityRequirement by AdjustableHeadBand;
    satisfy AdjustabilityRequirement by MirrorMount;
    satisfy ViewingRequirement by ApertureViewPath;

}